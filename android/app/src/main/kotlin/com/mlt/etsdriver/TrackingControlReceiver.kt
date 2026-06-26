package com.mlt.etsdriver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class TrackingControlReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "MLT_ControlReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.i(TAG, "Control action: $action")

        val serviceIntent = Intent(context, LocationForegroundService::class.java).apply {
            this.action = action
        }

        when (action) {
            LocationForegroundService.ACTION_START -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
            LocationForegroundService.ACTION_STOP -> {
                context.startService(serviceIntent)  // Deliver STOP intent; service stops itself
            }
        }
    }
}
