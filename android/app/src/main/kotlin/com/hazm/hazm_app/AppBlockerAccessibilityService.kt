package com.hazm.hazm_app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Intent
import android.content.res.Configuration
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityWindowInfo
import android.widget.Toast

class AppBlockerAccessibilityService : AccessibilityService() {
    private val main = Handler(Looper.getMainLooper())
    private val thread = HandlerThread("hazm-guard").also { it.start() }
    private val worker = Handler(thread.looper)
    private val owners = HashMap<Int, String>()
    private val activities = HashMap<String, Boolean>()
    private val labels = HashMap<String, String>()
    private val policy by lazy { BlockPolicy(this) }
    private val overlay by lazy { LockOverlay(this, ::openOptions) }
    private val tick = Runnable { sweep() }
    private var lastPackage = ""
    private var lastBlockedAt = 0L
    private var lastHomeAt = 0L
    private var lastToastAt = 0L
    private var lastRestoreAt = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        serviceInfo?.let { info ->
            info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or AccessibilityEvent.TYPE_WINDOWS_CHANGED
            info.flags = info.flags or
                AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            info.notificationTimeout = 0
            serviceInfo = info
        }
        instance = this
        connected = true
        restoreSession(force = true)
        sweep()
        MainActivity.notifyStatus()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        when (event?.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> onWindow(event)
            AccessibilityEvent.TYPE_WINDOWS_CHANGED -> later()
        }
    }

    private fun onWindow(event: AccessibilityEvent) {
        val name = event.packageName?.toString() ?: return
        if (name == packageName) return
        val session = guarded() ?: return
        if (policy.isUrgent(name)) {
            overlay.hide()
            return
        }
        if (isAppWindow(name, event) && policy.shouldBlock(name)) block(name, session) else later()
    }

    private fun later() {
        main.removeCallbacks(tick)
        main.postDelayed(tick, SWEEP_DELAY_MS)
    }

    private fun sweep() {
        main.removeCallbacks(tick)
        guarded() ?: return
        main.postDelayed(tick, WATCH_MS)
        if (!interactive()) return
        worker.post {
            val apps = visibleApps()
            main.post { decide(apps) }
        }
    }

    private fun decide(apps: List<String>) {
        if (instance !== this) return
        if (apps.any(policy::isUrgent)) {
            overlay.hide()
            return
        }
        val target = apps.firstOrNull { it != packageName && policy.shouldBlock(it) } ?: return
        val session = SessionStore.read(this)?.takeIf { it.blocking } ?: return
        block(target, session)
    }

    private fun guarded(): Session? {
        val session = SessionStore.read(this)
        if (session != null && !SessionService.running) restoreSession()
        if (session?.blocking == true) return session
        overlay.hide()
        return null
    }

    private fun block(target: String, session: Session) {
        val now = SystemClock.uptimeMillis()
        if (target != lastPackage || now - lastBlockedAt > REPEAT_WINDOW_MS) SessionStore.recordAttempt(this, target)
        lastPackage = target
        lastBlockedAt = now
        val shown = overlay.show(LockOverlay.Content.blocked(this, label(target), target, session))
        if (now - lastHomeAt >= HOME_GAP_MS) {
            lastHomeAt = now
            performGlobalAction(GLOBAL_ACTION_HOME)
        }
        if (!shown) toast(now)
    }

    private fun visibleApps(): List<String> {
        val apps = runCatching { windows }.getOrNull().orEmpty()
            .filter { it.type == AccessibilityWindowInfo.TYPE_APPLICATION && !it.isInPictureInPictureMode }
        if (apps.isEmpty()) {
            return listOfNotNull(runCatching { rootInActiveWindow?.packageName?.toString() }.getOrNull())
        }
        owners.keys.retainAll(apps.mapTo(HashSet()) { it.id })
        return apps.mapNotNull { window ->
            owners[window.id] ?: runCatching { window.root?.packageName?.toString() }.getOrNull()
                ?.also { owners[window.id] = it }
        }
    }

    private fun isAppWindow(name: String, event: AccessibilityEvent): Boolean {
        if (event.isFullScreen) return true
        val type = event.className?.toString() ?: return false
        if (activities.size > MAX_CACHED_WINDOWS) activities.clear()
        return activities.getOrPut("$name/$type") {
            runCatching { packageManager.getActivityInfo(ComponentName(name, type), 0) }.isSuccess
        }
    }

    private fun label(target: String): String =
        labels.getOrPut(target) { AppCatalog.labels(this, listOf(target))[target] ?: target }

    private fun openOptions(target: String) {
        runCatching { startActivity(MainActivity.blockedIntent(this, target)) }
    }

    private fun toast(now: Long) {
        if (now - lastToastAt < TOAST_INTERVAL_MS) return
        lastToastAt = now
        Toast.makeText(this, NativeStrings.blocked(this), Toast.LENGTH_SHORT).show()
    }

    private fun interactive(): Boolean = getSystemService(PowerManager::class.java)?.isInteractive != false

    private fun restoreSession(force: Boolean = false) {
        val now = SystemClock.uptimeMillis()
        if (!force && now - lastRestoreAt < RESTORE_INTERVAL_MS) return
        lastRestoreAt = now
        FocusEngine.sync(this, foreground = true)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        overlay.relayout()
    }

    override fun onInterrupt() = Unit

    override fun onUnbind(intent: Intent?): Boolean {
        disconnect()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        disconnect()
        thread.quitSafely()
        super.onDestroy()
    }

    private fun disconnect() {
        main.removeCallbacksAndMessages(null)
        worker.removeCallbacksAndMessages(null)
        overlay.hide(immediate = true)
        if (instance === this) instance = null
        if (!connected) return
        connected = false
        MainActivity.notifyStatus()
    }

    companion object {
        private const val SWEEP_DELAY_MS = 120L
        private const val WATCH_MS = 1_000L
        private const val REPEAT_WINDOW_MS = 2_000L
        private const val HOME_GAP_MS = 700L
        private const val TOAST_INTERVAL_MS = 2_500L
        private const val RESTORE_INTERVAL_MS = 15_000L
        private const val MAX_CACHED_WINDOWS = 512

        @Volatile
        var connected = false
            private set

        @Volatile
        private var instance: AppBlockerAccessibilityService? = null

        fun refresh() {
            val service = instance ?: return
            service.main.post { service.sweep() }
        }

        fun preview(): Boolean {
            val service = instance ?: return false
            service.main.post { service.overlay.show(LockOverlay.Content.preview(service)) }
            return true
        }
    }
}
