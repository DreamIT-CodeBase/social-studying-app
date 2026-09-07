import Flutter
import UIKit
import UserNotifications

#if canImport(FamilyControls)
import FamilyControls
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Re-apply shields every time the app comes to the foreground.
  // This ensures shields survive app kills, device reboots, and iOS
  // evicting the process between sessions.
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    ScreenTimeManager.shared.reapplyShields()
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    NSLog("Entra iOS callback delivered to AppDelegate: %@", url.absoluteString)
    if NativeEntraAuthCoordinator.shared.handleRedirectURL(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // ── Entra Auth ────────────────────────────────────────────────────────────
    let authChannel = FlutterMethodChannel(
      name: "com.socialstudyapp.app/entra_auth",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    authChannel.setMethodCallHandler { call, result in
      guard call.method == "signInWithMicrosoft" else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.main.async {
        NativeEntraAuthCoordinator.shared.signIn(arguments: call.arguments, result: result)
      }
    }

    // ── Screen Time ───────────────────────────────────────────────────────────
    let screenTimeChannel = FlutterMethodChannel(
      name: "com.socialstudyapp.app/screen_time",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    screenTimeChannel.setMethodCallHandler { call, result in
      switch call.method {

      // ── Authorization ──────────────────────────────────────────────────────
      case "isScreenTimeAuthorized":
        result(ScreenTimeManager.shared.isAuthorized())

      case "getAuthorizationStatus":
        result(ScreenTimeManager.shared.authorizationStatusString())

      case "requestScreenTimeAuthorization":
        ScreenTimeManager.shared.requestAuthorization { approved, error in
          if let error = error, !approved {
            result(FlutterError(code: "SCREEN_TIME_ERROR", message: error, details: nil))
          } else {
            result(approved)
          }
        }

      case "openScreenTimeSettings":
        ScreenTimeManager.shared.openScreenTimeSettings()
        result(nil)

      // ── App Picker ─────────────────────────────────────────────────────────
      case "presentFamilyActivityPicker":
        ScreenTimeManager.shared.presentAppPicker { success, error in
          if let error = error {
            result(FlutterError(code: "PICKER_ERROR", message: error, details: nil))
          } else {
            result(success)
          }
        }

      case "hasSelectedBlockedApps":
        result(ScreenTimeManager.shared.hasSelectedApps())

      // ── Shield Sync ────────────────────────────────────────────────────────
      case "syncScreenTimeBalance":
        guard let args = call.arguments as? [String: Any],
              let minutes = args["availableMinutes"] as? Int,
              let enableBlocking = args["enableBlocking"] as? Bool else {
          result(FlutterError(
            code: "INVALID_ARGS",
            message: "syncScreenTimeBalance requires 'availableMinutes' (Int) and 'enableBlocking' (Bool)",
            details: nil
          ))
          return
        }
        ScreenTimeManager.shared.syncScreenTimeBalance(
          availableMinutes: minutes,
          enableBlocking: enableBlocking
        )
        result(true)

      case "reapplyShields":
        ScreenTimeManager.shared.reapplyShields()
        result(true)

      // ── Permission Status ──────────────────────────────────────────────────
      case "getIOSPermissionStatus":
        let authorized  = ScreenTimeManager.shared.isAuthorized()
        let hasApps     = ScreenTimeManager.shared.hasSelectedApps()
        let authStatus  = ScreenTimeManager.shared.authorizationStatusString()
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          let notificationsGranted =
            settings.authorizationStatus == .authorized ||
            settings.authorizationStatus == .provisional
          DispatchQueue.main.async {
            result([
              "screenTimeAuthorized": authorized,
              "hasSelectedApps":      hasApps,
              "notifications":        notificationsGranted,
              "authorizationStatus":  authStatus,
            ])
          }
        }

      case "requestNotificationPermission":
        UNUserNotificationCenter.current().requestAuthorization(
          options: [.alert, .badge, .sound]
        ) { granted, _ in
          DispatchQueue.main.async { result(granted) }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
