import Flutter
import UIKit
import UserNotifications

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

    let screenTimeChannel = FlutterMethodChannel(
      name: "com.socialstudyapp.app/screen_time",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    screenTimeChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "isScreenTimeAuthorized":
        result(ScreenTimeManager.shared.isAuthorized())
      case "requestScreenTimeAuthorization":
        ScreenTimeManager.shared.requestAuthorization { approved, error in
          if let error = error {
            result(FlutterError(code: "SCREEN_TIME_ERROR", message: error, details: nil))
          } else {
            result(approved)
          }
        }
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
      case "syncScreenTimeBalance":
        guard let args = call.arguments as? [String: Any],
              let minutes = args["availableMinutes"] as? Int,
              let enableBlocking = args["enableBlocking"] as? Bool else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid syncScreenTimeBalance arguments", details: nil))
          return
        }
        ScreenTimeManager.shared.syncScreenTimeBalance(availableMinutes: minutes, enableBlocking: enableBlocking)
        result(true)
      case "getIOSPermissionStatus":
        let authorized = ScreenTimeManager.shared.isAuthorized()
        let hasApps = ScreenTimeManager.shared.hasSelectedApps()
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          let notificationsGranted = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
          DispatchQueue.main.async {
            result([
              "screenTimeAuthorized": authorized,
              "hasSelectedApps": hasApps,
              "notifications": notificationsGranted
            ])
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
