package com.hazm.hazm_app

import android.annotation.SuppressLint
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings

object Background {
    private val autostartScreens = listOf(
        "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
        "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
        "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
        "com.hihonor.systemmanager" to "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
        "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
        "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
        "com.oplus.safecenter" to "com.oplus.safecenter.permission.startup.StartupAppListActivity",
        "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
        "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
        "com.transsion.phonemaster" to "com.cyin.himgr.autostart.AutoStartActivity",
    )

    @Volatile
    private var autostart: Intent? = null

    @Volatile
    private var resolved = false

    fun unrestricted(ctx: Context): Boolean =
        ctx.getSystemService(PowerManager::class.java)?.isIgnoringBatteryOptimizations(ctx.packageName) == true

    @SuppressLint("BatteryLife")
    fun exemptionIntent(ctx: Context): Intent =
        Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${ctx.packageName}"))

    fun optimizationSettingsIntent(): Intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)

    fun autostartIntent(ctx: Context): Intent? {
        if (resolved) return autostart
        autostart = autostartScreens.asSequence()
            .map { (pkg, cls) -> Intent().setComponent(ComponentName(pkg, cls)) }
            .firstOrNull { intent ->
                runCatching { ctx.packageManager.resolveActivity(intent, 0)?.activityInfo?.exported == true }
                    .getOrDefault(false)
            }
        resolved = true
        return autostart
    }
}
