import Flutter
import MediaPlayer
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Held for the life of the app: it owns the channel the lock screen
  /// buttons come back on.
  private var nowPlaying: NowPlayingBridge?

  /// The channel a tapped chart is handed over on.
  private var shared: FlutterMethodChannel?

  /// A chart that arrived before Dart was listening, which is every link
  /// that starts the app rather than arriving at a running one.
  private var waiting: String?

  /// Whether Dart has asked what opened the app. Before it does, a chart
  /// is held; after, it is sent straight over. Doing both would import
  /// the same thing twice.
  private var asked = false

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NowPlaying") {
      nowPlaying = NowPlayingBridge(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SharedCharts") {
      let shared = FlutterMethodChannel(
        name: "the_changes/shared",
        binaryMessenger: registrar.messenger()
      )
      self.shared = shared
      shared.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(nil)
          return
        }
        if call.method == "initial" {
          self.asked = true
          result(self.waiting)
          self.waiting = nil
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  /// A link tapped somewhere else, which iOS hands over whole.
  ///
  /// Called from the scene rather than here. This app runs the
  /// scene-based lifecycle, and under it the application-level open is
  /// never called at all: the URL arrives at the scene, and a handler
  /// written here only looks as though it works.
  func handed(_ url: URL) {
    let text = url.absoluteString
    if asked, let shared {
      shared.invokeMethod("shared", arguments: text)
    } else {
      waiting = text
    }
  }
}

final class NowPlayingBridge {
  private let channel: FlutterMethodChannel

  /// Whether the remote commands have been wired up. They are enabled on
  /// the first card rather than at launch, so an app that has never
  /// played does not sit in Control Centre offering to play nothing.
  private var listening = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "the_changes/now_playing",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "show":
        let arguments = call.arguments as? [String: Any] ?? [:]
        self.show(
          title: arguments["title"] as? String ?? "",
          line: arguments["line"] as? String ?? "",
          playing: arguments["playing"] as? Bool ?? true
        )
        result(nil)
      case "hide":
        self.hide()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func show(title: String, line: String, playing: Bool) {
    startListening()
    var info = [String: Any]()
    info[MPMediaItemPropertyTitle] = title
    info[MPMediaItemPropertyArtist] = line
    // No duration and no elapsed time on purpose. The band is a loop
    // that runs until you stop it, and a progress bar would have to
    // invent an end for it.
    info[MPNowPlayingInfoPropertyIsLiveStream] = true
    info[MPNowPlayingInfoPropertyPlaybackRate] = playing ? 1.0 : 0.0
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    if #available(iOS 13.0, *) {
      MPNowPlayingInfoCenter.default().playbackState = playing ? .playing : .paused
    }
  }

  private func hide() {
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    if #available(iOS 13.0, *) {
      MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
    stopListening()
  }

  private func startListening() {
    guard !listening else { return }
    listening = true
    let centre = MPRemoteCommandCenter.shared()

    centre.playCommand.isEnabled = true
    centre.playCommand.addTarget { [weak self] _ in
      self?.channel.invokeMethod("play", arguments: nil)
      return .success
    }
    centre.pauseCommand.isEnabled = true
    centre.pauseCommand.addTarget { [weak self] _ in
      self?.channel.invokeMethod("pause", arguments: nil)
      return .success
    }
    // The headphone button and the one big button on the card, which
    // send a toggle rather than one or the other.
    centre.togglePlayPauseCommand.isEnabled = true
    centre.togglePlayPauseCommand.addTarget { [weak self] _ in
      self?.channel.invokeMethod("toggle", arguments: nil)
      return .success
    }
    centre.stopCommand.isEnabled = true
    centre.stopCommand.addTarget { [weak self] _ in
      self?.channel.invokeMethod("stop", arguments: nil)
      return .success
    }
    // Said plainly rather than left at their defaults: there is nothing
    // to skip to and nothing to scrub along.
    centre.nextTrackCommand.isEnabled = false
    centre.previousTrackCommand.isEnabled = false
    centre.changePlaybackPositionCommand.isEnabled = false
    centre.seekForwardCommand.isEnabled = false
    centre.seekBackwardCommand.isEnabled = false

    UIApplication.shared.beginReceivingRemoteControlEvents()
  }

  private func stopListening() {
    guard listening else { return }
    listening = false
    let centre = MPRemoteCommandCenter.shared()
    centre.playCommand.removeTarget(nil)
    centre.pauseCommand.removeTarget(nil)
    centre.togglePlayPauseCommand.removeTarget(nil)
    centre.stopCommand.removeTarget(nil)
    centre.playCommand.isEnabled = false
    centre.pauseCommand.isEnabled = false
    centre.togglePlayPauseCommand.isEnabled = false
    centre.stopCommand.isEnabled = false
    UIApplication.shared.endReceivingRemoteControlEvents()
  }
}

