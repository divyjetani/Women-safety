package com.example.mobile

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val PERMISSION_REQ = 101
    private val LOCATION_PERMISSION_REQ = 102
    private val BG_LOCATION_CHANNEL = "com.example.mobile/bg_location"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SOSBridge.register(flutterEngine, this)
        
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
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestCriticalPermissions()
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

        if (intent.getBooleanExtra("AUTO_SOS", false)) {
            MethodChannel(
                flutterEngine!!.dartExecutor.binaryMessenger,
                "sos_trigger"
            ).invokeMethod("autoSOS", null)
        }
    }
}
