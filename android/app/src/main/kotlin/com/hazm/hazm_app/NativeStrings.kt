package com.hazm.hazm_app

import android.content.Context
import java.util.Locale

object NativeStrings {
    fun isArabic(ctx: Context) = SessionStore.language(ctx) == "ar"

    private fun pick(ctx: Context, en: String, ar: String) = if (isArabic(ctx)) ar else en

    fun lockedApp(ctx: Context, label: String) =
        pick(ctx, "${label.uppercase(Locale.ROOT)} IS LOCKED", "$label محجوب الآن")

    fun untilSessionEnds(ctx: Context) = pick(ctx, "UNTIL YOUR SESSION ENDS", "حتى نهاية الجلسة")

    fun backToFocus(ctx: Context) = pick(ctx, "BACK TO FOCUS", "العودة إلى التركيز")

    fun unlockOptions(ctx: Context) = pick(ctx, "UNLOCK OPTIONS", "خيارات الفتح")

    fun lockSpine(ctx: Context) = pick(ctx, "DEEP WORK MODE", "وضع العمل العميق")

    fun previewEyebrow(ctx: Context) = pick(ctx, "BLOCKING IS ON", "خدمة الحجب تعمل")

    fun previewHeadline(ctx: Context) = pick(ctx, "READY", "جاهز")

    fun previewCaption(ctx: Context) =
        pick(ctx, "BLOCKED APPS CLOSE LIKE THIS", "هكذا تُغلق التطبيقات المحجوبة")

    fun previewSpine(ctx: Context) = pick(ctx, "DEEP WORK MODE", "وضع العمل العميق")

    fun gotIt(ctx: Context) = pick(ctx, "GOT IT", "حسناً")

    fun focusTitle(ctx: Context) = pick(ctx, "Deep work session", "جلسة عمل عميق")

    fun focusText(ctx: Context, intention: String?) = intention?.takeIf { it.isNotBlank() }
        ?: pick(ctx, "Distracting apps are blocked until the session ends", "التطبيقات المشتِّتة محجوبة حتى نهاية الجلسة")

    fun breakTitle(ctx: Context) = pick(ctx, "Break", "استراحة")

    fun breakText(ctx: Context) = pick(ctx, "Blocking resumes automatically", "يعود الحجب تلقائياً بعد الاستراحة")

    fun sessionChannel(ctx: Context) = pick(ctx, "Focus session", "جلسة التركيز")

    fun updatesChannel(ctx: Context) = pick(ctx, "Session updates", "تحديثات الجلسات")

    fun alertsChannel(ctx: Context) = pick(ctx, "Blocking alerts", "تنبيهات الحجب")

    fun guardTitle(ctx: Context) = pick(ctx, "Blocking is off", "الحجب متوقف")

    fun guardText(ctx: Context) = pick(
        ctx,
        "HAZM's blocking service stopped, so apps are not being blocked. Tap to turn it back on.",
        "توقفت خدمة الحجب، فالتطبيقات غير محجوبة الآن. يمكن إعادة تشغيلها بالضغط هنا.",
    )

    fun completedTitle(ctx: Context) = pick(ctx, "Session complete", "اكتملت الجلسة")

    fun completedText(ctx: Context, minutes: Long) =
        pick(ctx, "$minutes min of deep work. Well done.", "${arabicMinutes(minutes)} من العمل العميق. إنجاز رائع.")

    private fun arabicMinutes(minutes: Long): String {
        val tens = minutes % 100
        return when {
            minutes == 1L -> "دقيقة واحدة"
            minutes == 2L -> "دقيقتان"
            tens in 3..10 -> "$minutes دقائق"
            else -> "$minutes دقيقة"
        }
    }

    private val blockedEn = listOf(
        "Not now. Your session is still running.",
        "Stay with it. You're doing deep work.",
        "This can wait. Finish your session first.",
        "Back to what matters.",
    )

    private val blockedAr = listOf(
        "ليس الآن، فالجلسة ما زالت مستمرة.",
        "وقت العمل العميق ما زال مستمراً.",
        "هذا يمكن أن ينتظر حتى نهاية الجلسة.",
        "العودة إلى ما يهم.",
    )

    fun blocked(ctx: Context) = (if (isArabic(ctx)) blockedAr else blockedEn).random()
}
