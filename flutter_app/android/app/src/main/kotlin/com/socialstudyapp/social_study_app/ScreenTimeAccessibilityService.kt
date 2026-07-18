package com.socialstudyapp.social_study_app

import android.accessibilityservice.AccessibilityService
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.Space
import android.widget.TextView
import java.time.DayOfWeek
import java.time.Instant
import java.time.ZoneOffset
import java.time.temporal.TemporalAdjusters
import org.json.JSONArray

/**
 * Enforces the locally cached screen-time policy without making network calls.
 *
 * Flutter owns authentication and cloud synchronization. It writes the active
 * student, wallet, and workspace policy into FlutterSharedPreferences. This
 * service reads that cache so blocking keeps working while Flutter is stopped
 * or the device is offline.
 */
class ScreenTimeAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private var currentForegroundPackage: String? = null
    private var usageTickRunnable: Runnable? = null
    private var foregroundVerificationRunnable: Runnable? = null
    private var lastUsageTickElapsedRealtime = 0L
    private var isOverlayShowing = false
    private var overlayView: View? = null
    private var overlayMode: OverlayMode? = null
    private var breakCountdownRunnable: Runnable? = null
    private var breakCountdownText: TextView? = null
    private var breakForegroundPackage: String? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        startForegroundVerification()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (
            event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED
        ) {
            return
        }

        val foregroundPackage = event.packageName?.toString() ?: return
        handleForegroundPackage(foregroundPackage, event.className?.toString().orEmpty())
    }

    override fun onInterrupt() {
        stopUsageTracking()
        hideOverlay()
    }

    override fun onDestroy() {
        foregroundVerificationRunnable?.let(handler::removeCallbacks)
        foregroundVerificationRunnable = null
        stopUsageTracking()
        hideOverlay()
        super.onDestroy()
    }

    private fun handleForegroundPackage(foregroundPackage: String, className: String = "") {
        if (foregroundPackage == packageName) {
            if (className.contains("MainActivity")) {
                leaveBlockedApp()
            }
            return
        }

        val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val userId = prefs.getString(KEY_CURRENT_USER_ID, "").orEmpty()
        val enforcementReady = prefs.getBoolean(KEY_ENFORCEMENT_READY, false)
        val enableBlocking = prefs.getBoolean(KEY_ENABLE_BLOCKING, true)

        if (userId.isEmpty() || !enforcementReady || !enableBlocking) {
            leaveBlockedApp()
            return
        }

        resetExpiredWeeklyBalance(prefs, userId)

        if (!getBlockedPackages(prefs).contains(foregroundPackage)) {
            leaveBlockedApp()
            return
        }

        currentForegroundPackage = foregroundPackage
        val breakUntilKey = "$KEY_BREAK_UNTIL_MILLIS$userId"
        val now = System.currentTimeMillis()
        val breakUntil = getSafeLongPref(prefs, breakUntilKey, 0L)
        if (breakUntil > now) {
            breakForegroundPackage = foregroundPackage
            stopUsageTracking()
            showBreakOverlay(userId, breakUntil)
            return
        }
        if (breakUntil > 0L) {
            prefs.edit()
                .remove(breakUntilKey)
                .putLong("$KEY_CONTINUOUS_USAGE_MILLIS$userId", 0L)
                .apply()
        }

        val availableMinutes = getSafeLongPref(
            prefs,
            "$KEY_AVAILABLE_MINUTES$userId",
            0L,
        )
        if (availableMinutes <= 0L) {
            stopUsageTracking()
            showExhaustedOverlay()
            return
        }

        hideOverlay()
        startUsageTracking()
    }

    private fun leaveBlockedApp() {
        stopUsageTracking()
        hideOverlay()
    }

    /**
     * Deduct only actual foreground time. Partial seconds survive app switches,
     * so reopening an app no longer spends a whole minute immediately.
     */
    private fun startUsageTracking() {
        if (usageTickRunnable != null) return

        lastUsageTickElapsedRealtime = SystemClock.elapsedRealtime()
        usageTickRunnable = object : Runnable {
            override fun run() {
                val foregroundPackage = currentForegroundPackage
                if (foregroundPackage == null) {
                    stopUsageTracking()
                    return
                }

                val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                val userId = prefs.getString(KEY_CURRENT_USER_ID, "").orEmpty()
                val stillEnforced = userId.isNotEmpty() &&
                    prefs.getBoolean(KEY_ENFORCEMENT_READY, false) &&
                    prefs.getBoolean(KEY_ENABLE_BLOCKING, true) &&
                    getBlockedPackages(prefs).contains(foregroundPackage)
                if (!stillEnforced) {
                    leaveBlockedApp()
                    return
                }

                if (resetExpiredWeeklyBalance(prefs, userId)) {
                    stopUsageTracking()
                    showExhaustedOverlay()
                    return
                }

                val nowElapsed = SystemClock.elapsedRealtime()
                val elapsedMillis = (nowElapsed - lastUsageTickElapsedRealtime).coerceAtLeast(0L)
                lastUsageTickElapsedRealtime = nowElapsed

                val pendingKey = "$KEY_PENDING_USAGE_MILLIS$userId"
                val pendingMillis = getSafeLongPref(prefs, pendingKey, 0L) + elapsedMillis
                val continuousKey = "$KEY_CONTINUOUS_USAGE_MILLIS$userId"
                val continuousMillis = getSafeLongPref(prefs, continuousKey, 0L) + elapsedMillis
                val wholeMinutes = pendingMillis / MILLIS_PER_MINUTE
                val availableKey = "$KEY_AVAILABLE_MINUTES$userId"
                val availableMinutes = getSafeLongPref(prefs, availableKey, 0L)

                if (availableMinutes <= 0L) {
                    stopUsageTracking()
                    showExhaustedOverlay()
                    return
                }

                if (wholeMinutes > 0L) {
                    val minutesToConsume = wholeMinutes.coerceAtMost(availableMinutes)
                    val remainingMinutes = availableMinutes - minutesToConsume
                    val consumedKey = "$KEY_CONSUMED_MINUTES$userId"
                    val consumedTodayKey = "$KEY_CONSUMED_TODAY$userId"

                    prefs.edit()
                        .putLong(availableKey, remainingMinutes)
                        .putLong(
                            consumedKey,
                            getSafeLongPref(prefs, consumedKey, 0L) + minutesToConsume,
                        )
                        .putLong(
                            consumedTodayKey,
                            getSafeLongPref(prefs, consumedTodayKey, 0L) + minutesToConsume,
                        )
                        .putLong(
                            pendingKey,
                            pendingMillis - (minutesToConsume * MILLIS_PER_MINUTE),
                        )
                        .putLong(continuousKey, continuousMillis)
                        .putLong("$KEY_LAST_SYNC_TIME$userId", System.currentTimeMillis())
                        .apply()

                    if (remainingMinutes <= 0L) {
                        stopUsageTracking()
                        showExhaustedOverlay()
                        return
                    }
                } else {
                    prefs.edit()
                        .putLong(pendingKey, pendingMillis)
                        .putLong(continuousKey, continuousMillis)
                        .apply()
                }

                if (continuousMillis >= CONTINUOUS_USAGE_LIMIT_MILLIS) {
                    val breakUntil = System.currentTimeMillis() + BREAK_DURATION_MILLIS
                    prefs.edit()
                        .putLong("$KEY_BREAK_UNTIL_MILLIS$userId", breakUntil)
                        .apply()
                    breakForegroundPackage = foregroundPackage
                    stopUsageTracking()
                    showBreakOverlay(userId, breakUntil)
                    return
                }

                handler.postDelayed(this, USAGE_TICK_MILLIS)
            }
        }

        handler.postDelayed(usageTickRunnable!!, USAGE_TICK_MILLIS)
    }

    private fun stopUsageTracking() {
        usageTickRunnable?.let(handler::removeCallbacks)
        usageTickRunnable = null
        lastUsageTickElapsedRealtime = 0L
        currentForegroundPackage = null
    }

    /**
     * Usage Access is a fallback for OEM/app combinations that do not emit a
     * reliable window-state accessibility event. Without the grant this query
     * simply returns no events and accessibility events remain the primary path.
     */
    private fun startForegroundVerification() {
        if (foregroundVerificationRunnable != null) return

        foregroundVerificationRunnable = object : Runnable {
            override fun run() {
                latestForegroundPackageFromUsageStats()?.let { foregroundPackage ->
                    handleForegroundPackage(foregroundPackage)
                }
                handler.postDelayed(this, FOREGROUND_VERIFY_MILLIS)
            }
        }
        handler.post(foregroundVerificationRunnable!!)
    }

    private fun latestForegroundPackageFromUsageStats(): String? {
        val usageStatsManager = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        val events = usageStatsManager.queryEvents(endTime - USAGE_LOOKBACK_MILLIS, endTime)
        val event = UsageEvents.Event()
        var latestTimestamp = Long.MIN_VALUE
        var latestPackage: String? = null

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val isForegroundEvent = event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                    event.eventType == UsageEvents.Event.ACTIVITY_RESUMED)
            if (isForegroundEvent && event.timeStamp >= latestTimestamp) {
                latestTimestamp = event.timeStamp
                latestPackage = event.packageName
            }
        }
        return latestPackage
    }

    private fun showExhaustedOverlay() {
        showOverlay(OverlayMode.EXHAUSTED) { createOverlayView() }
    }

    private fun showBreakOverlay(userId: String, breakUntil: Long) {
        if (overlayMode == OverlayMode.BREAK && overlayView != null) {
            updateBreakCountdown(breakUntil)
            return
        }
        showOverlay(OverlayMode.BREAK) { createBreakOverlayView(breakUntil) }
        startBreakCountdown(userId, breakUntil)
    }

    private fun showOverlay(mode: OverlayMode, createView: () -> View) {
        if (overlayMode != null && overlayMode != mode) hideOverlay()
        if (isOverlayShowing || overlayView != null) return
        isOverlayShowing = true
        overlayMode = mode

        handler.post {
            if (!isOverlayShowing || overlayView != null || overlayMode != mode) return@post
            try {
                val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
                val layoutParams = WindowManager.LayoutParams().apply {
                    type = WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                    format = PixelFormat.TRANSLUCENT
                    flags = WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_FULLSCREEN
                    width = WindowManager.LayoutParams.MATCH_PARENT
                    height = WindowManager.LayoutParams.MATCH_PARENT
                }

                val view = createView()
                overlayView = view
                try {
                    windowManager.addView(view, layoutParams)
                } catch (accessibilityOverlayError: Exception) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(this)) {
                        layoutParams.type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                        } else {
                            @Suppress("DEPRECATION")
                            WindowManager.LayoutParams.TYPE_PHONE
                        }
                        windowManager.addView(view, layoutParams)
                    } else {
                        throw accessibilityOverlayError
                    }
                }
            } catch (_: Exception) {
                overlayView = null
                isOverlayShowing = false
                overlayMode = null
            }
        }
    }

    private fun hideOverlay() {
        breakCountdownRunnable?.let(handler::removeCallbacks)
        breakCountdownRunnable = null
        breakCountdownText = null
        val view = overlayView ?: run {
            isOverlayShowing = false
            overlayMode = null
            return
        }

        handler.post {
            try {
                val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
                windowManager.removeView(view)
            } catch (_: Exception) {
                // The OS may already have detached the accessibility overlay.
            } finally {
                if (overlayView === view) {
                    overlayView = null
                    isOverlayShowing = false
                    overlayMode = null
                }
            }
        }
    }

    private fun createOverlayView(): View {
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#0F172A"))
        }
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dpToPx(32), dpToPx(32), dpToPx(32), dpToPx(32))
        }
        root.addView(
            container,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER,
            ),
        )

        container.addView(
            TextView(this).apply {
                text = "📚"
                textSize = 64f
                gravity = Gravity.CENTER
            },
        )
        container.addView(Space(this), LinearLayout.LayoutParams(1, dpToPx(24)))
        container.addView(
            TextView(this).apply {
                text = "Study Time Exhausted"
                textSize = 24f
                setTextColor(Color.WHITE)
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                gravity = Gravity.CENTER
            },
        )
        container.addView(Space(this), LinearLayout.LayoutParams(1, dpToPx(12)))
        container.addView(
            TextView(this).apply {
                text = "You have used all earned screen time. Study and earn XP to unlock more social media time."
                textSize = 14f
                setTextColor(Color.parseColor("#94A3B8"))
                gravity = Gravity.CENTER
                setLineSpacing(0f, 1.2f)
            },
        )
        container.addView(Space(this), LinearLayout.LayoutParams(1, dpToPx(36)))

        val buttonParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        )
        container.addView(createActionButton("Study Now", "#1D4ED8") {
            packageManager.getLaunchIntentForPackage(packageName)?.let { intent ->
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                startActivity(intent)
            }
            hideOverlay()
        }, buttonParams)
        container.addView(Space(this), LinearLayout.LayoutParams(1, dpToPx(12)))
        container.addView(createActionButton("Close App", "#1E293B") {
            performGlobalAction(GLOBAL_ACTION_HOME)
            hideOverlay()
        }, buttonParams)
        return root
    }

    private fun createBreakOverlayView(breakUntil: Long): View {
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#0F172A"))
        }
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dpToPx(32), dpToPx(32), dpToPx(32), dpToPx(32))
        }
        root.addView(
            container,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER,
            ),
        )
        container.addView(
            TextView(this).apply {
                text = "Take a 5-minute break before continuing."
                textSize = 24f
                setTextColor(Color.WHITE)
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                gravity = Gravity.CENTER
            },
        )
        container.addView(Space(this), LinearLayout.LayoutParams(1, dpToPx(20)))
        breakCountdownText = TextView(this).apply {
            textSize = 48f
            setTextColor(Color.WHITE)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            gravity = Gravity.CENTER
        }
        container.addView(breakCountdownText)
        updateBreakCountdown(breakUntil)
        container.addView(Space(this), LinearLayout.LayoutParams(1, dpToPx(16)))
        container.addView(
            TextView(this).apply {
                text = "Your earned time is paused during this break. Access resumes automatically."
                textSize = 14f
                setTextColor(Color.parseColor("#94A3B8"))
                gravity = Gravity.CENTER
                setLineSpacing(0f, 1.2f)
            },
        )
        return root
    }

    private fun startBreakCountdown(userId: String, breakUntil: Long) {
        breakCountdownRunnable?.let(handler::removeCallbacks)
        breakCountdownRunnable = object : Runnable {
            override fun run() {
                if (breakUntil <= System.currentTimeMillis()) {
                    val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                    prefs.edit()
                        .remove("$KEY_BREAK_UNTIL_MILLIS$userId")
                        .putLong("$KEY_CONTINUOUS_USAGE_MILLIS$userId", 0L)
                        .apply()
                    val foregroundPackage = breakForegroundPackage
                    breakForegroundPackage = null
                    hideOverlay()
                    if (foregroundPackage != null) {
                        handler.post { handleForegroundPackage(foregroundPackage) }
                    }
                    return
                }
                updateBreakCountdown(breakUntil)
                handler.postDelayed(this, USAGE_TICK_MILLIS)
            }
        }
        handler.post(breakCountdownRunnable!!)
    }

    private fun updateBreakCountdown(breakUntil: Long) {
        val remainingSeconds =
            ((breakUntil - System.currentTimeMillis()).coerceAtLeast(0L) + 999L) / 1_000L
        breakCountdownText?.text = String.format(
            "%02d:%02d",
            remainingSeconds / 60L,
            remainingSeconds % 60L,
        )
    }

    private fun createActionButton(label: String, backgroundColor: String, onClick: () -> Unit): TextView {
        return TextView(this).apply {
            text = label
            textSize = 16f
            setTextColor(Color.WHITE)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(0, dpToPx(16), 0, dpToPx(16))
            background = android.graphics.drawable.GradientDrawable().apply {
                shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(12).toFloat()
                setColor(Color.parseColor(backgroundColor))
                if (label == "Close App") {
                    setStroke(dpToPx(1), Color.parseColor("#475569"))
                }
            }
            isClickable = true
            isFocusable = true
            setOnClickListener { onClick() }
        }
    }

    private fun dpToPx(dp: Int): Int = (dp * resources.displayMetrics.density).toInt()

    private fun getBlockedPackages(prefs: android.content.SharedPreferences): Set<String> {
        val jsonString = prefs.getString(KEY_BLOCKED_PACKAGES, null)
            ?: return DEFAULT_BLOCKED_PACKAGES
        return parseJsonArray(jsonString).toSet()
    }

    private fun getSafeLongPref(
        prefs: android.content.SharedPreferences,
        key: String,
        defaultValue: Long,
    ): Long {
        return try {
            prefs.getLong(key, defaultValue)
        } catch (_: ClassCastException) {
            try {
                prefs.getInt(key, defaultValue.toInt()).toLong()
            } catch (_: Exception) {
                defaultValue
            }
        }
    }

    /**
     * Mirrors the backend's Monday UTC reset so stale cached time cannot be
     * spent while the app is offline. The next Flutter sync makes the same
     * reset authoritative in the cloud wallet.
     */
    private fun resetExpiredWeeklyBalance(
        prefs: android.content.SharedPreferences,
        userId: String,
    ): Boolean {
        val weekStartKey = "$KEY_WEEK_START_DATE$userId"
        val weekStart = Instant.ofEpochMilli(System.currentTimeMillis())
            .atZone(ZoneOffset.UTC)
            .toLocalDate()
            .with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
            .toString()
        val savedWeekStart = prefs.getString(weekStartKey, null)
        if (savedWeekStart == null) {
            prefs.edit().putString(weekStartKey, weekStart).apply()
            return false
        }
        if (savedWeekStart == weekStart) return false

        prefs.edit()
            .putLong("$KEY_AVAILABLE_MINUTES$userId", 0L)
            .putLong("$KEY_TOTAL_EARNED_MINUTES$userId", 0L)
            .putLong("$KEY_CONSUMED_TODAY$userId", 0L)
            .putLong("$KEY_PENDING_USAGE_MILLIS$userId", 0L)
            .putLong("$KEY_CONTINUOUS_USAGE_MILLIS$userId", 0L)
            .remove("$KEY_BREAK_UNTIL_MILLIS$userId")
            .putString(weekStartKey, weekStart)
            .apply()
        return true
    }

    private fun parseJsonArray(jsonString: String): List<String> {
        return try {
            val jsonArray = JSONArray(jsonString)
            List(jsonArray.length()) { index -> jsonArray.getString(index) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    companion object {
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val KEY_CURRENT_USER_ID = "flutter.current_user_id"
        private const val KEY_ENFORCEMENT_READY = "flutter.enforcement_ready"
        private const val KEY_ENABLE_BLOCKING = "flutter.enable_blocking"
        private const val KEY_BLOCKED_PACKAGES = "flutter.blocked_packages_json"
        private const val KEY_AVAILABLE_MINUTES = "flutter.available_minutes_"
        private const val KEY_CONSUMED_MINUTES = "flutter.consumed_minutes_"
        private const val KEY_CONSUMED_TODAY = "flutter.consumed_today_"
        private const val KEY_TOTAL_EARNED_MINUTES = "flutter.total_earned_minutes_"
        private const val KEY_WEEK_START_DATE = "flutter.week_start_date_"
        private const val KEY_LAST_SYNC_TIME = "flutter.last_sync_time_"
        private const val KEY_PENDING_USAGE_MILLIS = "flutter.pending_usage_millis_"
        private const val KEY_CONTINUOUS_USAGE_MILLIS = "flutter.continuous_usage_millis_"
        private const val KEY_BREAK_UNTIL_MILLIS = "flutter.break_until_millis_"
        private const val MILLIS_PER_MINUTE = 60_000L
        private const val CONTINUOUS_USAGE_LIMIT_MILLIS = 20L * MILLIS_PER_MINUTE
        private const val BREAK_DURATION_MILLIS = 5L * MILLIS_PER_MINUTE
        private const val USAGE_TICK_MILLIS = 1_000L
        private const val FOREGROUND_VERIFY_MILLIS = 1_500L
        private const val USAGE_LOOKBACK_MILLIS = 10_000L

        private val DEFAULT_BLOCKED_PACKAGES = setOf(
            "com.instagram.android",
            "com.instagram.barcelona",
            "com.zhiliaoapp.musically",
            "com.google.android.youtube",
            "com.facebook.katana",
            "com.twitter.android",
            "com.snapchat.android",
            "com.reddit.frontpage",
            "com.pinterest",
        )

        private enum class OverlayMode {
            EXHAUSTED,
            BREAK,
        }
    }
}
