package com.hazm.hazm_app

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import java.io.ByteArrayOutputStream

object AppCatalog {
    fun launchable(ctx: Context): List<Map<String, Any>> {
        val pm = ctx.packageManager
        val essentials = Essentials.resolve(ctx)
        return pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
            .asSequence()
            .mapNotNull { info -> info.activityInfo?.packageName?.let { it to info } }
            .filter { (name, _) -> name != ctx.packageName }
            .distinctBy { (name, _) -> name }
            .map { (name, info) ->
                mapOf(
                    "package" to name,
                    "label" to info.loadLabel(pm).toString().trim().ifEmpty { name },
                    "essential" to (name in essentials),
                )
            }
            .sortedBy { (it["label"] as String).lowercase() }
            .toList()
    }

    fun labels(ctx: Context, packages: List<String>): Map<String, String> {
        val pm = ctx.packageManager
        return packages.associateWith { name ->
            runCatching { pm.getApplicationLabel(pm.getApplicationInfo(name, 0)).toString() }.getOrDefault(name)
        }
    }

    fun icon(ctx: Context, packageName: String, size: Int): ByteArray? = runCatching {
        val drawable = ctx.packageManager.getApplicationIcon(packageName)
        val px = size.coerceIn(24, 256)
        val bitmap = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, px, px)
        drawable.draw(Canvas(bitmap))
        ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            bitmap.recycle()
            out.toByteArray()
        }
    }.getOrNull()
}
