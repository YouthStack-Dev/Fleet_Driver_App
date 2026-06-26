package com.mlt.etsdriver

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "mlt_driver/tracking"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startBackgroundTracking" -> {
                        val serviceIntent = Intent(this, LocationForegroundService::class.java).apply {
                            action = LocationForegroundService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                    }
                    "stopBackgroundTracking" -> {
                        val serviceIntent = Intent(this, LocationForegroundService::class.java).apply {
                            action = LocationForegroundService.ACTION_STOP
                        }
                        startService(serviceIntent)
                        result.success(true)
                    }
                    "isTrackingRunning" -> {
                        result.success(LocationForegroundService.isServiceRunning)
                    }
                    "updateToken" -> {
                        val token = call.argument<String>("token")
                        if (token != null) {
                            val prefs = getSharedPreferences(LocationForegroundService.PREFS_NAME, Context.MODE_PRIVATE)
                            prefs.edit().putString(LocationForegroundService.KEY_TOKEN, token).apply()
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "Token is null", null)
                        }
                    }
                    "updateRoute" -> {
                        val routeId = call.argument<String>("routeId")
                        if (routeId != null) {
                            val prefs = getSharedPreferences(LocationForegroundService.PREFS_NAME, Context.MODE_PRIVATE)
                            prefs.edit().putString(LocationForegroundService.KEY_ROUTE_ID, routeId).apply()
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "Route ID is null", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
