package com.hazm.hazm_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat

object Notifications {
    const val SESSION_ID = 1001
    private const val COMPLETED_ID = 1002
    private const val GUARD_ID = 1003
    private const val SESSION_CHANNEL = "hazm_session"
    private const val UPDATES_CHANNEL = "hazm_updates"
    private const val ALERTS_CHANNEL = "hazm_alerts"
    private const val LEGACY_CHANNEL = "hazm_blocker_channel"
    private const val BRAND = 0xFFF96B06.toInt()

    fun ensureChannels(ctx: Context) {
        val manager = ctx.getSystemService(NotificationManager::class.java) ?: return
        manager.deleteNotificationChannel(LEGACY_CHANNEL)
        manager.createNotificationChannel(
            NotificationChannel(SESSION_CHANNEL, NativeStrings.sessionChannel(ctx), NotificationManager.IMPORTANCE_LOW).apply {
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(UPDATES_CHANNEL, NativeStrings.updatesChannel(ctx), NotificationManager.IMPORTANCE_DEFAULT),
        )
        manager.createNotificationChannel(
            NotificationChannel(ALERTS_CHANNEL, NativeStrings.alertsChannel(ctx), NotificationManager.IMPORTANCE_HIGH),
        )
    }

    fun session(ctx: Context, session: Session?): Notification {
        val builder = NotificationCompat.Builder(ctx, SESSION_CHANNEL)
            .setSmallIcon(R.drawable.ic_hazm_notification)
            .setColor(BRAND)
            .setOngoing(true)
            .setSilent(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(openApp(ctx))
        if (session == null) return builder.setContentTitle("HAZM").build()
        return builder
            .setContentTitle(if (session.paused) NativeStrings.breakTitle(ctx) else NativeStrings.focusTitle(ctx))
            .setContentText(
                if (session.paused) NativeStrings.breakText(ctx) else NativeStrings.focusText(ctx, session.intention),
            )
            .setWhen(System.currentTimeMillis() + session.nextEventMs)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .build()
    }

    fun updateSession(ctx: Context, session: Session) {
        if (!canPost(ctx)) return
        ctx.getSystemService(NotificationManager::class.java)?.notify(SESSION_ID, session(ctx, session))
    }

    fun showCompleted(ctx: Context, focusedMs: Long) {
        if (!canPost(ctx)) return
        ensureChannels(ctx)
        val notification = NotificationCompat.Builder(ctx, UPDATES_CHANNEL)
            .setSmallIcon(R.drawable.ic_hazm_notification)
            .setColor(BRAND)
            .setContentTitle(NativeStrings.completedTitle(ctx))
            .setContentText(NativeStrings.completedText(ctx, focusedMs / 60_000))
            .setAutoCancel(true)
            .setContentIntent(openApp(ctx))
            .build()
        ctx.getSystemService(NotificationManager::class.java)?.notify(COMPLETED_ID, notification)
    }

    fun showGuard(ctx: Context) {
        if (!canPost(ctx)) return
        ensureChannels(ctx)
        val text = NativeStrings.guardText(ctx)
        val notification = NotificationCompat.Builder(ctx, ALERTS_CHANNEL)
            .setSmallIcon(R.drawable.ic_hazm_notification)
            .setColor(BRAND)
            .setContentTitle(NativeStrings.guardTitle(ctx))
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)
            .setContentIntent(
                PendingIntent.getActivity(
                    ctx,
                    GUARD_ID,
                    AccessibilityState.settingsIntent(ctx),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
            .build()
        ctx.getSystemService(NotificationManager::class.java)?.notify(GUARD_ID, notification)
    }

    fun cancelGuard(ctx: Context) {
        ctx.getSystemService(NotificationManager::class.java)?.cancel(GUARD_ID)
    }

    private fun canPost(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun openApp(ctx: Context): PendingIntent = PendingIntent.getActivity(
        ctx,
        0,
        Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
}
