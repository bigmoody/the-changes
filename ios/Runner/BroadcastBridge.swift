// The app's side of hearing other apps (see BroadcastExtension). Builds
// being worked on only: a release build has neither the extension nor
// the App Group, and none of this is compiled into it.

#if DEBUG
import Flutter
import QuartzCore
import ReplayKit
import UIKit

final class BroadcastBridge {
  private let channel: FlutterMethodChannel

  /// The system's own start button, which is the only way to start a
  /// broadcast from inside an app. Kept on screen but out of sight, and
  /// pressed for the person when they press the app's.
  private var picker: RPSystemBroadcastPickerView?

  /// Where the extension writes: the group's Library.
  private let folder = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.yaseminbridges.playAlong"
  )?.appendingPathComponent("Library", isDirectory: true)

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "the_changes/broadcast",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "pick":
        result(self.pick())
      case "read":
        result(self.read("broadcast.json").map { String(decoding: $0, as: UTF8.self) })
      case "kept":
        result(self.read("broadcast.wav").map { FlutterStandardTypedData(bytes: $0) })
      case "keptPlaced":
        result(self.read("broadcast-wav.json").map { String(decoding: $0, as: UTF8.self) })
      case "now":
        // The phone's clock, which the extension's timestamps are on.
        result(CACurrentMediaTime())
      case "keepTaps":
        result(self.write(call.arguments as? String ?? "", to: "broadcast-taps.txt"))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Puts up the system's sheet for starting a broadcast, with this
  /// app's extension chosen and the microphone left off. False when
  /// there is no window to put it in.
  private func pick() -> Bool {
    guard
      let window = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .flatMap({ $0.windows })
        .first(where: { $0.isKeyWindow })
    else { return false }
    let picker = self.picker ?? RPSystemBroadcastPickerView(
      frame: CGRect(x: 0, y: 0, width: 1, height: 1)
    )
    picker.preferredExtension = "com.yaseminbridges.playAlong.BroadcastExtension"
    picker.showsMicrophoneButton = false
    picker.alpha = 0.01
    if picker.superview == nil { window.addSubview(picker) }
    self.picker = picker
    guard let button = picker.subviews.compactMap({ $0 as? UIButton }).first
    else { return false }
    button.sendActions(for: .touchUpInside)
    return true
  }

  /// Written beside what the extension kept, so all three come off the
  /// phone together.
  private func write(_ text: String, to name: String) -> Bool {
    guard let folder else { return false }
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try Data(text.utf8).write(to: folder.appendingPathComponent(name), options: .atomic)
      return true
    } catch {
      return false
    }
  }

  private func read(_ name: String) -> Data? {
    guard let folder else { return nil }
    return try? Data(contentsOf: folder.appendingPathComponent(name))
  }
}
#endif
