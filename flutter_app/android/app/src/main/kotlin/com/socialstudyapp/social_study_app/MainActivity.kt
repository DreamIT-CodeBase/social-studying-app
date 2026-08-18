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
        try {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } catch (_: Throwable) {}
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Screen time / permissions channel ───────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_TIME_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "isAccessibilityEnabled" -> {
                            result.success(isAccessibilityServiceEnabled())
                        }
                        "openAccessibilitySettings" -> {
                            try {
                                val serviceComponent =
                                    ComponentName(this, ScreenTimeAccessibilityService::class.java)
                                val detailIntent = Intent(ACTION_ACCESSIBILITY_DETAILS_SETTINGS).apply {
                                    putExtra(Intent.EXTRA_COMPONENT_NAME, serviceComponent.flattenToString())
                                }
                                if (!openSettings(detailIntent)) {
                                    openSettings(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                                }
                            } catch (_: Throwable) {
                                openSettings(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                            }
                            result.success(null)
                        }
                        "isUsageAccessGranted" -> {
                            result.success(isUsageAccessGranted())
                        }
                        "openUsageAccessSettings" -> {
                            try {
                                val appSpecificIntent = Intent(
                                    Settings.ACTION_USAGE_ACCESS_SETTINGS,
                                    Uri.parse("package:$packageName"),
                                )
                                if (!openSettings(appSpecificIntent)) {
                                    openSettings(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                                }
                            } catch (_: Throwable) {
                                openSettings(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                            }
                            result.success(null)
                        }
                        "isOverlayGranted" -> {
                            result.success(isOverlayGranted())
                        }
                        "openOverlaySettings" -> {
                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    val overlayIntent = Intent(
                                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                        Uri.parse("package:$packageName"),
                                    )
                                    if (!openSettings(overlayIntent)) {
                                        openSettings(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION))
                                    }
                                } else {
                                    openSettings(Intent(Settings.ACTION_SETTINGS))
                                }
                            } catch (_: Throwable) {
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
                            try {
                                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                }
                                if (!openSettings(intent)) {
                                    openSettings(Intent(Settings.ACTION_SETTINGS))
                                }
                            } catch (_: Throwable) {
                                openSettings(Intent(Settings.ACTION_SETTINGS))
                            }
                            result.success(null)
                        }
                        "isBatteryOptimizationExempt" -> {
                            result.success(isBatteryOptimizationExempt())
                        }
                        "openBatteryOptimizationSettings" -> {
                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    val intent = Intent(
                                        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                        Uri.parse("package:$packageName"),
                                    )
                                    if (!openSettings(intent)) {
                                        openSettings(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                                    }
                                }
                            } catch (_: Throwable) {
                                openSettings(Intent(Settings.ACTION_SETTINGS))
                            }
                            result.success(null)
                        }
                        else -> {
                            result.notImplemented()
                        }
                    }
                } catch (t: Throwable) {
                    result.error("method_channel_error", t.message, null)
                }
            }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        return try {
            val expectedComponent = ComponentName(this, ScreenTimeAccessibilityService::class.java)
            val enabledServices = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false

            enabledServices.split(":").any { flattened ->
                ComponentName.unflattenFromString(flattened) == expectedComponent
            }
        } catch (_: Throwable) {
            false
        }
    }

    private fun openSettings(intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Throwable) {
            false
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        try {
            if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return

            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingNotificationResult?.success(granted)
            pendingNotificationResult = null
        } catch (_: Throwable) {
            pendingNotificationResult = null
        }
    }

    private fun isUsageAccessGranted(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
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
            mode == AppOpsManager.MODE_ALLOWED
        } catch (_: Throwable) {
            false
        }
    }

    private fun isOverlayGranted(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Settings.canDrawOverlays(this)
            } else {
                true
            }
        } catch (_: Throwable) {
            false
        }
    }

    private fun isNotificationGranted(): Boolean {
        return try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                manager.areNotificationsEnabled()
            } else {
                true
            }
        } catch (_: Throwable) {
            false
        }
    }

    private fun isBatteryOptimizationExempt(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
                powerManager.isIgnoringBatteryOptimizations(packageName)
            } else {
                true
            }
        } catch (_: Throwable) {
            false
        }
    }

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 7001
        private const val ACTION_ACCESSIBILITY_DETAILS_SETTINGS =
            "android.settings.ACCESSIBILITY_DETAILS_SETTINGS"
    }
}
