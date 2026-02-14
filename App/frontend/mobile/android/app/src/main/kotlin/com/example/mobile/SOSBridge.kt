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
                    val i = Intent(context, SafetyService::class.java)
                    context.startForegroundService(i)
                    result.success(null)
                }
                "stopService" -> {
                    context.stopService(Intent(context, SafetyService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun notifyServiceStopped() {
        methodChannel?.invokeMethod("onServiceStopped", null)
    }
}
