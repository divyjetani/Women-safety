package com.example.mobile

import android.app.*
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class SafetyService : Service(), SensorEventListener {

    companion object {
        const val NOTIFICATION_ID = 101
        const val NOTIFICATION_CHANNEL_ID = "safety_channel"
        const val ACTION_STOP_AUDIO = "com.example.mobile.STOP_AUDIO"
        const val AUTO_SOS_CHANNEL_ID = "auto_sos_channel"
        @Volatile var audioSharingEnabled = true  // 👈 accessible from SafetySocket
    }

    private var running = true
    @Volatile private var audioStarted = false
    private lateinit var audioRecorder: AudioRecord
    private lateinit var sensorManager: SensorManager
    private var proximitySensor: Sensor? = null

    override fun onCreate() {
        super.onCreate()
        audioSharingEnabled = true
        running = true
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        // Start WebSocket connection when service starts
        SafetySocket.connect(
            this,
            { onThreatDetected() },
            { maybeStartAudioRecording() }
        )
        // Start proximity sensing
        startProximitySensing()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {

        when (intent?.action) {
            ACTION_STOP_AUDIO -> {
                Log.i("SafetyService", "🔕 Audio sharing stopped from notification")
                audioSharingEnabled = false
                SafetySocket.close()
                updateNotification("Audio sharing OFF")
                // Notify Flutter that the service has stopped
                SOSBridge.notifyServiceStopped()
                // Stop the service after 2 seconds
                Handler(Looper.getMainLooper()).postDelayed({
                    stopSelf()
                }, 2000)
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        running = false
        SafetySocket.close()
        try {
            audioRecorder.stop()
            audioRecorder.release()
        } catch (e: Exception) {
            Log.w("SafetyService", "Error stopping audio: ${e.message}")
        }
        try {
            sensorManager.unregisterListener(this)
        } catch (e: Exception) {
            Log.w("SafetyService", "Error unregistering sensor: ${e.message}")
        }
        super.onDestroy()
    }

    // =========================
    // AUDIO RECORDING
    // =========================
    private fun maybeStartAudioRecording() {
        if (audioStarted) return
        audioStarted = true
        startAudioRecording()
    }

    private fun startAudioRecording() {
        val sampleRate = 16000
        val bufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        audioRecorder = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )

        if (audioRecorder.state != AudioRecord.STATE_INITIALIZED) {
            Log.e("SafetyService", "❌ Microphone not initialized")
            return
        }

        audioRecorder.startRecording()
        Log.i("SafetyService", "🎤 Audio recording started | bufferSize=$bufferSize")

        // Read audio in background thread
        Thread {
            val buffer = ShortArray(bufferSize)
            while (running && audioSharingEnabled) {
                try {
                    val read = audioRecorder.read(buffer, 0, buffer.size)
                    if (read > 0) {
                        SafetySocket.sendAudio(buffer, read)
                    }
                } catch (e: Exception) {
                    Log.e("SafetyService", "Audio read error: ${e.message}")
                    break
                }
            }
            Log.i("SafetyService", "🎤 Audio thread stopped")
        }.start()
    }

    // =========================
    // PROXIMITY SENSING
    // =========================
    private fun startProximitySensing() {
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        proximitySensor = sensorManager.getDefaultSensor(Sensor.TYPE_PROXIMITY)

        proximitySensor?.let {
            sensorManager.registerListener(
                this,
                it,
                SensorManager.SENSOR_DELAY_NORMAL
            )
            Log.i("SafetyService", "📡 Proximity sensor registered")
        } ?: run {
            Log.w("SafetyService", "⚠️ Proximity sensor not available")
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type == Sensor.TYPE_PROXIMITY) {
            SafetySocket.sendProximity(event.values[0])
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    // =========================
    // NOTIFICATION
    // =========================
    private fun buildNotification(text: String = "Monitoring active, audio sharing ON"): Notification {

        // 🔹 Open app when notification tapped
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val openAppPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 🔹 Stop audio action
        val stopAudioIntent = Intent(this, SafetyService::class.java).apply {
            action = ACTION_STOP_AUDIO
        }

        val stopAudioPendingIntent = PendingIntent.getService(
            this,
            1,
            stopAudioIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Women Safety Monitoring")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(openAppPendingIntent) // 👈 tap opens app
            .setOngoing(true)
            .addAction(
                android.R.drawable.ic_dialog_info,
                "Stop Audio Sharing",
                stopAudioPendingIntent
            )
            .build()
    }

    private fun updateNotification(text: String) {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(text))
    }

    // =========================
    // THREAT DETECTION
    // =========================
    private fun onThreatDetected() {
        Log.e("SafetyService", "🚨 THREAT DETECTED - triggering SOS")
        val reason = "Potential threat detected from real-time audio"

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("AUTO_SOS", true)
            putExtra("AUTO_SOS_REASON", reason)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            9001,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, AUTO_SOS_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Automatic SOS Triggered")
            .setContentText(reason)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setOngoing(false)
            .setFullScreenIntent(pendingIntent, true)
            .setContentIntent(pendingIntent)
            .build()

        NotificationManagerCompat.from(this).notify(9001, notification)

        try {
            startActivity(intent)
        } catch (e: Exception) {
            Log.w("SafetyService", "Unable to foreground app directly: ${e.message}")
        }
    }

    // =========================
    // CHANNEL
    // =========================
    private fun createNotificationChannel() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Safety Monitoring",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "Audio & safety monitoring"

            val autoSosChannel = NotificationChannel(
                AUTO_SOS_CHANNEL_ID,
                "Automatic SOS",
                NotificationManager.IMPORTANCE_HIGH
            )
            autoSosChannel.description = "Shows full-screen automatic SOS interruption"
            autoSosChannel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
            manager.createNotificationChannel(autoSosChannel)
        }
    }
}
