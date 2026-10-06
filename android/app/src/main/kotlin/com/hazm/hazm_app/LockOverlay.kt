package com.hazm.hazm_app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.animation.LinearInterpolator
import android.view.animation.PathInterpolator
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import java.util.Locale

class LockOverlay(private val service: AccessibilityService, private val onOptions: (String) -> Unit) {
    class Content(
        val eyebrow: String,
        val headline: String?,
        val endsAt: Long,
        val caption: String,
        val message: String?,
        val primary: String,
        val secondary: String?,
        val spine: String,
        val target: String?,
        val holdMs: Long,
    ) {
        companion object {
            private const val BLOCK_HOLD_MS = 4_500L
            private const val PREVIEW_HOLD_MS = 3_200L

            fun blocked(ctx: Context, label: String, target: String, session: Session) = Content(
                eyebrow = NativeStrings.lockedApp(ctx, label),
                headline = null,
                endsAt = SystemClock.elapsedRealtime() + session.remainingMs,
                caption = NativeStrings.untilSessionEnds(ctx),
                message = NativeStrings.blocked(ctx),
                primary = NativeStrings.backToFocus(ctx),
                secondary = NativeStrings.unlockOptions(ctx),
                spine = NativeStrings.lockSpine(ctx),
                target = target,
                holdMs = BLOCK_HOLD_MS,
            )

            fun preview(ctx: Context) = Content(
                eyebrow = NativeStrings.previewEyebrow(ctx),
                headline = NativeStrings.previewHeadline(ctx),
                endsAt = 0,
                caption = NativeStrings.previewCaption(ctx),
                message = null,
                primary = NativeStrings.gotIt(ctx),
                secondary = null,
                spine = NativeStrings.previewSpine(ctx),
                target = null,
                holdMs = PREVIEW_HOLD_MS,
            )
        }
    }

    private class Views(val root: View) {
        val spine: SpineView = root.findViewById(R.id.lock_spine)
        val ring: LockRingView = root.findViewById(R.id.lock_ring)
        val eyebrow: TextView = root.findViewById(R.id.lock_eyebrow)
        val headline: TextView = root.findViewById(R.id.lock_headline)
        val rule: BarView = root.findViewById(R.id.lock_rule)
        val caption: TextView = root.findViewById(R.id.lock_caption)
        val message: TextView = root.findViewById(R.id.lock_message)
        val primary: TextView = root.findViewById(R.id.lock_primary)
        val secondary: TextView = root.findViewById(R.id.lock_secondary)
        val drain: BarView = root.findViewById(R.id.lock_drain)
        val staged = listOf(eyebrow, headline, caption, message, primary, secondary)
    }

    private val handler = Handler(Looper.getMainLooper())
    private val windowManager = service.getSystemService(WindowManager::class.java)
    private val emphasized = PathInterpolator(0.2f, 0f, 0f, 1f)
    private val exit = PathInterpolator(0.3f, 0f, 0.8f, 0.15f)
    private var views: Views? = null
    private var params: WindowManager.LayoutParams? = null
    private var content: Content? = null

    private val dismiss = Runnable { hide() }

    private val tick = object : Runnable {
        override fun run() {
            val current = views ?: return
            val shown = content ?: return
            if (shown.headline != null) return
            val left = shown.endsAt - SystemClock.elapsedRealtime()
            if (left <= 0) {
                hide()
                return
            }
            current.headline.text = clock(left)
            handler.postDelayed(this, left % 1_000 + 20)
        }
    }

    fun show(next: Content): Boolean {
        val current = views
        if (current != null) {
            bind(current, next)
            current.ring.knock()
            current.root.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
            arm(current, next)
            return true
        }
        val created = runCatching { Views(LayoutInflater.from(service).inflate(R.layout.hazm_lock, null)) }
            .getOrNull() ?: return false
        style(created)
        bind(created, next)
        val layout = layoutParams()
        if (runCatching { windowManager.addView(created.root, layout) }.isFailure) {
            content = null
            return false
        }
        views = created
        params = layout
        enter(created)
        arm(created, next)
        created.root.post {
            created.root.performHapticFeedback(
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) HapticFeedbackConstants.REJECT else HapticFeedbackConstants.LONG_PRESS,
            )
        }
        return true
    }

    fun hide(immediate: Boolean = false) {
        val current = views ?: return
        val layout = params
        views = null
        params = null
        content = null
        handler.removeCallbacks(dismiss)
        handler.removeCallbacks(tick)
        current.ring.stop()
        current.rule.stop()
        current.drain.stop()
        if (immediate || layout == null) {
            remove(current.root)
            return
        }
        layout.flags = layout.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        runCatching { windowManager.updateViewLayout(current.root, layout) }
        current.root.animate().cancel()
        current.root.animate()
            .alpha(0f)
            .scaleX(EXIT_SCALE)
            .scaleY(EXIT_SCALE)
            .setDuration(EXIT_MS)
            .setInterpolator(exit)
            .withEndAction { remove(current.root) }
            .start()
    }

    fun relayout() {
        views?.let(::fit)
    }

    private fun remove(view: View) {
        runCatching { windowManager.removeViewImmediate(view) }
    }

    private fun layoutParams() = WindowManager.LayoutParams(
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
        PixelFormat.TRANSLUCENT,
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        title = "HAZM"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) fitInsetsTypes = 0
    }

    private fun style(views: Views) {
        val arabic = NativeStrings.isArabic(service)
        val text = Fonts.text(service, arabic)
        val numerals = Fonts.numerals(service)
        views.root.layoutDirection = if (arabic) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR
        views.spine.typeface = text
        listOf(views.eyebrow, views.caption, views.primary, views.secondary).forEach { it.typeface = text }
        views.message.typeface = Fonts.body(service, arabic)
        views.headline.typeface = numerals
        if (arabic) listOf(views.eyebrow, views.caption, views.primary, views.secondary).forEach { it.letterSpacing = 0f }
        ViewCompat.setOnApplyWindowInsetsListener(views.root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }
        views.root.setOnClickListener { hide() }
        views.primary.setOnClickListener { hide() }
        views.secondary.setOnClickListener {
            val target = content?.target
            hide()
            if (target != null) onOptions(target)
        }
        fit(views)
    }

    private fun bind(views: Views, next: Content) {
        content = next
        views.spine.text = next.spine
        views.eyebrow.text = next.eyebrow
        views.caption.text = next.caption
        views.primary.text = next.primary
        views.message.text = next.message.orEmpty()
        views.secondary.text = next.secondary.orEmpty()
        views.secondary.visibility = if (next.secondary == null) View.GONE else View.VISIBLE
        views.headline.typeface = if (next.headline != null && NativeStrings.isArabic(service)) {
            Fonts.text(service, arabic = true)
        } else {
            Fonts.numerals(service)
        }
        views.headline.text = next.headline ?: clock(next.endsAt - SystemClock.elapsedRealtime())
        fit(views)
    }

    private fun fit(views: Views) {
        val compact = service.resources.configuration.screenHeightDp < COMPACT_HEIGHT_DP
        val headline = if (compact) HEADLINE_COMPACT_SP else HEADLINE_SP
        views.ring.visibility = if (compact) View.GONE else View.VISIBLE
        views.message.visibility = if (compact || content?.message == null) View.GONE else View.VISIBLE
        views.headline.layoutParams = views.headline.layoutParams.also {
            it.height = (headline * HEADLINE_LINE * service.resources.displayMetrics.density).toInt()
        }
        views.headline.setAutoSizeTextTypeUniformWithConfiguration(
            HEADLINE_MIN_SP,
            headline,
            HEADLINE_STEP_SP,
            TypedValue.COMPLEX_UNIT_SP,
        )
    }

    private fun enter(views: Views) {
        views.root.alpha = 0f
        views.root.animate().alpha(1f).setDuration(FADE_MS).setInterpolator(DecelerateInterpolator()).start()
        views.ring.play()
        val rise = 22 * service.resources.displayMetrics.density
        views.spine.alpha = 0f
        views.spine.translationY = rise * 3
        views.spine.animate().alpha(1f).translationY(0f).setDuration(SPINE_MS).setInterpolator(emphasized).start()
        views.staged.forEachIndexed { index, view ->
            view.alpha = 0f
            view.translationY = rise
            view.animate()
                .alpha(1f)
                .translationY(0f)
                .setStartDelay(STAGE_START_MS + index * STAGE_STEP_MS)
                .setDuration(STAGE_MS)
                .setInterpolator(emphasized)
                .start()
        }
        views.rule.run(0f, 1f, RULE_MS, RULE_DELAY_MS, emphasized)
    }

    private fun arm(views: Views, next: Content) {
        handler.removeCallbacks(dismiss)
        handler.postDelayed(dismiss, next.holdMs)
        views.drain.run(1f, 0f, next.holdMs, 0, LinearInterpolator())
        handler.removeCallbacks(tick)
        handler.post(tick)
    }

    private fun clock(ms: Long): String {
        val total = (ms.coerceAtLeast(0) + 999) / 1_000
        val hours = total / 3_600
        val minutes = total % 3_600 / 60
        val seconds = total % 60
        return if (hours > 0) {
            String.format(Locale.US, "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format(Locale.US, "%02d:%02d", minutes, seconds)
        }
    }

    private object Fonts {
        private val cache = HashMap<String, Typeface>()

        fun text(ctx: Context, arabic: Boolean): Typeface =
            load(ctx, if (arabic) "NotoKufiArabic-Bold.ttf" else "SpaceGrotesk-Bold.ttf")

        fun body(ctx: Context, arabic: Boolean): Typeface =
            load(ctx, if (arabic) "NotoKufiArabic-Medium.ttf" else "SpaceGrotesk-Medium.ttf")

        fun numerals(ctx: Context): Typeface = load(ctx, "SpaceGrotesk-Bold.ttf")

        private fun load(ctx: Context, file: String): Typeface = cache.getOrPut(file) {
            runCatching { Typeface.createFromAsset(ctx.assets, "flutter_assets/assets/fonts/$file") }
                .getOrDefault(Typeface.DEFAULT_BOLD)
        }
    }

    private companion object {
        const val COMPACT_HEIGHT_DP = 560
        const val HEADLINE_SP = 84
        const val HEADLINE_COMPACT_SP = 60
        const val HEADLINE_MIN_SP = 28
        const val HEADLINE_STEP_SP = 2
        const val HEADLINE_LINE = 1.34f
        const val FADE_MS = 180L
        const val SPINE_MS = 760L
        const val STAGE_START_MS = 140L
        const val STAGE_STEP_MS = 50L
        const val STAGE_MS = 520L
        const val RULE_DELAY_MS = 320L
        const val RULE_MS = 640L
        const val EXIT_MS = 200L
        const val EXIT_SCALE = 0.985f
    }
}
