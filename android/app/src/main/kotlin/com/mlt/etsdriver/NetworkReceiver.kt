package com.mlt.etsdriver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.util.Log

class NetworkReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "MLT_NetworkReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val networkType = getNetworkType(context)
        if (networkType == "Offline") return   // Ignore disconnection events

        Log.i(TAG, "Network reconnected ($networkType)")

        // 1. Guard: If service is already running, do nothing
        if (LocationForegroundService.isServiceRunning) {
            Log.d(TAG, "LocationForegroundService is already running. Skipping restart.")
            return
        }

        val prefs = context.getSharedPreferences(
            LocationForegroundService.PREFS_NAME, Context.MODE_PRIVATE
        )
        val routeId = prefs.getString(LocationForegroundService.KEY_ROUTE_ID, "") ?: ""
        val token = prefs.getString(LocationForegroundService.KEY_TOKEN, "") ?: ""

        // 3. Verify location permission
        val hasGpsPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true // Legacy support
        }

        // 2. Ensure Route ID, Token, and Permission are present before starting
        if (routeId.isNotEmpty() && token.isNotEmpty() && hasGpsPermission) {
            Log.i(TAG, "Active route ($routeId), token, and permissions found — restarting tracking service")
            val serviceIntent = Intent(context, LocationForegroundService::class.java).apply {
                action = LocationForegroundService.ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } else {
            Log.i(TAG, "Checks failed for restart: route=$routeId, token=${token.isNotEmpty()}, permission=$hasGpsPermission — service not started")
        }
    }

    private fun getNetworkType(context: Context): String {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val activeNet = cm.activeNetwork ?: return "Offline"
            val caps = cm.getNetworkCapabilities(activeNet) ?: return "Offline"
            return when {
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "WiFi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "Cellular"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> "VPN"
                else -> "Other"
            }
        } else {
            @Suppress("DEPRECATION")
            val info = cm.activeNetworkInfo
            if (info == null || !info.isConnected) return "Offline"
            return when (info.type) {
                ConnectivityManager.TYPE_WIFI -> "WiFi"
                ConnectivityManager.TYPE_MOBILE -> "Cellular"
                else -> "Other"
            }
        }
    }
}
