package com.example.mobile

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import kotlinx.coroutines.*
import okhttp3.*
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

        val prefs = appContext?.getSharedPreferences("bubble_app", MODE_PRIVATE)
        val userId = prefs?.getInt("user_id", -1) ?: -1
        val ip = prefs?.getString("ip_address", "") ?: ""
        val wsUrl = if (userId > 0) {
            "ws://$ip:8000/ws?user_id=$userId"
        } else {
            "ws://$ip:8000/ws"
        }

        val request = Request.Builder()
            .url(wsUrl)
            .build()

        socket = client!!.newWebSocket(request, object : WebSocketListener() {

            override fun onOpen(ws: WebSocket, response: Response) {
                connected = true
                readyForAudio = true
                reconnecting.set(false)
                Log.i("SafetySocket", "✅ WS OPEN (${response.code})")
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
            Log.i(TAG,
                "🎤 Audio sent | samples=$size | bytes=${bytes.size} | time=${System.currentTimeMillis()}"
            )
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
