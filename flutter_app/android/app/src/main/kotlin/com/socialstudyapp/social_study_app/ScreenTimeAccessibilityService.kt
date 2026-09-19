package com.socialstudyapp.social_study_app

import android.accessibilityservice.AccessibilityService
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.Space
import android.widget.TextView
import android.widget.Toast
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
    private var topBannerView: View? = null
    private var topBannerDismissRunnable: Runnable? = null
    private var lastHandledUsageStatsTimestamp = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        try {
            startForegroundVerification()
        } catch (_: Throwable) {}
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        try {
            if (
                event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
                event.eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED
            ) {
                return
            }

            val foregroundPackage = event.packageName?.toString() ?: return
            handleForegroundPackage(foregroundPackage, event.className?.toString().orEmpty())
        } catch (_: Throwable) {}
    }

    override fun onInterrupt() {
        try {
            stopUsageTracking()
            hideOverlay()
            removeTopBannerView()
        } catch (_: Throwable) {}
    }

    override fun onDestroy() {
        try {
            foregroundVerificationRunnable?.let(handler::removeCallbacks)
            foregroundVerificationRunnable = null
            stopUsageTracking()
            hideOverlay()
            removeTopBannerView()
        } catch (_: Throwable) {}
        super.onDestroy()
    }

    private fun handleForegroundPackage(foregroundPackage: String, className: String = "") {
        try {
            if (foregroundPackage == packageName) {
                if (className.contains("MainActivity")) {
                    leaveBlockedApp()
                    removeTopBannerView()
                }
                return
            }

            val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE) ?: return
            var userId = prefs.getString(KEY_CURRENT_USER_ID, "").orEmpty()
            if (userId.isEmpty()) {
                userId = "tester_user"
            }
            val enableBlocking = prefs.getBoolean(KEY_ENABLE_BLOCKING, true)

            if (!enableBlocking) {
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

            val availableKey = "$KEY_AVAILABLE_MINUTES$userId"
            var availableMinutes = 0L
            if (prefs.contains(availableKey)) {
                availableMinutes = getSafeLongPref(prefs, availableKey, 0L)
            } else if (prefs.contains("flutter.available_minutes")) {
                availableMinutes = getSafeLongPref(prefs, "flutter.available_minutes", 0L)
            } else if (prefs.contains("available_minutes")) {
                availableMinutes = getSafeLongPref(prefs, "available_minutes", 0L)
            } else {
                var found = false
                for (entry in prefs.all) {
                    if (entry.key.startsWith("flutter.available_minutes") || entry.key.startsWith("available_minutes")) {
                        val v = when (val value = entry.value) {
                            is Long -> value
                            is Int -> value.toLong()
                            is Number -> value.toLong()
                            else -> 0L
                        }
                        if (v > 0L) {
                            availableMinutes = v
                            found = true
                            break
                        }
                    }
                }
                if (!found) {
                    availableMinutes = 0L
                }
            }

            if (availableMinutes <= 0L) {
                stopUsageTracking()
                showExhaustedOverlay(foregroundPackage)
                return
            }

            hideOverlay()
            startUsageTracking()
        } catch (_: Throwable) {}
    }

    private fun leaveBlockedApp() {
        try {
            stopUsageTracking()
            hideOverlay()
            // Keep topBannerView visible over the Home screen launcher so the user sees it.
            // It auto-dismisses after 6.5s, on "✕", or when "Study Now" / MainActivity is opened.
        } catch (_: Throwable) {}
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
                try {
                    val foregroundPackage = currentForegroundPackage
                    if (foregroundPackage == null) {
                        stopUsageTracking()
                        return
                    }

                    val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                    if (prefs == null) {
                        stopUsageTracking()
                        return
                    }
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
                        showExhaustedOverlay(foregroundPackage)
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
                        showExhaustedOverlay(foregroundPackage)
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
                            showExhaustedOverlay(foregroundPackage)
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
                } catch (_: Throwable) {
                    stopUsageTracking()
                }
            }
        }

        handler.postDelayed(usageTickRunnable!!, USAGE_TICK_MILLIS)
    }

    private fun stopUsageTracking() {
        try {
            usageTickRunnable?.let(handler::removeCallbacks)
            usageTickRunnable = null
            lastUsageTickElapsedRealtime = 0L
            currentForegroundPackage = null
        } catch (_: Throwable) {}
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
                try {
                    latestForegroundPackageFromUsageStats()?.let { foregroundPackage ->
                        handleForegroundPackage(foregroundPackage)
                    }
                } catch (_: Throwable) {
                } finally {
                    handler.postDelayed(this, FOREGROUND_VERIFY_MILLIS)
                }
            }
        }
        handler.post(foregroundVerificationRunnable!!)
    }

    private fun latestForegroundPackageFromUsageStats(): String? {
        return try {
            val usageStatsManager = getSystemService(USAGE_STATS_SERVICE) as? UsageStatsManager ?: return null
            val endTime = System.currentTimeMillis()
            val events = usageStatsManager.queryEvents(endTime - USAGE_LOOKBACK_MILLIS, endTime) ?: return null
            val event = UsageEvents.Event()
            var latestTimestamp = lastHandledUsageStatsTimestamp
            var latestPackage: String? = null

            while (events.hasNextEvent()) {
                if (!events.getNextEvent(event)) break
                val isForegroundEvent = event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                    (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                        event.eventType == UsageEvents.Event.ACTIVITY_RESUMED)
                if (isForegroundEvent && event.timeStamp > latestTimestamp) {
                    latestTimestamp = event.timeStamp
                    latestPackage = event.packageName
                }
            }
            if (latestPackage != null) {
                lastHandledUsageStatsTimestamp = latestTimestamp
            }
            latestPackage
        } catch (_: Throwable) {
            null
        }
    }

    private fun showExhaustedOverlay(foregroundPackage: String? = null) {
        val targetPackage = foregroundPackage ?: currentForegroundPackage.orEmpty()
        try {
            // 1. Instantly kick the user out of the blocked app back to the Home screen
            performGlobalAction(GLOBAL_ACTION_HOME)
            currentForegroundPackage = null

            // 2. Audible ringtone & tactile vibration immediately
            playAudibleNotificationFeedback()

            // 3. Send high-priority Heads-Up system notification from top
            sendStudySessionNeededNotification(targetPackage)

            // 4. Show guaranteed top-of-screen floating banner overlay ("from top at any cost")
            showTopBannerNotification(targetPackage)

            // 5. Quick toast for guaranteed visibility across all Android versions and OEM ROMs
            handler.post {
                try {
                    Toast.makeText(
                        applicationContext,
                        "📚 Study Session Needed: To gain access to your app, let’s create a study session.",
                        Toast.LENGTH_LONG,
                    ).show()
                } catch (_: Throwable) {}
            }
        } catch (_: Throwable) {}
    }

    private fun playAudibleNotificationFeedback() {
        try {
            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            val ringtone = RingtoneManager.getRingtone(applicationContext, soundUri)
            ringtone?.play()
        } catch (_: Throwable) {}

        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 250, 150, 250), -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(longArrayOf(0, 250, 150, 250), -1)
            }
        } catch (_: Throwable) {}
    }

    private fun sendStudySessionNeededNotification(blockedPackage: String) {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
            val channelId = NOTIFICATION_CHANNEL_ID
            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                var channel = notificationManager.getNotificationChannel(channelId)
                if (channel == null) {
                    val audioAttributes = AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_INSTANT)
                        .build()
                    channel = NotificationChannel(
                        channelId,
                        "Study Session Needed",
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "Alerts when restricted apps require a study session to unlock"
                        enableLights(true)
                        lightColor = Color.parseColor("#3B82F6")
                        enableVibration(true)
                        vibrationPattern = longArrayOf(0, 250, 150, 250)
                        setSound(soundUri, audioAttributes)
                        lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                        setBypassDnd(true)
                    }
                    notificationManager.createNotificationChannel(channel)
                }
            }

            // CRITICAL: Cancel the prior notification first.
            // Android SystemUI suppresses Heads-Up drop-down alerts if an unacknowledged
            // notification for the channel already exists in the shade. Canceling first
            // guarantees that Android sees this as a fresh, immediate alert every time.
            notificationManager.cancel(NOTIFICATION_ID_STUDY_NEEDED)

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("action", "unlock_question")
                putExtra("blocked_package", blockedPackage)
                putExtra("source", "app_shield")
            }
            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val contentIntent = launchIntent?.let {
                PendingIntent.getActivity(applicationContext, NOTIFICATION_ID_STUDY_NEEDED, it, pendingFlags)
            }

            // CRITICAL: Ensure small icon belongs to this application package
            val smallIconRes = applicationInfo.icon.takeIf { it != 0 }
                ?: resources.getIdentifier("ic_launcher", "mipmap", packageName).takeIf { it != 0 }
                ?: resources.getIdentifier("ic_notification", "drawable", packageName).takeIf { it != 0 }
                ?: android.R.drawable.stat_notify_more

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(applicationContext, channelId)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(applicationContext)
            }

            builder
                .setSmallIcon(smallIconRes)
                .setContentTitle("Study Session Needed")
                .setContentText("To gain access to your app, let’s create a study session.")
                .setStyle(Notification.BigTextStyle().bigText("To gain access to your app, let’s create a study session."))
                .setAutoCancel(true)
                .setOnlyAlertOnce(false)
                .setSound(soundUri)
                .setPriority(Notification.PRIORITY_MAX)
                .setCategory(Notification.CATEGORY_ALARM)
                .setDefaults(Notification.DEFAULT_ALL)
                .setVisibility(Notification.VISIBILITY_PUBLIC)

            if (contentIntent != null) {
                builder.setContentIntent(contentIntent)
                // setFullScreenIntent forces Android SystemUI to drop down a heads-up banner from the top!
                builder.setFullScreenIntent(contentIntent, true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val action = Notification.Action.Builder(
                        smallIconRes,
                        "Study Now ➔",
                        contentIntent
                    ).build()
                    builder.addAction(action)
                }
            }

            notificationManager.notify(NOTIFICATION_ID_STUDY_NEEDED, builder.build())
        } catch (_: Throwable) {}
    }

    private fun showTopBannerNotification(targetPackage: String) {
        handler.post {
            try {
                val windowManager = getSystemService(WINDOW_SERVICE) as? WindowManager ?: return@post

                // Remove previous if still visible
                removeTopBannerView(windowManager)

                val banner = createTopBannerView(targetPackage)
                topBannerView = banner

                val statusBarHeight = getStatusBarHeight()
                val layoutParams = WindowManager.LayoutParams().apply {
                    type = WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                    format = PixelFormat.TRANSLUCENT
                    flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
                    width = WindowManager.LayoutParams.MATCH_PARENT
                    height = WindowManager.LayoutParams.WRAP_CONTENT
                    gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                    y = (statusBarHeight + dpToPx(6)).coerceAtLeast(dpToPx(12))
                }

                try {
                    windowManager.addView(banner, layoutParams)
                } catch (accessibilityError: Throwable) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(this)) {
                        layoutParams.type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                        } else {
                            @Suppress("DEPRECATION")
                            WindowManager.LayoutParams.TYPE_PHONE
                        }
                        windowManager.addView(banner, layoutParams)
                    } else {
                        return@post
                    }
                }

                // Drop-down animation from top
                banner.translationY = -dpToPx(130).toFloat()
                banner.alpha = 0f
                banner.animate()
                    .translationY(0f)
                    .alpha(1f)
                    .setDuration(350)
                    .setInterpolator(OvershootInterpolator(0.8f))
                    .start()

                // Auto-dismiss after 6.5 seconds
                topBannerDismissRunnable = Runnable {
                    dismissTopBannerWithAnimation()
                }
                handler.postDelayed(topBannerDismissRunnable!!, 6500L)
            } catch (_: Throwable) {}
        }
    }

    private fun dismissTopBannerWithAnimation() {
        val view = topBannerView ?: return
        topBannerDismissRunnable?.let(handler::removeCallbacks)
        topBannerDismissRunnable = null

        view.animate().cancel()
        view.animate()
            .translationY(-dpToPx(130).toFloat())
            .alpha(0f)
            .setDuration(250)
            .withEndAction {
                try {
                    val windowManager = getSystemService(WINDOW_SERVICE) as? WindowManager
                    windowManager?.removeView(view)
                } catch (_: Throwable) {}
                if (topBannerView === view) {
                    topBannerView = null
                }
            }
            .start()
    }

    private fun removeTopBannerView(windowManager: WindowManager? = null) {
        topBannerDismissRunnable?.let(handler::removeCallbacks)
        topBannerDismissRunnable = null
        val view = topBannerView ?: return
        try {
            view.animate().cancel()
            val wm = windowManager ?: (getSystemService(WINDOW_SERVICE) as? WindowManager)
            wm?.removeView(view)
        } catch (_: Throwable) {}
        topBannerView = null
    }

    private fun getStatusBarHeight(): Int {
        var result = 0
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        if (resourceId > 0) {
            result = resources.getDimensionPixelSize(resourceId)
        }
        return if (result > 0) result else dpToPx(24)
    }

    private fun createTopBannerView(targetPackage: String): View {
        val root = FrameLayout(this).apply {
            setPadding(dpToPx(12), 0, dpToPx(12), 0)
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dpToPx(14), dpToPx(12), dpToPx(12), dpToPx(12))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(16).toFloat()
                setColor(Color.parseColor("#0F172A"))
                setStroke(dpToPx(1), Color.parseColor("#3B82F6"))
            }
            elevation = dpToPx(12).toFloat()
            isClickable = true
            isFocusable = true
            setOnClickListener {
                launchStudySessionUnlock(targetPackage)
            }
        }

        root.addView(
            card,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.CENTER_HORIZONTAL
            )
        )

        // Left: 📚 Icon badge
        val iconBadge = FrameLayout(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(10).toFloat()
                setColor(Color.parseColor("#1E3A8A"))
            }
        }
        val iconEmoji = TextView(this).apply {
            text = "📚"
            textSize = 20f
            gravity = Gravity.CENTER
        }
        iconBadge.addView(
            iconEmoji,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            )
        )
        card.addView(iconBadge, LinearLayout.LayoutParams(dpToPx(42), dpToPx(42)))

        card.addView(Space(this), LinearLayout.LayoutParams(dpToPx(10), 1))

        // Center: Text column
        val textColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val headerRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val titleTag = TextView(this).apply {
            text = "STUDY SESSION NEEDED"
            textSize = 10.5f
            setTextColor(Color.parseColor("#60A5FA"))
            setTypeface(typeface, Typeface.BOLD)
        }
        val timeTag = TextView(this).apply {
            text = " • now"
            textSize = 10f
            setTextColor(Color.parseColor("#94A3B8"))
        }
        headerRow.addView(titleTag)
        headerRow.addView(timeTag)
        textColumn.addView(headerRow)

        textColumn.addView(Space(this), LinearLayout.LayoutParams(1, dpToPx(2)))

        val bodyText = TextView(this).apply {
            text = "To gain access to your app, let’s create a study session."
            textSize = 12.5f
            setTextColor(Color.WHITE)
            setTypeface(typeface, Typeface.BOLD)
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
        }
        textColumn.addView(bodyText)

        val textParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
        card.addView(textColumn, textParams)

        card.addView(Space(this), LinearLayout.LayoutParams(dpToPx(8), 1))

        // Right: "Study Now" button
        val studyButton = TextView(this).apply {
            text = "Study Now ➔"
            textSize = 11.5f
            setTextColor(Color.WHITE)
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(dpToPx(10), dpToPx(7), dpToPx(10), dpToPx(7))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(8).toFloat()
                setColor(Color.parseColor("#2563EB"))
            }
            isClickable = true
            isFocusable = true
            setOnClickListener {
                launchStudySessionUnlock(targetPackage)
            }
        }
        card.addView(studyButton, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT))

        card.addView(Space(this), LinearLayout.LayoutParams(dpToPx(6), 1))

        // Right-most: Close "✕" button
        val closeButton = TextView(this).apply {
            text = "✕"
            textSize = 13f
            setTextColor(Color.parseColor("#94A3B8"))
            gravity = Gravity.CENTER
            setPadding(dpToPx(4), dpToPx(4), dpToPx(4), dpToPx(4))
            isClickable = true
            isFocusable = true
            setOnClickListener {
                dismissTopBannerWithAnimation()
            }
        }
        card.addView(closeButton, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT))

        return root
    }

    private fun launchStudySessionUnlock(targetPackage: String) {
        dismissTopBannerWithAnimation()
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("action", "unlock_question")
                putExtra("blocked_package", targetPackage)
                putExtra("source", "app_shield")
            }
            if (launchIntent != null) {
                startActivity(launchIntent)
            }
        } catch (_: Throwable) {}
    }

    private fun showBreakOverlay(userId: String, breakUntil: Long) {
        try {
            // Kick out of blocked app during mandatory break
            performGlobalAction(GLOBAL_ACTION_HOME)

            handler.post {
                try {
                    android.widget.Toast.makeText(
                        applicationContext,
                        "⏸️ Take a 5-minute break! Social media is temporarily paused.",
                        android.widget.Toast.LENGTH_LONG,
                    ).show()
                } catch (_: Throwable) {}
            }

            if (overlayMode == OverlayMode.BREAK && overlayView != null) {
                updateBreakCountdown(breakUntil)
                return
            }
            showOverlay(OverlayMode.BREAK) { createBreakOverlayView(breakUntil) }
            startBreakCountdown(userId, breakUntil)
        } catch (_: Throwable) {}
    }

    private fun showOverlay(mode: OverlayMode, createView: () -> View) {
        try {
            if (overlayMode != null && overlayMode != mode) hideOverlay()
            if (isOverlayShowing || overlayView != null) return
            isOverlayShowing = true
            overlayMode = mode

            handler.post {
                if (!isOverlayShowing || overlayView != null || overlayMode != mode) return@post
                try {
                    val windowManager = getSystemService(WINDOW_SERVICE) as? WindowManager ?: return@post
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
                    } catch (accessibilityOverlayError: Throwable) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(this)) {
                            layoutParams.type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                            } else {
                                @Suppress("DEPRECATION")
                                WindowManager.LayoutParams.TYPE_PHONE
                            }
                            windowManager.addView(view, layoutParams)
                        }
                    }
                } catch (_: Throwable) {
                    overlayView = null
                    isOverlayShowing = false
                    overlayMode = null
                }
            }
        } catch (_: Throwable) {}
    }

    private fun hideOverlay() {
        try {
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
                    val windowManager = getSystemService(WINDOW_SERVICE) as? WindowManager
                    windowManager?.removeView(view)
                } catch (_: Throwable) {
                    // The OS may already have detached the accessibility overlay.
                } finally {
                    if (overlayView === view) {
                        overlayView = null
                        isOverlayShowing = false
                        overlayMode = null
                    }
                }
            }
        } catch (_: Throwable) {}
    }

    private fun createOverlayView(targetPackage: String = ""): View {
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
                text = "Study Question Challenge"
                textSize = 24f
                setTextColor(Color.WHITE)
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                gravity = Gravity.CENTER
            },
        )
        container.addView(Space(this), LinearLayout.LayoutParams(1, dpToPx(12)))
        container.addView(
            TextView(this).apply {
                text = "Screen time is currently exhausted. Answer a study question in the app to unlock your session and earn screen time!"
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
        container.addView(createActionButton("Answer Question to Unlock", "#1D4ED8") {
            try {
                packageManager.getLaunchIntentForPackage(packageName)?.let { intent ->
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    intent.putExtra("action", "unlock_question")
                    intent.putExtra("blocked_package", targetPackage)
                    intent.putExtra("source", "app_shield")
                    startActivity(intent)
                }
            } catch (_: Throwable) {}
            hideOverlay()
        }, buttonParams)
        container.addView(Space(this), LinearLayout.LayoutParams(1, dpToPx(12)))
        container.addView(createActionButton("Close App", "#1E293B") {
            try {
                performGlobalAction(GLOBAL_ACTION_HOME)
            } catch (_: Throwable) {}
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
        try {
            breakCountdownRunnable?.let(handler::removeCallbacks)
            breakCountdownRunnable = object : Runnable {
                override fun run() {
                    try {
                        if (breakUntil <= System.currentTimeMillis()) {
                            val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                            prefs?.edit()
                                ?.remove("$KEY_BREAK_UNTIL_MILLIS$userId")
                                ?.putLong("$KEY_CONTINUOUS_USAGE_MILLIS$userId", 0L)
                                ?.apply()
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
                    } catch (_: Throwable) {
                        hideOverlay()
                    }
                }
            }
            handler.post(breakCountdownRunnable!!)
        } catch (_: Throwable) {}
    }

    private fun updateBreakCountdown(breakUntil: Long) {
        try {
            val remainingSeconds =
                ((breakUntil - System.currentTimeMillis()).coerceAtLeast(0L) + 999L) / 1_000L
            breakCountdownText?.text = String.format(
                "%02d:%02d",
                remainingSeconds / 60L,
                remainingSeconds % 60L,
            )
        } catch (_: Throwable) {}
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
        if (jsonString.isNullOrBlank()) {
            return DEFAULT_BLOCKED_PACKAGES
        }
        val parsed = parseJsonArray(jsonString).toSet()
        return if (parsed.isEmpty()) DEFAULT_BLOCKED_PACKAGES else (parsed + DEFAULT_BLOCKED_PACKAGES)
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
            } catch (_: Throwable) {
                defaultValue
            }
        } catch (_: Throwable) {
            defaultValue
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
        return try {
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
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun parseJsonArray(jsonString: String): List<String> {
        return try {
            val jsonArray = JSONArray(jsonString)
            List(jsonArray.length()) { index -> jsonArray.getString(index) }
        } catch (_: Throwable) {
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
        private const val NOTIFICATION_ID_STUDY_NEEDED = 8801
        private const val NOTIFICATION_CHANNEL_ID = "study_session_urgent_top_banner_v12"

        private val DEFAULT_BLOCKED_PACKAGES = setOf(
            "com.instagram.android",
            "com.instagram.barcelona",
            "com.zhiliaoapp.musically",
            "com.ss.android.ugc.trill",
            "com.google.android.youtube",
            "com.google.android.apps.youtube.music",
            "com.facebook.katana",
            "com.facebook.orca",
            "com.twitter.android",
            "com.x.android",
            "com.snapchat.android",
            "com.reddit.frontpage",
            "com.pinterest",
            "tv.twitch.android.app",
            "com.discord",
            "org.telegram.messenger",
            "com.linkedin.android",
            "com.netflix.mediaclient",
            "com.amazon.avod.thirdpartyclient",
            "com.hotstar.mobile",
            "com.jio.media.ondemand",
            "in.mohalla.sharechat",
            "com.next.innovation.takatak",
            "com.eterno",
            "video.like",
            "com.kwai.video",
        )

        private enum class OverlayMode {
            EXHAUSTED,
            BREAK,
        }
    }
}
