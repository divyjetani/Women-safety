package com.example.mobile

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import kotlinx.coroutines.*
import okhttp3.*
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okio.ByteString.Companion.toByteString
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import android.content.Context.MODE_PRIVATE

object SafetySocket {

    private const val TAG = "SafetySocket"

    private var client: OkHttpClient? = null
    private var socket: WebSocket? = null

    @Volatile private var connected = false
    @Volatile private var readyForAudio = false
    private val reconnecting = AtomicBoolean(false)

    private var appContext: Context? = null
    private var threatCallback: (() -> Unit)? = null
    private var readyCallback: (() -> Unit)? = null
    @Volatile private var lastNotReadyLogAt = 0L
    @Volatile private var audioSendCount = 0L

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    // =========================
    // CONNECT
    // =========================
    fun connect(context: Context, onThreat: () -> Unit, onReady: (() -> Unit)? = null) {
        appContext = context.applicationContext
        threatCallback = onThreat
        readyCallback = onReady

        if (client == null) {
            client = OkHttpClient.Builder()
                .pingInterval(15, TimeUnit.SECONDS)
                .build()
        }

        scope.launch {
            openSocket()
        }
    }

    // =========================
    // OPEN SOCKET (SINGLE INSTANCE)
    // =========================
    private fun openSocket() {
        if (socket != null || connected) {
            Log.w("SafetySocket", "WS already active, skipping open")
            return
        }

        Log.i("SafetySocket", "🔧 Opening WebSocket")

        try {
            val wsUrl = resolveWsUrl()
            if (wsUrl.isNullOrBlank()) {
                Log.w("SafetySocket", "Missing/invalid ip_address; cannot open WS")
                cleanupAndReconnect()
                return
            }
            Log.i("SafetySocket", "🌐 WS URL resolved: $wsUrl")

            val request = Request.Builder()
                .url(wsUrl)
                .build()

            socket = client!!.newWebSocket(request, object : WebSocketListener() {

            override fun onOpen(ws: WebSocket, response: Response) {
                connected = true
                readyForAudio = true
                reconnecting.set(false)
                Log.i("SafetySocket", "✅ WS OPEN (${response.code})")
                ws.send("{\"type\":\"client_ready\",\"source\":\"android_safety_service\"}")
                readyCallback?.invoke()
            }

            override fun onMessage(ws: WebSocket, text: String) {
                try {
                    val json = JSONObject(text)
                    if (json.optBoolean("threat")) {
                        threatCallback?.invoke()
                    }
                } catch (e: Exception) {
                    Log.w("SafetySocket", "Bad message: ${e.message}")
                }
            }

            override fun onClosed(ws: WebSocket, code: Int, reason: String) {
                Log.w("SafetySocket", "🔴 WS CLOSED $code | $reason")
                cleanupAndReconnect()
            }

            override fun onFailure(ws: WebSocket, t: Throwable, response: Response?) {
                Log.e(
                    "SafetySocket",
                    "❌ WS FAILURE ${t.message} | code=${response?.code}",
                    t
                )
                cleanupAndReconnect()
            }
            })
        } catch (e: Exception) {
            Log.e("SafetySocket", "Error opening WS: ${e.message}", e)
            cleanupAndReconnect()
        }
    }

    private fun resolveWsUrl(): String? {
        val ctx = appContext ?: return null
        val flutterPrefs = ctx.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val bubblePrefs = ctx.getSharedPreferences("bubble_app", MODE_PRIVATE)

        val rawIp = (flutterPrefs.getString("flutter.ip_address", "") ?: "").trim()
        if (rawIp.isEmpty()) return null

        var base = rawIp
        if (!base.startsWith("http://") && !base.startsWith("https://")) {
            base = "http://$base"
        }

        val parsed = base.toHttpUrlOrNull() ?: return null

        val userIdFromBubble = bubblePrefs.getInt("user_id", -1)
        val userIdFromFlutter = (flutterPrefs.all["flutter.cached_user_id"] as? Number)?.toInt() ?: -1
        val userId = if (userIdFromBubble > 0) userIdFromBubble else userIdFromFlutter

        val builder = parsed.newBuilder()
            .encodedPath("/ws")
            .query(null)

        if (userId > 0) {
            builder.addQueryParameter("user_id", userId.toString())
        }

        val httpUrl = builder.build().toString()
        return if (parsed.isHttps) {
            httpUrl.replaceFirst("https://", "wss://")
        } else {
            httpUrl.replaceFirst("http://", "ws://")
        }
    }

    // =========================
    // CLEANUP + RECONNECT
    // =========================
    private fun cleanupAndReconnect() {
        connected = false
        readyForAudio = false
        socket = null

        if (reconnecting.getAndSet(true)) return

        Handler(Looper.getMainLooper()).postDelayed({
            Log.i("SafetySocket", "🔁 Reconnecting WS")
            scope.launch { openSocket() }
        }, 2000)
    }

    // =========================
    // SEND AUDIO (BINARY PCM)
    // =========================
    fun sendAudio(buffer: ShortArray, size: Int) {
        if (!SafetyService.audioSharingEnabled) {
            return // 🔕 audio disabled from notification
        }
        if (!readyForAudio || socket == null) {
            val now = System.currentTimeMillis()
            if (now - lastNotReadyLogAt > 3000) {
                Log.w("SafetySocket", "⚠️ WS not ready, dropping audio until connected")
                lastNotReadyLogAt = now
            }
            return
        }

        if (size <= 0) return

        val bytes = ByteArray(size * 2)
        var i = 0
        for (n in 0 until size) {
            val v = buffer[n].toInt()
            bytes[i++] = (v and 0xFF).toByte()
            bytes[i++] = ((v shr 8) and 0xFF).toByte()
        }

        val sent = try {
            socket!!.send(bytes.toByteString())
        } catch (e: Exception) {
            false
        }

        if (sent) {
            audioSendCount += 1
            if (audioSendCount % 20L == 0L) {
                Log.i(TAG,
                    "🎤 Audio sent | count=$audioSendCount | samples=$size | bytes=${bytes.size}"
                )
            }
        } else {
            Log.w(TAG, "⚠️ Audio send failed")
        }

    }

    // =========================
    // SEND PROXIMITY
    // =========================
    fun sendProximity(value: Float) {
        if (!connected || socket == null) return

        val json = JSONObject()
        json.put("type", "proximity")
        json.put("value", value)
        socket!!.send(json.toString())
    }

    fun close() {
        try {
            socket?.close(1000, "closed")
        } catch (_: Exception) {}
        socket = null
        connected = false
        readyForAudio = false
    }
}
