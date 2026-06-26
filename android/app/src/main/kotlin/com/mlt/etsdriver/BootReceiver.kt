package com.mlt.etsdriver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "MLT_BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.i(TAG, "onReceive: $action")

        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON" -> {
                // HTC devices use QUICKBOOT_POWERON instead of BOOT_COMPLETED
                checkAndStartService(context)
            }
        }
    }

    private fun checkAndStartService(context: Context) {
        val prefs = context.getSharedPreferences(
            LocationForegroundService.PREFS_NAME, Context.MODE_PRIVATE
        )
        val routeId = prefs.getString(LocationForegroundService.KEY_ROUTE_ID, "") ?: ""
        val token = prefs.getString(LocationForegroundService.KEY_TOKEN, "") ?: ""

        val hasGpsPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true // Legacy support
        }

        if (routeId.isNotEmpty() && token.isNotEmpty() && hasGpsPermission) {
            Log.i(TAG, "Active route ($routeId), token, and permissions found after boot — restarting tracking service")
            val serviceIntent = Intent(context, LocationForegroundService::class.java).apply {
                action = LocationForegroundService.ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } else {
            Log.i(TAG, "Boot checks failed: route=$routeId, token=${token.isNotEmpty()}, permission=$hasGpsPermission — service not started")
        }
    }
}
