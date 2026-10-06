package com.hazm.hazm_app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var gravity: EventChannel? = null
    private var sensor: GravityStream? = null
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(::handle)
        }
        sensor = GravityStream(this)
        gravity = EventChannel(flutterEngine.dartExecutor.binaryMessenger, GRAVITY_CHANNEL).also {
            it.setStreamHandler(sensor)
        }
        current = this
        capture(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (capture(intent)) channel?.invokeMethod("blocked", null)
    }

    override fun onResume() {
        super.onResume()
        isForeground = true
    }

    override fun onPause() {
        isForeground = false
        super.onPause()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        gravity?.setStreamHandler(null)
        gravity = null
        sensor?.stop()
        sensor = null
        if (current === this) current = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        if (current === this) current = null
        super.onDestroy()
    }

    private fun pushStatus() {
        channel?.invokeMethod("status", status())
    }

    private fun capture(intent: Intent?): Boolean {
        val blocked = intent?.getStringExtra(EXTRA_BLOCKED) ?: return false
        intent.removeExtra(EXTRA_BLOCKED)
        pendingBlocked = blocked
        return true
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status())
            "testGuard" -> result.success(AppBlockerAccessibilityService.preview())
            "version" -> result.success(versionName())
            "openUrl" -> result.success(
                call.argument<String>("url")?.let(Uri::parse)?.takeIf { it.scheme == "https" }
                    ?.let { open(Intent(Intent.ACTION_VIEW, it)) } ?: false,
            )
            "openAccessibilitySettings" -> result.success(open(AccessibilityState.settingsIntent(this)))
            "openAppDetails" -> result.success(
                open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))),
            )
            "openNotificationSettings" -> result.success(
                open(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)),
            )
            "openDndSettings" -> result.success(open(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)))
            "requestBatteryExemption" -> result.success(
                open(Background.exemptionIntent(this)) || open(Background.optimizationSettingsIntent()),
            )
            "openAutostart" -> result.success(Background.autostartIntent(this)?.let { open(it) } ?: false)
            "setLanguage" -> {
                SessionStore.setLanguage(this, call.argument<String>("code") ?: "en")
                Notifications.ensureChannels(this)
                SessionStore.read(this)?.takeIf { SessionService.running }?.let { Notifications.updateSession(this, it) }
                result.success(null)
            }
            "session" -> result.success(FocusEngine.sync(this, foreground = true)?.toMap())
            "start" -> {
                SessionStore.start(
                    this,
                    plannedMs = (call.argument<Int>("minutes") ?: 0) * 60_000L,
                    thresholdMinutes = call.argument<Int>("bonusThreshold") ?: 90,
                    dnd = call.argument<Boolean>("dnd") ?: false,
                    taskId = call.argument<String>("taskId"),
                    intention = call.argument<String>("intention"),
                )
                result.success(FocusEngine.sync(this, foreground = true)?.toMap())
            }
            "pause" -> {
                SessionStore.pause(this, call.argument<Int>("seconds") ?: 0)
                result.success(FocusEngine.sync(this, foreground = true)?.toMap())
            }
            "resume" -> {
                SessionStore.resume(this)
                result.success(FocusEngine.sync(this, foreground = true)?.toMap())
            }
            "extend" -> {
                SessionStore.extend(this, call.argument<Int>("minutes") ?: 5)
                val session = FocusEngine.sync(this, foreground = true)
                session?.takeIf { SessionService.running }?.let { Notifications.updateSession(this, it) }
                result.success(session?.toMap())
            }
            "breakSession" -> {
                SessionStore.breakSession(this)
                FocusEngine.sync(this)
                result.success(null)
            }
            "cancelSession" -> {
                SessionStore.cancel(this)
                FocusEngine.sync(this)
                result.success(null)
            }
            "takeResults" -> result.success(SessionStore.takeResults(this))
            "takeBlocked" -> result.success(takeBlocked())
            "allowedApps" -> result.success(SessionStore.allowedApps(this).toList())
            "setAllowedApps" -> {
                SessionStore.setAllowedApps(this, call.argument<List<String>>("packages").orEmpty())
                result.success(null)
            }
            "apps" -> background(result) { AppCatalog.launchable(this) }
            "labels" -> background(result) {
                AppCatalog.labels(this, call.argument<List<String>>("packages").orEmpty())
            }
            "icon" -> background(result) {
                AppCatalog.icon(this, call.argument<String>("package").orEmpty(), call.argument<Int>("size") ?: 96)
            }
            else -> result.notImplemented()
        }
    }

    private fun status(): Map<String, Any> {
        val manager = getSystemService(NotificationManager::class.java)
        return mapOf(
            "accessibility" to AccessibilityState.isEnabled(this),
            "running" to AccessibilityState.isRunning(this),
            "restricted" to AccessibilityState.isRestricted(this),
            "notifications" to NotificationManagerCompat.from(this).areNotificationsEnabled(),
            "dndAccess" to (manager?.isNotificationPolicyAccessGranted == true),
            "battery" to Background.unrestricted(this),
            "autostart" to (Background.autostartIntent(this) != null),
            "sdk" to Build.VERSION.SDK_INT,
        )
    }

    private fun takeBlocked(): Map<String, String>? {
        val blocked = pendingBlocked ?: return null
        pendingBlocked = null
        return mapOf("package" to blocked, "label" to (AppCatalog.labels(this, listOf(blocked))[blocked] ?: blocked))
    }

    private fun open(intent: Intent): Boolean = runCatching { startActivity(intent) }.isSuccess

    @Suppress("DEPRECATION")
    private fun versionName(): String? = runCatching {
        if (Build.VERSION.SDK_INT >= 33) {
            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0)).versionName
        } else {
            packageManager.getPackageInfo(packageName, 0).versionName
        }
    }.getOrNull()

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        runCatching {
            worker.execute {
                val outcome = runCatching(work)
                main.post {
                    outcome.fold(
                        onSuccess = { result.success(it) },
                        onFailure = { result.error("hazm", it.message, null) },
                    )
                }
            }
        }.onFailure { result.error("hazm", it.message, null) }
    }

    companion object {
        private const val CHANNEL = "com.hazm.hazm_app/blocker"
        private const val GRAVITY_CHANNEL = "com.hazm.hazm_app/gravity"
        private const val EXTRA_BLOCKED = "com.hazm.hazm_app.BLOCKED"
        private val worker: ExecutorService = Executors.newSingleThreadExecutor()

        @Volatile
        var isForeground = false
            private set

        @Volatile
        private var pendingBlocked: String? = null

        @Volatile
        private var current: MainActivity? = null

        fun notifyStatus() {
            val activity = current ?: return
            activity.main.post { if (current === activity) activity.pushStatus() }
        }

        fun blockedIntent(ctx: Context, packageName: String): Intent = Intent(ctx, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(EXTRA_BLOCKED, packageName)
    }
}
