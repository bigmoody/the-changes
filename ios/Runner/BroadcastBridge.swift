// The app's side of hearing other apps (see BroadcastExtension). Builds
// being worked on only: a release build has neither the extension nor
// the App Group, and none of this is compiled into it.

#if DEBUG
import AVFoundation
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

  /// The room, when following through the microphone.
  private var mic: MicRecorder?

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
        let source = (call.arguments as? [String: Any])?["source"] as? String
        result(self.follow(microphone: source == "microphone"))
      case "stopFollowing":
        self.listener?.stop()
        self.listener = nil
        self.mic?.stop()
        self.mic = nil
        result(nil)
      case "keptMicrophone":
        result(self.keptMicrophone())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Starts Beat This! on what the broadcast hears, or on the room
  /// through the microphone. Nil when started, or what is missing.
  private func follow(microphone: Bool) -> String? {
    if listener != nil { return nil }
    guard let folder else { return "There is no App Group to read the broadcast from." }
    guard let model = Bundle.main.url(forResource: "BeatThis", withExtension: "mlmodelc") else {
      return "This build has no Beat This! model. Run tool/beat_this/convert.py and build again."
    }
    var ring = folder.appendingPathComponent("broadcast-ring.raw")
    if microphone {
      switch AVAudioSession.sharedInstance().recordPermission {
      case .denied:
        return "The microphone is not allowed. Allow it in Settings, The Changes."
      case .undetermined:
        // Asked once; following starts when it is next asked for.
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        return "Allow the microphone, then choose it again."
      default:
        break
      }
      ring = folder.appendingPathComponent("microphone-ring.raw")
      let mic = MicRecorder(ring: ring)
      do {
        try mic.start()
      } catch {
        return "The microphone could not start: \(error.localizedDescription)"
      }
      self.mic = mic
    }
    let listener = BeatListener(
      ring: ring,
      model: model,
      log: folder.appendingPathComponent("beat-this-log.txt"),
      source: microphone ? "the microphone" : "the broadcast"
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

  /// The microphone's last minute as a WAV, and when its last sample was
  /// heard, as the extension leaves them for the broadcast.
  private func keptMicrophone() -> [String: Any]? {
    guard let folder,
      let ring = SoundRing(readingFrom: folder.appendingPathComponent("microphone-ring.raw")),
      let latest = ring.latest(MicRecorder.keptSeconds)
    else { return nil }
    let rate = UInt32(ring.sampleRate)
    var wav = Data()
    func add<T: FixedWidthInteger>(_ value: T) {
      withUnsafeBytes(of: value.littleEndian) { wav.append(contentsOf: $0) }
    }
    let bytes = UInt32(latest.sound.count * 2)
    wav.append(contentsOf: Array("RIFF".utf8))
    add(36 + bytes)
    wav.append(contentsOf: Array("WAVEfmt ".utf8))
    add(UInt32(16))
    add(UInt16(1))
    add(UInt16(1))
    add(rate)
    add(rate * 2)
    add(UInt16(2))
    add(UInt16(16))
    wav.append(contentsOf: Array("data".utf8))
    add(bytes)
    for value in latest.sound {
      add(Int16(max(-1, min(1, value)) * 32767))
    }
    return [
      "wav": FlutterStandardTypedData(bytes: wav),
      "placed": [
        "seconds": Double(latest.sound.count) / ring.sampleRate,
        "sampleRate": ring.sampleRate,
        "endByTimestamp": latest.end,
      ],
    ]
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

  /// What it did, look by look, beside the broadcast: to be copied off
  /// the phone and read when it has not followed.
  private let log: URL
  private var lines = [String]()
  private var looks = 0
  private let queue = DispatchQueue(label: "the_changes.beat_this", qos: .userInitiated)
  private var timer: DispatchSourceTimer?
  private var tracker: BeatTracker?
  private let pitches = BarPitches()

  /// What it is listening to, in words: "the broadcast".
  private let source: String

  init(
    ring: URL, model: URL, log: URL, source: String,
    heard: @escaping ([String: Any]) -> Void
  ) {
    self.ring = ring
    self.model = model
    self.log = log
    self.source = source
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
        // The first time on a phone, Core ML makes the model ready for its
        // chips, which can take a while: said, so it is not taken for
        // nothing happening.
        note("loading the model")
        tell(["waiting": "Loading Beat This!..."])
        tracker = try BeatTracker(model: model)
        // Its first run is far slower than the rest (on an iPad Pro, 14 s
        // against a third of a second), so it is had on silence now, not
        // on the first twenty seconds of music.
        _ = try tracker!.track([])
        let took = CACurrentMediaTime() - started
        note(String(format: "loaded and warmed up in %.1f s", took))
        tell(["loaded": took])
      }
      // Opened afresh each time: a new broadcast makes a new ring.
      guard let shared = SoundRing(readingFrom: ring),
        let latest = shared.latest(Double(BeatTracker.samples) / LogMel.sampleRate + 0.1)
      else {
        note("no ring to read")
        return tell(["waiting": "Nothing from \(source) yet."])
      }
      // Nothing new for a while: the broadcast has stopped, or the
      // other app has.
      let now = CACurrentMediaTime()
      guard now - latest.end < 1.5 else {
        note(String(format: "ring %.1f s old", now - latest.end))
        return tell(["waiting": "Nothing has arrived from \(source) for a while."])
      }
      let started = CACurrentMediaTime()
      let sound = BeatTracker.resample(latest.sound, from: shared.sampleRate)
      let found = try tracker!.track(sound)
      let bars = pitches(BeatTracker.window(sound), downbeats: found.downbeats)
      // The window's last sample was played at the ring's end.
      let windowStarts = latest.end - Double(BeatTracker.samples) / LogMel.sampleRate
      looks += 1
      note(
        String(
          format: "look %d: %.1f s of sound ending %.3f, %.0f ms, %d beats, %d barlines, last %.3f",
          looks, Double(latest.sound.count) / shared.sampleRate, latest.end,
          (CACurrentMediaTime() - started) * 1000, found.beats.count, found.downbeats.count,
          found.downbeats.last.map { windowStarts + $0 } ?? 0
        )
      )
      // Every barline it said, so a look on the phone can be replayed
      // exactly on a computer.
      note(
        "  barlines "
          + found.downbeats.map { String(format: "%.3f", windowStarts + $0) }.joined(separator: " ")
      )
      tell([
        "beats": found.beats.map { windowStarts + $0 },
        "downbeats": found.downbeats.map { windowStarts + $0 },
        // What sounded in each bar between them, for placing the bars in
        // the tune.
        "bars": zip(found.downbeats, bars).map { start, heard in
          ["start": windowStarts + start, "pitches": heard.map(Double.init)] as [String: Any]
        },
        "end": latest.end,
        "took": CACurrentMediaTime() - started,
      ])
    } catch {
      note("failed: \(error)")
      tell(["problem": "Beat This! could not run: \(error.localizedDescription)"])
    }
  }

  /// A line in the log, by the phone's clock.
  private func note(_ line: String) {
    lines.append(String(format: "%.3f  ", CACurrentMediaTime()) + line)
    if lines.count > 300 { lines.removeFirst(lines.count - 300) }
    try? lines.joined(separator: "\n").write(to: log, atomically: true, encoding: .utf8)
  }

  private func tell(_ what: [String: Any]) {
    DispatchQueue.main.async { [heard] in heard(what) }
  }
}
#endif
