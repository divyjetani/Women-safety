package com.example.mobile

import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import android.content.Context

object SOSBridge {
    private var methodChannel: MethodChannel? = null

    fun register(engine: FlutterEngine, context: Context) {
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "safety_service")
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    try {
                        val i = Intent(context, SafetyService::class.java)
                        context.startForegroundService(i)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error(
                            "START_SERVICE_FAILED",
                            e.message ?: "Unable to start safety service",
                            null
                        )
                    }
                }
                "stopService" -> {
                    try {
                        context.stopService(Intent(context, SafetyService::class.java))
                        context.stopService(Intent(context, LocationSharingService::class.java))
                        result.success(null)
                    } catch (e: Exception) {
                        result.error(
                            "STOP_SERVICE_FAILED",
                            e.message ?: "Unable to stop safety service",
                            null
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun notifyServiceStopped() {
        methodChannel?.invokeMethod("onServiceStopped", null)
    }
}
