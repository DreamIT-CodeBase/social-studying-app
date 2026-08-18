package com.socialstudyapp.social_study_app

import android.Manifest
import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SCREEN_TIME_CHANNEL = "com.socialstudyapp.app/screen_time"
    private var pendingNotificationResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Protect every Flutter route from screenshots, screen recording,
        // recent-app previews, and non-secure external displays. Applying the
        // flag before Flutter renders prevents a sensitive first-frame leak.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Screen time / permissions channel ───────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_TIME_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAccessibilityEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }
                    "openAccessibilitySettings" -> {
                        val serviceComponent =
                            ComponentName(this, ScreenTimeAccessibilityService::class.java)
                        val detailIntent = Intent(ACTION_ACCESSIBILITY_DETAILS_SETTINGS).apply {
                            putExtra(Intent.EXTRA_COMPONENT_NAME, serviceComponent.flattenToString())
                        }
                        if (!openSettings(detailIntent)) {
                            openSettings(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        }
                        result.success(null)
                    }
                    "isUsageAccessGranted" -> {
                        result.success(isUsageAccessGranted())
                    }
                    "openUsageAccessSettings" -> {
                        val appSpecificIntent = Intent(
                            Settings.ACTION_USAGE_ACCESS_SETTINGS,
                            Uri.parse("package:$packageName"),
                        )
                        if (!openSettings(appSpecificIntent)) {
                            openSettings(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        }
                        result.success(null)
                    }
                    "isOverlayGranted" -> {
                        result.success(isOverlayGranted())
                    }
                    "openOverlaySettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            openSettings(
                                Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                        } else {
                            openSettings(Intent(Settings.ACTION_SETTINGS))
                        }
                        result.success(null)
                    }
                    "isNotificationGranted" -> {
                        result.success(isNotificationGranted())
                    }
                    "requestNotificationPermission" -> {
                        if (
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                                PackageManager.PERMISSION_GRANTED
                        ) {
                            if (pendingNotificationResult != null) {
                                result.error(
                                    "permission_request_active",
                                    "A notification permission request is already active.",
                                    null,
                                )
                                return@setMethodCallHandler
                            }
                            pendingNotificationResult = result
                            requestPermissions(
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                NOTIFICATION_PERMISSION_REQUEST,
                            )
                        } else {
                            result.success(isNotificationGranted())
                        }
                    }
                    "openNotificationSettings" -> {
                        openSettings(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            },
                        )
                        result.success(null)
                    }
                    "isBatteryOptimizationExempt" -> {
                        result.success(isBatteryOptimizationExempt())
                    }
                    "openBatteryOptimizationSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            openSettings(
                                Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                        }
                        result.success(null)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedComponent = ComponentName(this, ScreenTimeAccessibilityService::class.java)
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        return enabledServices.split(":").any { flattened ->
            ComponentName.unflattenFromString(flattened) == expectedComponent
        }
    }

    private fun openSettings(intent: Intent): Boolean {
        return try {
            if (intent.resolveActivity(packageManager) == null) {
                false
            } else {
                startActivity(intent)
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingNotificationResult?.success(granted)
        pendingNotificationResult = null
    }

    private fun isUsageAccessGranted(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isOverlayGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun isNotificationGranted(): Boolean {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            manager.areNotificationsEnabled()
        } else {
            true
        }
    }

    private fun isBatteryOptimizationExempt(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }
    }

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 7001
        private const val ACTION_ACCESSIBILITY_DETAILS_SETTINGS =
            "android.settings.ACCESSIBILITY_DETAILS_SETTINGS"
    }
}
