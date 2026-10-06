package com.hazm.hazm_app

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat

class SessionService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var phase = ""

    private val ticker = object : Runnable {
        override fun run() {
            val session = FocusEngine.sync(this@SessionService)
            if (session == null) {
                shutdown()
                return
            }
            val next = if (session.paused) PHASE_BREAK else PHASE_FOCUS
            if (next != phase) {
                phase = next
                Notifications.updateSession(this@SessionService, session)
            }
            handler.postDelayed(this, TICK_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        running = true
        Notifications.ensureChannels(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val session = SessionStore.read(this)
        if (!promote(Notifications.session(this, session)) || session == null) {
            shutdown()
            return START_NOT_STICKY
        }
        phase = if (session.paused) PHASE_BREAK else PHASE_FOCUS
        handler.removeCallbacks(ticker)
        handler.postDelayed(ticker, TICK_MS)
        return START_STICKY
    }

    private fun promote(notification: Notification): Boolean = runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(Notifications.SESSION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(Notifications.SESSION_ID, notification)
        }
    }.onFailure { Log.w(TAG, "Session service could not enter the foreground", it) }.isSuccess

    private fun shutdown() {
        handler.removeCallbacks(ticker)
        runCatching { stopForeground(STOP_FOREGROUND_REMOVE) }
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacks(ticker)
        running = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val TAG = "HAZM"
        private const val TICK_MS = 1_000L
        private const val PHASE_FOCUS = "focus"
        private const val PHASE_BREAK = "break"

        @Volatile
        var running = false
            private set

        fun start(ctx: Context) {
            runCatching { ContextCompat.startForegroundService(ctx, Intent(ctx, SessionService::class.java)) }
                .onFailure { Log.w(TAG, "Session service could not start", it) }
        }

        fun stop(ctx: Context) {
            if (running) ctx.stopService(Intent(ctx, SessionService::class.java))
        }
    }
}
