package com.socialstudyapp.social_study_app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.Space
import android.widget.TextView
import org.json.JSONArray

class ScreenTimeAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private var currentForegroundPackage: String? = null
    private var checkUsageRunnable: Runnable? = null
    private var isOverlayShowing = false
    private var overlayView: View? = null

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = event.packageName?.toString() ?: return
            
            // If the package is our own app, hide the overlay only if it is our main activity.
            // This prevents the overlay from dismissing itself when it is first drawn.
            if (packageName == this.packageName) {
                val className = event.className?.toString() ?: ""
                if (className.contains("MainActivity")) {
                    hideLockOverlay()
                    stopUsageTracking()
                }
                return
            }

            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            val currentUserId = prefs.getString("flutter.current_user_id", "") ?: ""
            val suffix = if (currentUserId.isNotEmpty()) "_$currentUserId" else ""

            val enableBlocking = prefs.getBoolean("flutter.enable_blocking", true)
            if (!enableBlocking) {
                hideLockOverlay()
                stopUsageTracking()
                return
            }

            val blockedPackages = getBlockedPackages(prefs)

            if (blockedPackages.contains(packageName)) {
                currentForegroundPackage = packageName
                val availableMinutes = getSafeLongPref(prefs, "flutter.available_minutes$suffix", 0L).toInt()
                if (availableMinutes <= 0) {
                    showLockOverlay()
                    stopUsageTracking()
                } else {
                    hideLockOverlay()
                    startUsageTracking(packageName)
                }
            } else {
                // If it is another application or home launcher, stop usage tracking.
                // We do NOT hide overlay here unless we are absolutely sure, but typically leaving 
                // a blocked app should hide the overlay automatically.
                hideLockOverlay()
                stopUsageTracking()
            }
        }
    }

    override fun onInterrupt() {
        stopUsageTracking()
        hideLockOverlay()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopUsageTracking()
        hideLockOverlay()
    }

    private fun startUsageTracking(packageName: String) {
        if (checkUsageRunnable != null) return // Timer is already running

        checkUsageRunnable = object : Runnable {
            override fun run() {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val currentUserId = prefs.getString("flutter.current_user_id", "") ?: ""
                val suffix = if (currentUserId.isNotEmpty()) "_$currentUserId" else ""

                val enableBlocking = prefs.getBoolean("flutter.enable_blocking", true)
                val blockedPackages = getBlockedPackages(prefs)

                if (enableBlocking && blockedPackages.contains(packageName)) {
                    var availableMinutes = getSafeLongPref(prefs, "flutter.available_minutes$suffix", 0L).toInt()
                    if (availableMinutes > 0) {
                        availableMinutes -= 1

                        val consumedMinutes = getSafeLongPref(prefs, "flutter.consumed_minutes$suffix", 0L).toInt() + 1
                        val consumedToday = getSafeLongPref(prefs, "flutter.consumed_today$suffix", 0L).toInt() + 1

                        prefs.edit().apply {
                            putLong("flutter.available_minutes$suffix", availableMinutes.toLong())
                            putLong("flutter.consumed_minutes$suffix", consumedMinutes.toLong())
                            putLong("flutter.consumed_today$suffix", consumedToday.toLong())
                            putLong("flutter.last_sync_time$suffix", System.currentTimeMillis())
                            apply()
                        }

                        if (availableMinutes <= 0) {
                            showLockOverlay()
                            stopUsageTracking()
                            return
                        }
                    } else {
                        showLockOverlay()
                        stopUsageTracking()
                        return
                    }
                } else {
                    stopUsageTracking()
                    return
                }

                // Repeat in 60 seconds
                handler.postDelayed(this, 60000)
            }
        }

        // Fire the first check immediately so the first minute is deducted
        // at t=0 rather than after a free 60-second grace period.
        handler.post(checkUsageRunnable!!)
    }

    private fun stopUsageTracking() {
        checkUsageRunnable?.let {
            handler.removeCallbacks(it)
        }
        checkUsageRunnable = null
        currentForegroundPackage = null
    }

    private fun showLockOverlay() {
        if (isOverlayShowing) return

        handler.post {
            try {
                val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
                val layoutParams = WindowManager.LayoutParams().apply {
                    type = WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                    format = PixelFormat.TRANSLUCENT
                    flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                            WindowManager.LayoutParams.FLAG_FULLSCREEN
                    width = WindowManager.LayoutParams.MATCH_PARENT
                    height = WindowManager.LayoutParams.MATCH_PARENT
                }

                val view = createOverlayView()
                overlayView = view
                windowManager.addView(view, layoutParams)
                isOverlayShowing = true
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun hideLockOverlay() {
        if (!isOverlayShowing || overlayView == null) return

        handler.post {
            try {
                val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
                windowManager.removeView(overlayView)
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                overlayView = null
                isOverlayShowing = false
            }
        }
    }

    private fun createOverlayView(): View {
        val context = this

        val root = FrameLayout(context).apply {
            setBackgroundColor(Color.parseColor("#0F172A")) // Slate 900
        }

        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dpToPx(32), dpToPx(32), dpToPx(32), dpToPx(32))
        }

        val rootParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
            Gravity.CENTER
        )
        root.addView(container, rootParams)

        val iconView = TextView(context).apply {
            text = "📚"
            textSize = 64f
            gravity = Gravity.CENTER
        }
        container.addView(iconView)

        container.addView(Space(context), LinearLayout.LayoutParams(1, dpToPx(24)))

        val titleView = TextView(context).apply {
            text = "Study Time Exhausted"
            textSize = 24f
            setTextColor(Color.WHITE)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            gravity = Gravity.CENTER
        }
        container.addView(titleView)

        container.addView(Space(context), LinearLayout.LayoutParams(1, dpToPx(12)))

        val subtitleView = TextView(context).apply {
            text = "You have used all earned screen time. Answer questions and earn XP to unlock more social media usage."
            textSize = 14f
            setTextColor(Color.parseColor("#94A3B8")) // Slate 400
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.2f)
        }
        container.addView(subtitleView)

        container.addView(Space(context), LinearLayout.LayoutParams(1, dpToPx(36)))

        val studyButton = TextView(context).apply {
            text = "Study Now"
            textSize = 16f
            setTextColor(Color.WHITE)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(0, dpToPx(16), 0, dpToPx(16))

            val shape = android.graphics.drawable.GradientDrawable().apply {
                shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(12).toFloat()
                setColor(Color.parseColor("#1D4ED8")) // Primary Blue
            }
            background = shape
            isClickable = true
            isFocusable = true

            setOnClickListener {
                val intent = packageManager.getLaunchIntentForPackage(packageName)
                if (intent != null) {
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                    startActivity(intent)
                }
                hideLockOverlay()
            }
        }
        val buttonParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        container.addView(studyButton, buttonParams)

        container.addView(Space(context), LinearLayout.LayoutParams(1, dpToPx(12)))

        val closeButton = TextView(context).apply {
            text = "Close App"
            textSize = 16f
            setTextColor(Color.parseColor("#E2E8F0")) // Slate 200
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(0, dpToPx(16), 0, dpToPx(16))

            val shape = android.graphics.drawable.GradientDrawable().apply {
                shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(12).toFloat()
                setColor(Color.parseColor("#1E293B")) // Slate 800
                setStroke(dpToPx(1), Color.parseColor("#475569")) // Slate 600
            }
            background = shape
            isClickable = true
            isFocusable = true

            setOnClickListener {
                performGlobalAction(GLOBAL_ACTION_HOME)
                hideLockOverlay()
            }
        }
        container.addView(closeButton, buttonParams)

        return root
    }

    private fun dpToPx(dp: Int): Int {
        val density = resources.displayMetrics.density
        return (dp * density).toInt()
    }

    private fun getBlockedPackages(prefs: android.content.SharedPreferences): List<String> {
        val jsonStr = prefs.getString("flutter.blocked_packages_json", null)
        if (jsonStr == null) {
            return listOf(
                "com.instagram.android",
                "com.zhiliaoapp.musically",
                "com.google.android.youtube",
                "com.facebook.katana",
                "com.twitter.android",
                "com.snapchat.android"
            )
        }
        return parseJsonArray(jsonStr)
    }

    private fun getSafeLongPref(prefs: android.content.SharedPreferences, key: String, defaultValue: Long): Long {
        return try {
            prefs.getLong(key, defaultValue)
        } catch (e: ClassCastException) {
            try {
                prefs.getInt(key, defaultValue.toInt()).toLong()
            } catch (e2: Exception) {
                defaultValue
            }
        } catch (e: Exception) {
            defaultValue
        }
    }

    private fun parseJsonArray(jsonStr: String): List<String> {
        val list = mutableListOf<String>()
        try {
            val jsonArray = JSONArray(jsonStr)
            for (i in 0 until jsonArray.length()) {
                list.add(jsonArray.getString(i))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return list
    }
}
