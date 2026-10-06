package com.hazm.hazm_app

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import kotlin.math.abs

object FocusEngine {
    private const val GUARD_GRACE_MS = 5_000L
    private var scheduledAt = 0L
    private var blocking = false
    private var exposedSince = 0L
    private var alerted = false

    fun sync(context: Context, foreground: Boolean = false): Session? {
        val ctx = context.applicationContext
        val guarded = AccessibilityState.isRunning(ctx)
        val finished = SessionStore.tick(ctx, guarded)
        val session = SessionStore.read(ctx)
        FocusDnd.sync(ctx, session != null && session.dnd && session.blocking)
        val active = session?.blocking == true
        if (active != blocking) {
            blocking = active
            AppBlockerAccessibilityService.refresh()
        }
        if (session == null) {
            SessionService.stop(ctx)
            SessionAlarm.cancel(ctx)
            scheduledAt = 0
            watch(ctx, exposed = false)
            if (finished?.outcome == Outcome.COMPLETED && !MainActivity.isForeground) {
                Notifications.showCompleted(ctx, finished.focusedMs)
            }
            return null
        }
        if (foreground && !SessionService.running) SessionService.start(ctx)
        watch(ctx, exposed = session.blocking && !guarded)
        val target = SystemClock.elapsedRealtime() + session.nextEventMs + 250
        if (abs(target - scheduledAt) > 2_000) {
            SessionAlarm.schedule(ctx, target)
            scheduledAt = target
        }
        return session
    }

    private fun watch(ctx: Context, exposed: Boolean) {
        if (!exposed) {
            exposedSince = 0
            if (alerted) Notifications.cancelGuard(ctx)
            alerted = false
            return
        }
        val now = SystemClock.elapsedRealtime()
        if (exposedSince == 0L) exposedSince = now
        if (alerted || now - exposedSince < GUARD_GRACE_MS) return
        alerted = true
        Notifications.showGuard(ctx)
    }
}

object FocusDnd {
    private const val PREFS = "hazm_blocker"
    private const val APPLIED = "dnd_applied"

    fun sync(ctx: Context, want: Boolean) {
        val manager = ctx.getSystemService(NotificationManager::class.java) ?: return
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val applied = prefs.getBoolean(APPLIED, false)
        if (want == applied) return
        val granted = manager.isNotificationPolicyAccessGranted
        if (want) {
            if (!granted || manager.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL) return
            runCatching { manager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY) }
                .onSuccess { prefs.edit().putBoolean(APPLIED, true).apply() }
        } else {
            if (granted && manager.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_PRIORITY) {
                runCatching { manager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL) }
            }
            prefs.edit().putBoolean(APPLIED, false).apply()
        }
    }
}

object SessionAlarm {
    private const val ACTION = "com.hazm.hazm_app.SESSION_ALARM"

    private fun pending(ctx: Context): PendingIntent = PendingIntent.getBroadcast(
        ctx,
        7,
        Intent(ctx, SessionAlarmReceiver::class.java).setAction(ACTION),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    fun schedule(ctx: Context, elapsedRealtime: Long) {
        val manager = ctx.getSystemService(AlarmManager::class.java) ?: return
        runCatching { manager.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, elapsedRealtime, pending(ctx)) }
    }

    fun cancel(ctx: Context) {
        ctx.getSystemService(AlarmManager::class.java)?.cancel(pending(ctx))
    }
}

class SessionAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        FocusEngine.sync(context)
    }
}
