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

  /// Beat This!, listening to what the broadcast hears, while asked to.
  private var listener: BeatListener?

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
      case "follow":
        result(self.follow())
      case "stopFollowing":
        self.listener?.stop()
        self.listener = nil
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Starts Beat This! on what the broadcast hears. Nil when started, or
  /// what is missing.
  private func follow() -> String? {
    if listener != nil { return nil }
    guard let folder else { return "There is no App Group to read the broadcast from." }
    guard let model = Bundle.main.url(forResource: "BeatThis", withExtension: "mlmodelc") else {
      return "This build has no Beat This! model. Run tool/beat_this/convert.py and build again."
    }
    let listener = BeatListener(
      ring: folder.appendingPathComponent("broadcast-ring.raw"),
      model: model
    ) { [weak self] heard in
      self?.channel.invokeMethod("heard", arguments: heard)
    }
    listener.start()
    self.listener = listener
    return nil
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
/// Beat This! once a second on the last twenty seconds the broadcast
/// heard, off the main thread. What it hears goes to [heard], on the main
/// thread, by the phone's clock.
final class BeatListener {
  private let ring: URL
  private let model: URL
  private let heard: ([String: Any]) -> Void
  private let queue = DispatchQueue(label: "the_changes.beat_this", qos: .userInitiated)
  private var timer: DispatchSourceTimer?
  private var tracker: BeatTracker?

  init(ring: URL, model: URL, heard: @escaping ([String: Any]) -> Void) {
    self.ring = ring
    self.model = model
    self.heard = heard
  }

  func start() {
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now(), repeating: 1.0)
    timer.setEventHandler { [weak self] in self?.look() }
    timer.resume()
    self.timer = timer
  }

  func stop() {
    timer?.cancel()
    timer = nil
  }

  private func look() {
    do {
      if tracker == nil {
        let started = CACurrentMediaTime()
        tracker = try BeatTracker(model: model)
        tell(["loaded": CACurrentMediaTime() - started])
      }
      // Opened afresh each time: a new broadcast makes a new ring.
      guard let shared = SoundRing(readingFrom: ring),
        let latest = shared.latest(Double(BeatTracker.samples) / LogMel.sampleRate + 0.1)
      else { return tell(["waiting": "Nothing from the broadcast yet."]) }
      // Nothing new for a while: the broadcast has stopped, or the
      // other app has.
      let now = CACurrentMediaTime()
      guard now - latest.end < 1.5 else {
        return tell(["waiting": "Nothing has arrived from the broadcast for a while."])
      }
      let started = CACurrentMediaTime()
      let sound = BeatTracker.resample(latest.sound, from: shared.sampleRate)
      let found = try tracker!.track(sound)
      // The window's last sample was played at the ring's end.
      let windowStarts = latest.end - Double(BeatTracker.samples) / LogMel.sampleRate
      tell([
        "beats": found.beats.map { windowStarts + $0 },
        "downbeats": found.downbeats.map { windowStarts + $0 },
        "end": latest.end,
        "took": CACurrentMediaTime() - started,
      ])
    } catch {
      tell(["problem": "Beat This! could not run: \(error.localizedDescription)"])
    }
  }

  private func tell(_ what: [String: Any]) {
    DispatchQueue.main.async { [heard] in heard(what) }
  }
}
#endif
