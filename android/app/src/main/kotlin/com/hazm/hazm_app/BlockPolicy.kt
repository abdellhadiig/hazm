package com.hazm.hazm_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.AlarmClock
import android.provider.Settings
import android.provider.Telephony
import android.telecom.TelecomManager

object Essentials {
    private val fixed = setOf(
        "android",
        "com.android.systemui",
        "com.android.settings",
        "com.samsung.accessibility",
        "com.android.contacts",
        "com.google.android.contacts",
        "com.samsung.android.contacts",
        "com.android.mms",
        "com.android.messaging",
        "com.google.android.apps.messaging",
        "com.samsung.android.messaging",
        "com.android.deskclock",
        "com.google.android.deskclock",
        "com.sec.android.app.clockpackage",
        "com.android.packageinstaller",
        "com.google.android.packageinstaller",
        "com.miui.packageinstaller",
        "com.android.permissioncontroller",
        "com.google.android.permissioncontroller",
        "com.android.documentsui",
        "com.google.android.documentsui",
        "com.android.intentresolver",
    )

    private val tools = setOf(
        "com.google.android.calculator",
        "com.android.calculator2",
        "com.sec.android.app.popupcalculator",
        "com.miui.calculator",
        "com.coloros.calculator",
        "com.oneplus.calculator",
        "com.android.bbkcalculator",
        "com.transsion.calculator",
        "com.google.android.keep",
        "com.samsung.android.app.notes",
        "com.miui.notes",
        "com.coloros.note",
        "com.oneplus.note",
        "com.huawei.notepad",
        "com.hihonor.notepad",
        "com.android.notes",
        "com.transsion.notebook",
        "com.socialnmobile.dictapp.notepad.color.note",
        "com.microsoft.office.onenote",
        "com.evernote",
        "notion.id",
        "md.obsidian",
        "org.fossify.notes",
    )

    private val urgentFixed = setOf(
        "com.android.phone",
        "com.android.server.telecom",
        "com.android.dialer",
        "com.android.incallui",
        "com.google.android.dialer",
        "com.samsung.android.dialer",
        "com.samsung.android.incallui",
        "com.android.emergency",
        "com.google.android.apps.safetyhub",
        "com.android.cellbroadcastreceiver",
        "com.google.android.cellbroadcastreceiver",
    )

    private val toolCategories = listOf(
        Intent.CATEGORY_APP_CALCULATOR,
        Intent.CATEGORY_APP_CALENDAR,
        Intent.CATEGORY_APP_CONTACTS,
    )

    fun resolve(ctx: Context): Set<String> {
        val result = HashSet(fixed)
        result += tools
        result += urgent(ctx)
        result += handlers(ctx, Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME))
        result += handlers(ctx, Intent(Settings.ACTION_SETTINGS))
        result += handlers(ctx, Intent(AlarmClock.ACTION_SHOW_ALARMS))
        result += handlers(ctx, Intent(Intent.ACTION_DELETE, Uri.parse("package:${ctx.packageName}")))
        toolCategories.forEach { category ->
            result += handlers(ctx, Intent(Intent.ACTION_MAIN).addCategory(category))
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            result += handlers(ctx, Intent(Intent.ACTION_CREATE_NOTE))
        }
        result += inputMethods(ctx)
        runCatching { Telephony.Sms.getDefaultSmsPackage(ctx) }.getOrNull()?.let(result::add)
        return result
    }

    fun urgent(ctx: Context): Set<String> {
        val result = HashSet(urgentFixed)
        ctx.getSystemService(TelecomManager::class.java)?.let { telecom ->
            runCatching { telecom.defaultDialerPackage }.getOrNull()?.let(result::add)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                runCatching { telecom.systemDialerPackage }.getOrNull()?.let(result::add)
            }
        }
        return result
    }

    private fun handlers(ctx: Context, intent: Intent): List<String> = runCatching {
        ctx.packageManager.queryIntentActivities(intent, 0).mapNotNull { it.activityInfo?.packageName }
    }.getOrDefault(emptyList())

    private fun inputMethods(ctx: Context): List<String> = runCatching {
        val resolver = ctx.contentResolver
        listOfNotNull(
            Settings.Secure.getString(resolver, Settings.Secure.DEFAULT_INPUT_METHOD),
            Settings.Secure.getString(resolver, Settings.Secure.ENABLED_INPUT_METHODS),
        )
            .joinToString(":")
            .split(':')
            .map { it.substringBefore(';').substringBefore('/').trim() }
            .filter { it.isNotEmpty() }
    }.getOrDefault(emptyList())
}

class BlockPolicy(private val ctx: Context) {
    private val launchable = HashMap<String, Boolean>()
    private var essentials: Set<String> = emptySet()
    private var urgent: Set<String> = emptySet()
    private var allowed: Set<String> = emptySet()
    private var version = Int.MIN_VALUE
    private var refreshedAt = 0L

    fun shouldBlock(packageName: String): Boolean {
        refreshIfNeeded()
        if (packageName == ctx.packageName) return false
        if (packageName in essentials || packageName in allowed) return false
        return launchable.getOrPut(packageName) {
            ctx.packageManager.getLaunchIntentForPackage(packageName) != null
        }
    }

    fun isUrgent(packageName: String): Boolean {
        refreshIfNeeded()
        return packageName in urgent
    }

    private fun refreshIfNeeded() {
        val current = SessionStore.policyVersion(ctx)
        val now = SystemClock.elapsedRealtime()
        if (current == version && now - refreshedAt < REFRESH_INTERVAL_MS) return
        version = current
        refreshedAt = now
        essentials = Essentials.resolve(ctx)
        urgent = Essentials.urgent(ctx)
        allowed = SessionStore.allowedApps(ctx)
        launchable.clear()
    }

    private companion object {
        const val REFRESH_INTERVAL_MS = 60_000L
    }
}
