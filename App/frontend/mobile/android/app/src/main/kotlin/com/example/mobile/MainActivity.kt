package com.example.mobile

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val PERMISSION_REQ = 101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SOSBridge.register(flutterEngine, this)
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

        if (requestCode == PERMISSION_REQ) {
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

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)

        if (intent.getBooleanExtra("AUTO_SOS", false)) {
            MethodChannel(
                flutterEngine!!.dartExecutor.binaryMessenger,
                "sos_trigger"
            ).invokeMethod("autoSOS", null)
        }
    }
}
