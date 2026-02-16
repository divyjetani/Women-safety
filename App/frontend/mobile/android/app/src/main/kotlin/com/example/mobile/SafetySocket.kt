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

object SafetySocket {

    private const val TAG = "SafetySocket"

    private var client: OkHttpClient? = null
    private var socket: WebSocket? = null

    @Volatile private var connected = false
    @Volatile private var readyForAudio = false
    private val reconnecting = AtomicBoolean(false)

    private var appContext: Context? = null
    private var threatCallback: (() -> Unit)? = null

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    // =========================
    // CONNECT
    // =========================
    fun connect(context: Context, onThreat: () -> Unit) {
        appContext = context.applicationContext
        threatCallback = onThreat

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

        val request = Request.Builder()
            .url("ws://10.105.15.13:8000/ws") // emulator → host
            .build()

        socket = client!!.newWebSocket(request, object : WebSocketListener() {

            override fun onOpen(ws: WebSocket, response: Response) {
                connected = true
                readyForAudio = true
                reconnecting.set(false)
                Log.i("SafetySocket", "✅ WS OPEN (${response.code})")
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
            Log.e("SafetySocket", "❌ WS not ready, dropping audio")
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
