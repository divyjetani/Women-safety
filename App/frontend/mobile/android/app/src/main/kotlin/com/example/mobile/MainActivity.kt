package com.example.mobile

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val PERMISSION_REQ = 101
    private val LOCATION_PERMISSION_REQ = 102
    private val BG_LOCATION_CHANNEL = "com.example.mobile/bg_location"
    private val SOS_TRIGGER_CHANNEL = "sos_trigger"
    private val SECURE_SCREEN_CHANNEL = "com.example.mobile/secure_screen"

    private var sosChannel: MethodChannel? = null
    private var pendingAutoSosReason: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SOSBridge.register(flutterEngine, this)

        sosChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOS_TRIGGER_CHANNEL)
        sosChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingAutoSOS" -> {
                    val reason = pendingAutoSosReason
                    if (reason == null) {
                        result.success(null)
                    } else {
                        pendingAutoSosReason = null
                        result.success(mapOf(
                            "pending" to true,
                            "reason" to reason
                        ))
                    }
                }
                "clearPendingAutoSOS" -> {
                    pendingAutoSosReason = null
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // Register background location method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BG_LOCATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startLocationSharing" -> {
                        val bubbleCode = call.argument<String>("bubbleCode")
                        val userId = call.argument<Int>("userId")
                        val incognito = call.argument<Boolean>("incognito") ?: false

                        if (bubbleCode.isNullOrBlank() || userId == null || userId <= 0) {
                            result.error(
                                "INVALID_ARGS",
                                "bubbleCode/userId is missing for background location service",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        val prefs = getSharedPreferences("bubble_app", MODE_PRIVATE)
                        val saved = prefs.edit()
                            .putString("selected_bubble_code", bubbleCode)
                            .putInt("user_id", userId)
                            .putBoolean("incognito_mode", incognito)
                            .commit()

                        if (!saved) {
                            result.error(
                                "PREF_WRITE_FAILED",
                                "Failed to persist background location context",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        
                        // Request location permission first
                        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION,
                                Manifest.permission.FOREGROUND_SERVICE
                            )
                        } else {
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION
                            )
                        }
                        
                        val missing = permission.filter {
                            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
                        }
                        
                        if (missing.isNotEmpty()) {
                            ActivityCompat.requestPermissions(this, missing.toTypedArray(), LOCATION_PERMISSION_REQ)
                        }
                        
                        // Start the LocationSharingService
                        val intent = Intent(this, LocationSharingService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        
                        result.success(true)
                    }
                    "stopLocationSharing" -> {
                        val intent = Intent(this, LocationSharingService::class.java)
                        stopService(intent)
                        result.success(true)
                    }
                    "setIncognito" -> {
                        val incognito = call.argument<Boolean>("incognito") ?: false
                        val prefs = getSharedPreferences("bubble_app", MODE_PRIVATE)
                        prefs.edit().putBoolean("incognito_mode", incognito).apply()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_SCREEN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    }
                    "disable" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureAutoSosFromIntent(intent)
        requestCriticalPermissions()
    }

    private fun captureAutoSosFromIntent(intent: Intent?) {
        if (intent == null) return

        if (intent.getBooleanExtra("AUTO_SOS", false)) {
            val reason = intent.getStringExtra("AUTO_SOS_REASON")
                ?: "Automatic risk trigger detected"
            pendingAutoSosReason = reason
            triggerAutoSosVibration()
            Log.i("MainActivity", "Queued AUTO_SOS intent | reason=$reason")
        }
    }

    private fun triggerAutoSosVibration() {
        val vibrator = getSystemService(VIBRATOR_SERVICE) as? Vibrator ?: return
        if (!vibrator.hasVibrator()) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 400, 180, 400, 180, 400), -1))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(longArrayOf(0, 400, 180, 400, 180, 400), -1)
        }
    }

    private fun dispatchPendingAutoSosIfPossible() {
        val reason = pendingAutoSosReason ?: return
        val channel = sosChannel ?: return

        try {
            channel.invokeMethod("autoSOS", mapOf("reason" to reason))
            Log.i("MainActivity", "Dispatched AUTO_SOS to Flutter")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed dispatching AUTO_SOS to Flutter: ${e.message}")
        }
    }

    private fun requestCriticalPermissions() {
        val permissions = arrayOf(
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.ACCESS_FINE_LOCATION
        )

        val missing = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                missing.toTypedArray(),
                PERMISSION_REQ
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == PERMISSION_REQ || requestCode == LOCATION_PERMISSION_REQ) {
            permissions.forEachIndexed { index, perm ->
                if (grantResults[index] != PackageManager.PERMISSION_GRANTED) {
                    android.util.Log.e(
                        "PERMISSION",
                        "Permission denied: $perm"
                    )
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureAutoSosFromIntent(intent)
        dispatchPendingAutoSosIfPossible()
    }
}
