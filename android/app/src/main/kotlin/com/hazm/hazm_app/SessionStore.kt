package com.hazm.hazm_app

import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject

enum class Outcome(val key: String) {
    COMPLETED("completed"),
    BROKEN("broken"),
    INTERRUPTED("interrupted"),
}

data class Finished(val outcome: Outcome, val focusedMs: Long)

data class Session(
    val startedAt: Long,
    val plannedMs: Long,
    val elapsedMs: Long,
    val pauseFromMs: Long,
    val pauseToMs: Long,
    val settledPauseMs: Long,
    val attempts: Int,
    val unguardedMs: Long,
    val dnd: Boolean,
    val taskId: String?,
    val intention: String?,
) {
    val paused: Boolean get() = pauseToMs > elapsedMs
    val blocking: Boolean get() = !paused && elapsedMs < plannedMs
    val remainingMs: Long get() = (plannedMs - elapsedMs).coerceAtLeast(0)
    val pauseRemainingMs: Long get() = if (paused) pauseToMs - elapsedMs else 0L
    val nextEventMs: Long get() = if (paused) pauseRemainingMs else remainingMs
    val pausedMs: Long get() = settledPauseMs + if (paused) elapsedMs - pauseFromMs else 0L

    fun toMap(): Map<String, Any?> = mapOf(
        "startedAt" to startedAt,
        "plannedMs" to plannedMs,
        "elapsedMs" to elapsedMs,
        "pausedMs" to pausedMs,
        "paused" to paused,
        "pauseRemainingMs" to pauseRemainingMs,
        "pauseLengthMs" to if (paused) pauseToMs - pauseFromMs else 0L,
        "attempts" to attempts,
        "unguardedMs" to unguardedMs,
        "dnd" to dnd,
        "taskId" to taskId,
        "intention" to intention,
    )
}

object SessionStore {
    const val MIN_MS = 60_000L
    const val MAX_MS = 4L * 60 * 60 * 1000
    private const val CLOCK_SLACK_MS = 2L * 60 * 1000
    private const val MAX_RESULTS = 30

    private const val PREFS = "hazm_blocker"
    private const val ACTIVE = "session_active"
    private const val STARTED_AT = "session_start_time"
    private const val PLANNED = "session_planned_ms"
    private const val ANCHOR_RT = "session_anchor_rt"
    private const val ANCHOR_BOOT = "session_anchor_boot"
    private const val PAUSE_FROM = "session_pause_from"
    private const val PAUSE_TO = "session_pause_to"
    private const val PAUSED = "session_paused_ms"
    private const val ATTEMPTS = "session_attempts"
    private const val UNGUARDED = "session_unguarded_ms"
    private const val UNGUARDED_FROM = "session_unguarded_from"
    private const val BONUS_EXPOSURE_MS = 2L * 60 * 1000
    private const val APPS = "session_apps"
    private const val THRESHOLD = "bonus_threshold"
    private const val DND = "session_dnd"
    private const val TASK = "session_task"
    private const val INTENTION = "session_intention"
    private const val RESULTS = "session_results"
    private const val ALLOWED = "allowed_apps"
    private const val POLICY_VERSION = "policy_version"
    private const val LANGUAGE = "app_language"

    private val legacyKeys = listOf(
        "is_blocking",
        "block_end_time",
        "block_duration",
        "session_used_credit",
        "session_result_pending",
        "last_session_duration",
        "last_session_completed",
        "last_session_bonus_earned",
    )

    private fun prefs(ctx: Context): SharedPreferences {
        val p = ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (p.contains("block_end_time")) migrateLegacy(ctx, p)
        return p
    }

    private fun migrateLegacy(ctx: Context, p: SharedPreferences) {
        val editor = p.edit()
        val duration = p.getInt("block_duration", 0) * 1000L
        if (p.getBoolean(ACTIVE, false) && !p.contains(PLANNED) && duration in MIN_MS..MAX_MS) {
            val elapsed = System.currentTimeMillis() - p.getLong(STARTED_AT, 0)
            editor.putLong(PLANNED, duration)
                .putLong(ANCHOR_RT, SystemClock.elapsedRealtime() - elapsed.coerceAtLeast(0))
                .putInt(ANCHOR_BOOT, bootCount(ctx))
        } else if (!p.contains(PLANNED)) {
            editor.putBoolean(ACTIVE, false)
        }
        legacyKeys.forEach { editor.remove(it) }
        editor.commit()
    }

    private fun bootCount(ctx: Context): Int =
        Settings.Global.getInt(ctx.contentResolver, Settings.Global.BOOT_COUNT, -1)

    private fun anchorValid(ctx: Context, p: SharedPreferences): Boolean {
        val anchor = p.getLong(ANCHOR_RT, -1)
        if (anchor < 0 || SystemClock.elapsedRealtime() < anchor) return false
        val boot = bootCount(ctx)
        val anchorBoot = p.getInt(ANCHOR_BOOT, -1)
        return boot < 0 || anchorBoot < 0 || boot == anchorBoot
    }

    private fun reanchor(ctx: Context, p: SharedPreferences): Boolean {
        val wallElapsed = System.currentTimeMillis() - p.getLong(STARTED_AT, 0)
        if (wallElapsed < -CLOCK_SLACK_MS) return false
        p.edit()
            .putLong(ANCHOR_RT, SystemClock.elapsedRealtime() - wallElapsed.coerceAtLeast(0))
            .putInt(ANCHOR_BOOT, bootCount(ctx))
            .commit()
        return true
    }

    private fun elapsed(p: SharedPreferences): Long =
        SystemClock.elapsedRealtime() - p.getLong(ANCHOR_RT, 0)

    fun read(ctx: Context): Session? {
        val p = prefs(ctx)
        if (!p.getBoolean(ACTIVE, false)) return null
        if (!anchorValid(ctx, p) && !reanchor(ctx, p)) {
            finish(ctx, p, Outcome.INTERRUPTED, "clock")
            return null
        }
        val elapsed = elapsed(p)
        val pauseTo = p.getLong(PAUSE_TO, 0)
        if (pauseTo in 1..elapsed) {
            p.edit()
                .putLong(PAUSED, p.getLong(PAUSED, 0) + pauseTo - p.getLong(PAUSE_FROM, 0))
                .putLong(PAUSE_FROM, 0)
                .putLong(PAUSE_TO, 0)
                .apply()
        }
        return Session(
            startedAt = p.getLong(STARTED_AT, 0),
            plannedMs = p.getLong(PLANNED, 0),
            elapsedMs = elapsed,
            pauseFromMs = p.getLong(PAUSE_FROM, 0),
            pauseToMs = p.getLong(PAUSE_TO, 0),
            settledPauseMs = p.getLong(PAUSED, 0),
            attempts = p.getInt(ATTEMPTS, 0),
            unguardedMs = unguarded(p, elapsed),
            dnd = p.getBoolean(DND, false),
            taskId = p.getString(TASK, null),
            intention = p.getString(INTENTION, null),
        )
    }

    fun tick(ctx: Context, guarded: Boolean): Finished? {
        val session = read(ctx) ?: return null
        val p = prefs(ctx)
        return when {
            session.plannedMs !in MIN_MS..MAX_MS -> finish(ctx, p, Outcome.INTERRUPTED, "invalid")
            session.elapsedMs >= session.plannedMs -> finish(ctx, p, Outcome.COMPLETED, "timeout")
            else -> {
                trackGuard(p, session, guarded)
                null
            }
        }
    }

    private fun trackGuard(p: SharedPreferences, session: Session, guarded: Boolean) {
        val from = p.getLong(UNGUARDED_FROM, -1)
        val exposed = session.blocking && !guarded
        if (exposed && from < 0) {
            p.edit().putLong(UNGUARDED_FROM, session.elapsedMs).apply()
        } else if (!exposed && from >= 0) {
            p.edit()
                .putLong(UNGUARDED, p.getLong(UNGUARDED, 0) + (session.elapsedMs - from).coerceAtLeast(0))
                .putLong(UNGUARDED_FROM, -1)
                .apply()
        }
    }

    private fun unguarded(p: SharedPreferences, elapsed: Long): Long {
        val from = p.getLong(UNGUARDED_FROM, -1)
        val open = if (from >= 0) (elapsed - from).coerceAtLeast(0) else 0L
        return p.getLong(UNGUARDED, 0) + open
    }

    fun start(
        ctx: Context,
        plannedMs: Long,
        thresholdMinutes: Int,
        dnd: Boolean,
        taskId: String?,
        intention: String?,
    ): Session? {
        read(ctx)?.let { return it }
        val p = prefs(ctx)
        p.edit()
            .putBoolean(ACTIVE, true)
            .putLong(STARTED_AT, System.currentTimeMillis())
            .putLong(PLANNED, plannedMs.coerceIn(MIN_MS, MAX_MS))
            .putLong(ANCHOR_RT, SystemClock.elapsedRealtime())
            .putInt(ANCHOR_BOOT, bootCount(ctx))
            .putLong(PAUSE_FROM, 0)
            .putLong(PAUSE_TO, 0)
            .putLong(PAUSED, 0)
            .putInt(ATTEMPTS, 0)
            .putLong(UNGUARDED, 0)
            .putLong(UNGUARDED_FROM, -1)
            .putString(APPS, "{}")
            .putInt(THRESHOLD, thresholdMinutes.coerceIn(1, 600))
            .putBoolean(DND, dnd)
            .putString(TASK, taskId)
            .putString(INTENTION, intention?.trim()?.take(120)?.ifEmpty { null })
            .putInt(POLICY_VERSION, p.getInt(POLICY_VERSION, 0) + 1)
            .commit()
        return read(ctx)
    }

    fun pause(ctx: Context, seconds: Int): Session? {
        val session = read(ctx) ?: return null
        if (!session.blocking) return session
        val until = (session.elapsedMs + seconds.coerceIn(1, 3600) * 1000L).coerceAtMost(session.plannedMs)
        prefs(ctx).edit()
            .putLong(PAUSE_FROM, session.elapsedMs)
            .putLong(PAUSE_TO, until)
            .commit()
        return read(ctx)
    }

    fun resume(ctx: Context): Session? {
        val session = read(ctx) ?: return null
        if (!session.paused) return session
        prefs(ctx).edit()
            .putLong(PAUSED, session.settledPauseMs + session.elapsedMs - session.pauseFromMs)
            .putLong(PAUSE_FROM, 0)
            .putLong(PAUSE_TO, 0)
            .commit()
        return read(ctx)
    }

    fun extend(ctx: Context, minutes: Int): Session? {
        val session = read(ctx) ?: return null
        val planned = (session.plannedMs + minutes.coerceIn(1, 60) * 60_000L).coerceAtMost(MAX_MS)
        prefs(ctx).edit().putLong(PLANNED, planned).commit()
        return read(ctx)
    }

    fun breakSession(ctx: Context): Finished? {
        read(ctx) ?: return null
        return finish(ctx, prefs(ctx), Outcome.BROKEN, "unlock")
    }

    fun cancel(ctx: Context) {
        clear(prefs(ctx).edit()).commit()
    }

    fun recordAttempt(ctx: Context, packageName: String) {
        val p = prefs(ctx)
        if (!p.getBoolean(ACTIVE, false)) return
        val apps = parseObject(p.getString(APPS, null))
        apps.put(packageName, apps.optInt(packageName, 0) + 1)
        p.edit()
            .putInt(ATTEMPTS, p.getInt(ATTEMPTS, 0) + 1)
            .putString(APPS, apps.toString())
            .apply()
    }

    fun takeResults(ctx: Context): List<Map<String, Any?>> {
        val p = prefs(ctx)
        val raw = p.getString(RESULTS, null) ?: return emptyList()
        p.edit().remove(RESULTS).commit()
        val array = runCatching { JSONArray(raw) }.getOrNull() ?: return emptyList()
        return (0 until array.length()).mapNotNull { index ->
            array.optJSONObject(index)?.let(::toMap)
        }
    }

    fun allowedApps(ctx: Context): Set<String> =
        prefs(ctx).getStringSet(ALLOWED, null)?.toSet() ?: defaultAllowed

    private val defaultAllowed = setOf(
        "com.google.android.apps.nbu.files",
        "com.sec.android.app.myfiles",
        "com.mi.android.globalFileexplorer",
        "com.android.fileexplorer",
        "com.android.camera",
        "com.android.camera2",
        "com.google.android.GoogleCamera",
        "com.sec.android.app.camera",
        "com.oplus.camera",
    )

    fun setAllowedApps(ctx: Context, packages: Collection<String>) {
        val p = prefs(ctx)
        p.edit()
            .putStringSet(ALLOWED, packages.toSet())
            .putInt(POLICY_VERSION, p.getInt(POLICY_VERSION, 0) + 1)
            .apply()
    }

    fun policyVersion(ctx: Context): Int = prefs(ctx).getInt(POLICY_VERSION, 0)

    fun language(ctx: Context): String = prefs(ctx).getString(LANGUAGE, "en") ?: "en"

    fun setLanguage(ctx: Context, code: String) {
        prefs(ctx).edit().putString(LANGUAGE, code).apply()
    }

    private fun finish(ctx: Context, p: SharedPreferences, outcome: Outcome, reason: String): Finished {
        val planned = p.getLong(PLANNED, 0).coerceAtLeast(0)
        val startedAt = p.getLong(STARTED_AT, 0)
        val elapsed = when {
            outcome == Outcome.COMPLETED -> planned
            anchorValid(ctx, p) -> elapsed(p).coerceIn(0, planned)
            else -> (System.currentTimeMillis() - startedAt).coerceIn(0, planned)
        }
        val pauseFrom = p.getLong(PAUSE_FROM, 0)
        val pauseTo = p.getLong(PAUSE_TO, 0)
        val openPause = if (pauseTo > 0) (minOf(elapsed, pauseTo) - pauseFrom).coerceAtLeast(0L) else 0L
        val focused = (elapsed - p.getLong(PAUSED, 0) - openPause).coerceAtLeast(0)
        val exposure = unguarded(p, elapsed).coerceIn(0, focused)
        val threshold = p.getInt(THRESHOLD, 90) * 60_000L
        val result = JSONObject()
            .put("id", startedAt.toString())
            .put("startedAt", startedAt)
            .put("endedAt", startedAt + elapsed)
            .put("plannedSeconds", planned / 1000)
            .put("focusedSeconds", focused / 1000)
            .put("outcome", outcome.key)
            .put("reason", reason)
            .put("bonus", outcome == Outcome.COMPLETED && focused >= threshold && exposure < BONUS_EXPOSURE_MS)
            .put("attempts", p.getInt(ATTEMPTS, 0))
            .put("unguardedSeconds", exposure / 1000)
            .put("apps", parseObject(p.getString(APPS, null)))
            .put("taskId", p.getString(TASK, null) ?: JSONObject.NULL)
            .put("intention", p.getString(INTENTION, null) ?: JSONObject.NULL)
        val pending = runCatching { JSONArray(p.getString(RESULTS, "[]")) }.getOrDefault(JSONArray())
        pending.put(result)
        while (pending.length() > MAX_RESULTS) pending.remove(0)
        clear(p.edit().putString(RESULTS, pending.toString())).commit()
        return Finished(outcome, focused)
    }

    private fun clear(editor: SharedPreferences.Editor): SharedPreferences.Editor = editor
        .putBoolean(ACTIVE, false)
        .remove(STARTED_AT)
        .remove(PLANNED)
        .remove(ANCHOR_RT)
        .remove(ANCHOR_BOOT)
        .remove(PAUSE_FROM)
        .remove(PAUSE_TO)
        .remove(PAUSED)
        .remove(ATTEMPTS)
        .remove(UNGUARDED)
        .remove(UNGUARDED_FROM)
        .remove(APPS)
        .remove(DND)
        .remove(TASK)
        .remove(INTENTION)

    private fun parseObject(raw: String?): JSONObject =
        raw?.let { runCatching { JSONObject(it) }.getOrNull() } ?: JSONObject()

    private fun toMap(json: JSONObject): Map<String, Any?> = json.keys().asSequence().associateWith { key ->
        when (val value = json.opt(key)) {
            JSONObject.NULL -> null
            is JSONObject -> toMap(value)
            else -> value
        }
    }
}
