package com.hazm.hazm_app

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.accessibility.AccessibilityManager

object AccessibilityState {
    private const val FRAGMENT_ARGS_KEY = ":settings:fragment_args_key"
    private const val SHOW_FRAGMENT_ARGS = ":settings:show_fragment_args"
    private const val PLAY_STORE = "com.android.vending"

    fun component(ctx: Context) = ComponentName(ctx.packageName, AppBlockerAccessibilityService::class.java.name)

    fun isRunning(ctx: Context): Boolean = AppBlockerAccessibilityService.connected || isBound(ctx)

    fun isEnabled(ctx: Context): Boolean = isRunning(ctx) || isListed(ctx)

    fun isRestricted(ctx: Context): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && installer(ctx) != PLAY_STORE

    private fun isBound(ctx: Context): Boolean {
        val manager = ctx.getSystemService(AccessibilityManager::class.java) ?: return false
        val expected = component(ctx)
        return runCatching {
            manager.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK).any { info ->
                val service = info.resolveInfo?.serviceInfo
                service != null && service.packageName == expected.packageName && service.name == expected.className
            }
        }.getOrDefault(false)
    }

    private fun isListed(ctx: Context): Boolean {
        val raw = Settings.Secure.getString(ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            ?: return false
        val expected = component(ctx)
        val simpleName = expected.className.substringAfterLast('.')
        return raw.split(':').any { entry ->
            val name = ComponentName.unflattenFromString(entry.trim())
            name != null && name.packageName == expected.packageName && name.className.substringAfterLast('.') == simpleName
        }
    }

    private fun installer(ctx: Context): String? = runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            ctx.packageManager.getInstallSourceInfo(ctx.packageName).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            ctx.packageManager.getInstallerPackageName(ctx.packageName)
        }
    }.getOrNull()

    fun settingsIntent(ctx: Context): Intent {
        val key = component(ctx).flattenToString()
        return Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .putExtra(FRAGMENT_ARGS_KEY, key)
            .putExtra(SHOW_FRAGMENT_ARGS, Bundle().apply { putString(FRAGMENT_ARGS_KEY, key) })
    }
}
