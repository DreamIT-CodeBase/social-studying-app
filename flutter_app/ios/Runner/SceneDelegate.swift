import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    // iOS can create a new scene when Safari returns to the custom Entra
    // callback URL. Flutter receives plugin registrations during scene setup,
    // so relay launch-time callback URLs on the next run-loop cycle as well.
    let callbackContexts = connectionOptions.urlContexts
    guard !callbackContexts.isEmpty else { return }
    DispatchQueue.main.async { [weak self] in
      self?.scene(scene, openURLContexts: callbackContexts)
    }
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for context in URLContexts {
      NSLog("Entra iOS callback delivered to SceneDelegate: %@", context.url.absoluteString)
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
