package com.hazm.hazm_app

import android.animation.TimeInterpolator
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.text.TextPaint
import android.util.AttributeSet
import android.util.TypedValue
import android.view.View
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.view.animation.PathInterpolator
import kotlin.math.min

class LockRingView @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {
    private val density = resources.displayMetrics.density
    private val brand = context.getColor(R.color.hazm_brand)
    private val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 3 * density
        color = context.getColor(R.color.hazm_track)
    }
    private val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 3 * density
        strokeCap = Paint.Cap.ROUND
        color = brand
    }
    private val wave = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = brand
    }
    private val glow = Paint(Paint.ANTI_ALIAS_FLAG)
    private val mark = context.getDrawable(R.drawable.ic_hazm_mark)
    private val box = RectF()
    private val animators = ArrayList<ValueAnimator>()
    private var sweep = 1f
    private var pop = 1f
    private var ripple = 1f

    fun play() {
        stop()
        sweep = 0f
        pop = 0f
        ripple = 0f
        animate(SWEEP_MS, 0, PathInterpolator(0.2f, 0f, 0f, 1f)) { sweep = it }
        animate(POP_MS, POP_DELAY_MS, OvershootInterpolator(2.2f)) { pop = it }
        animate(WAVE_MS, WAVE_DELAY_MS, DecelerateInterpolator(1.8f)) { ripple = it }
    }

    fun knock() {
        stop()
        sweep = 1f
        pop = 1f
        animate(WAVE_MS, 0, DecelerateInterpolator(1.8f)) { ripple = it }
    }

    fun stop() {
        animators.forEach { it.cancel() }
        animators.clear()
    }

    private fun animate(duration: Long, delay: Long, curve: TimeInterpolator, apply: (Float) -> Unit) {
        animators += ValueAnimator.ofFloat(0f, 1f).apply {
            this.duration = duration
            startDelay = delay
            interpolator = curve
            addUpdateListener {
                apply(it.animatedValue as Float)
                invalidate()
            }
            start()
        }
    }

    private fun radius(): Float = min(width, height) * RING_FRACTION

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (w == 0 || h == 0) return
        glow.shader = RadialGradient(
            w / 2f,
            h / 2f,
            radius() * GLOW_SPREAD,
            intArrayOf(Color.argb(GLOW_ALPHA, Color.red(brand), Color.green(brand), Color.blue(brand)), Color.TRANSPARENT),
            null,
            Shader.TileMode.CLAMP,
        )
    }

    override fun onDraw(canvas: Canvas) {
        val cx = width / 2f
        val cy = height / 2f
        val radius = radius()
        glow.alpha = (255 * pop.coerceIn(0f, 1f)).toInt()
        canvas.drawCircle(cx, cy, radius * GLOW_SPREAD, glow)
        canvas.drawCircle(cx, cy, radius, track)
        box.set(cx - radius, cy - radius, cx + radius, cy + radius)
        canvas.drawArc(box, -90f, 360f * sweep, false, arc)
        if (ripple > 0f && ripple < 1f) {
            val fade = 1f - ripple
            wave.strokeWidth = (2.5f * fade + 0.5f) * density
            wave.alpha = (fade * fade * 200).toInt()
            canvas.drawCircle(cx, cy, radius + (min(cx, cy) - radius) * ripple, wave)
        }
        val drawable = mark ?: return
        val half = (radius * MARK_SCALE * pop).toInt()
        if (half <= 0) return
        drawable.setBounds((cx - half).toInt(), (cy - half).toInt(), (cx + half).toInt(), (cy + half).toInt())
        drawable.draw(canvas)
    }

    override fun onDetachedFromWindow() {
        stop()
        super.onDetachedFromWindow()
    }

    private companion object {
        const val RING_FRACTION = 0.27f
        const val GLOW_SPREAD = 1.9f
        const val GLOW_ALPHA = 56
        const val MARK_SCALE = 1.2f
        const val SWEEP_MS = 620L
        const val POP_MS = 540L
        const val POP_DELAY_MS = 120L
        const val WAVE_MS = 1_000L
        const val WAVE_DELAY_MS = 460L
    }
}

class SpineView @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {
    private val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = context.getColor(R.color.hazm_brand) }
    private val size = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, 34f, resources.displayMetrics)

    var text: String = ""
        set(value) {
            field = value
            invalidate()
        }

    var typeface: Typeface? = null
        set(value) {
            field = value
            paint.typeface = value
            invalidate()
        }

    override fun onDraw(canvas: Canvas) {
        if (text.isEmpty() || height == 0) return
        paint.textSize = size
        val length = paint.measureText(text)
        if (length > height) paint.textSize = size * height / length
        val metrics = paint.fontMetrics
        canvas.save()
        canvas.translate(width / 2f, height / 2f)
        canvas.rotate(if (layoutDirection == LAYOUT_DIRECTION_RTL) -90f else 90f)
        canvas.drawText(text, -paint.measureText(text) / 2, -(metrics.ascent + metrics.descent) / 2, paint)
        canvas.restore()
    }
}

class BarView @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = context.getColor(R.color.hazm_brand) }
    private var animator: ValueAnimator? = null
    private var progress = 1f

    fun run(from: Float, to: Float, duration: Long, delay: Long, curve: TimeInterpolator) {
        stop()
        progress = from
        invalidate()
        animator = ValueAnimator.ofFloat(from, to).apply {
            this.duration = duration
            startDelay = delay
            interpolator = curve
            addUpdateListener {
                progress = it.animatedValue as Float
                invalidate()
            }
            start()
        }
    }

    fun stop() {
        animator?.cancel()
        animator = null
    }

    override fun onDraw(canvas: Canvas) {
        val filled = width * progress.coerceIn(0f, 1f)
        if (filled <= 0f) return
        val start = if (layoutDirection == LAYOUT_DIRECTION_RTL) width - filled else 0f
        canvas.drawRect(start, 0f, start + filled, height.toFloat(), paint)
    }

    override fun onDetachedFromWindow() {
        stop()
        super.onDetachedFromWindow()
    }
}
