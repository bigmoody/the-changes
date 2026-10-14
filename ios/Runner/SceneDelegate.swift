import Flutter
import UIKit

/// Where a tapped chart actually arrives.
///
/// Under the scene-based lifecycle the application-level open is never
/// called, so a handler on the app delegate alone is a handler that
/// never runs. Both ways in are covered: a link that starts the app
/// comes with the scene's connection options, and one arriving at a
/// running app comes through on its own.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    hand(connectionOptions.urlContexts)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    hand(URLContexts)
  }

  private func hand(_ contexts: Set<UIOpenURLContext>) {
    guard let delegate = UIApplication.shared.delegate as? AppDelegate else {
      return
    }
    for context in contexts {
      delegate.handed(context.url)
    }
  }
}
