package com.example.mobile

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.android.volley.Request
import com.android.volley.RequestQueue
import com.android.volley.VolleyError
import com.android.volley.toolbox.JsonObjectRequest
import com.android.volley.toolbox.Volley
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.tasks.CancellationToken
import com.google.android.gms.tasks.OnTokenCanceledListener
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import org.json.JSONObject

class LocationSharingService : Service() {

    companion object {
        const val NOTIFICATION_ID = 102
        const val NOTIFICATION_CHANNEL_ID = "location_sharing_channel"
        const val ACTION_STOP = "com.example.mobile.STOP_LOCATION_SHARING"
        private const val LOCATION_UPDATE_INTERVAL = 5000L  // 5 seconds
        private const val TAG = "LocationSharingService"
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var handler: Handler
    private lateinit var prefs: SharedPreferences
    private lateinit var requestQueue: RequestQueue
    private var running = true

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "🚀 LocationSharingService created")

        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        handler = Handler(Looper.getMainLooper())
        prefs = getSharedPreferences("bubble_app", Context.MODE_PRIVATE)
        requestQueue = Volley.newRequestQueue(this)

        val backendBase = resolveBackendBaseUrl()
        if (backendBase == null) {
            Log.w(TAG, "⚠️ Missing/invalid server IP in SharedPreferences (ip_address)")
        }

        createNotificationChannel()
        val notification = buildNotification("Location sharing active")
        startForeground(NOTIFICATION_ID, notification)

        // Start the location sharing loop
        startLocationSharing()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                Log.i(TAG, "🛑 LocationSharingService stopping")
                running = false
                requestQueue.cancelAll { true }
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        Log.i(TAG, "💀 LocationSharingService destroyed")
        running = false
        handler.removeCallbacksAndMessages(null)
        requestQueue.cancelAll { true }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ===========================
    // LOCATION SHARING LOGIC
    // ===========================
    private fun startLocationSharing() {
        val runnable = object : Runnable {
            override fun run() {
                if (running) {
                    try {
                        // Check if incognito mode is enabled
                        val incognito = prefs.getBoolean("incognito_mode", false)
                        if (incognito) {
                            Log.d(TAG, "🔍 Incognito mode ON - not sharing location")
                        } else {
                            requestCurrentLocation()
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Error in location sharing: ${e.message}")
                    }

                    // Schedule next update
                    handler.postDelayed(this, LOCATION_UPDATE_INTERVAL)
                }
            }
        }
        handler.post(runnable)
    }

    private fun requestCurrentLocation() {
        try {
            val locationRequest = LocationRequest.create().apply {
                priority = LocationRequest.PRIORITY_HIGH_ACCURACY
                interval = LOCATION_UPDATE_INTERVAL
            }

            fusedLocationClient.getCurrentLocation(
                locationRequest.priority,
                object : CancellationToken() {
                    override fun onCanceledRequested(callback: OnTokenCanceledListener): CancellationToken = this
                    override fun isCancellationRequested(): Boolean = false
                }
            ).addOnSuccessListener { location: Location? ->
                if (location != null) {
                    shareLocation(location)
                } else {
                    Log.w(TAG, "⚠️ Location is null")
                }
            }.addOnFailureListener { e: Exception ->
                Log.e(TAG, "❌ Failed to get location: ${e.message}")
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security exception: ${e.message}")
        }
    }

    private fun shareLocation(location: Location) {
        var bubbleCode = prefs.getString("selected_bubble_code", null)
        var userId = prefs.getInt("user_id", -1)
        val incognito = prefs.getBoolean("incognito_mode", false)

        if (bubbleCode.isNullOrBlank() || userId <= 0) {
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            bubbleCode = bubbleCode ?: flutterPrefs.getString("flutter.selected_bubble_code", null)
            userId = if (userId > 0) {
                userId
            } else {
                (flutterPrefs.all["flutter.cached_user_id"] as? Number)?.toInt() ?: -1
            }
        }

        if (bubbleCode.isNullOrBlank() || userId <= 0) {
            Log.w(TAG, "⚠️ No bubble code or user ID - cannot share location")
            return
        }

        try {
            // Create request body matching ShareReq schema
            val body = JSONObject().apply {
                put("user_id", userId)
                put("lat", location.latitude)
                put("lng", location.longitude)
                put("battery", getBatteryPercentage())
                put("incognito", incognito)
            }

            val backendBase = resolveBackendBaseUrl()
            if (backendBase == null) {
                Log.w(TAG, "⚠️ Cannot share location: backend URL missing/invalid")
                return
            }
            val url = "$backendBase/bubble/share-location"

            val request = object : JsonObjectRequest(
                Method.POST, url, body,
                { response: JSONObject ->
                    Log.d(TAG, "✅ Location shared: ${location.latitude}, ${location.longitude}")
                },
                { error: VolleyError ->
                    Log.w(TAG, "⚠️ Failed to share location: ${error.message}")
                }
            ) {
                override fun getHeaders(): MutableMap<String, String> {
                    return mutableMapOf(
                        "Content-Type" to "application/json"
                    )
                }
            }

            requestQueue.add(request)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error sharing location: ${e.message}")
        }
    }

    private fun resolveBackendBaseUrl(): String? {
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = (flutterPrefs.getString("flutter.ip_address", "") ?: "").trim()
        if (raw.isEmpty()) return null

        val withScheme = if (raw.startsWith("http://") || raw.startsWith("https://")) {
            raw
        } else {
            "http://$raw"
        }

        val parsed = withScheme.toHttpUrlOrNull() ?: return null
        return parsed.newBuilder()
            .encodedPath("/")
            .query(null)
            .fragment(null)
            .build()
            .toString()
            .trimEnd('/')
    }

    private fun getBatteryPercentage(): Int {
        return try {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
            batteryManager.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } catch (e: Exception) {
            100
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Location Sharing",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background location sharing with your selected bubble"
            }
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val openAppPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Location Sharing")
            .setContentText("Sharing your live location in background")
            .setSmallIcon(android.R.drawable.ic_dialog_map)
            .setContentIntent(openAppPendingIntent)
            .setOngoing(true)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Stop Location",
                PendingIntent.getService(
                    this,
                    0,
                    Intent(this, LocationSharingService::class.java).apply {
                        action = ACTION_STOP
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
            .build()
    }
}
