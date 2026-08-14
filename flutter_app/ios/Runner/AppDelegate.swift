import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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

  }
}
