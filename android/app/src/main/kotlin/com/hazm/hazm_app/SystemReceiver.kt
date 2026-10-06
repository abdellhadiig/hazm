package com.hazm.hazm_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SystemReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> FocusEngine.sync(context, foreground = true)
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> FocusEngine.sync(context)
                ?.takeIf { SessionService.running }
                ?.let { Notifications.updateSession(context, it) }
        }
    }
}
