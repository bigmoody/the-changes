// The room, through the phone's own microphone, for Beat This! to follow
// as it follows a broadcast (see BroadcastBridge.swift). Builds being
// worked on only.
//
// Each buffer goes into a ring like the broadcast's (SoundRing.swift),
// with when it was heard by the phone's clock, so the rest is the same:
// the barlines, the count, the bar of the tune. The last minute is kept,
// to be saved with the taps made along with it.
//
// A room is quieter than a broadcast, and a quiet signal kept as 16-bit
// numbers keeps little of itself, so the level is brought up, slowly, to
// about what a broadcast gives. Slowly, so the loud and soft of a band
// are left as they are.

#if DEBUG || LISTENING
import AVFoundation
import QuartzCore

final class MicRecorder {
  static let keptSeconds = 60.0

  /// The level aimed for, root mean square: about a broadcast's.
  private static let aim = 0.1
  private static let mostGain = 64.0

  let ring: URL
  private let engine = AVAudioEngine()
  private var shared: SoundRing?

  /// How loud the room is before the gain, and the gain on it.
  private(set) var level = 0.0
  private var gain = 1.0
  private var slow = 0.0

  init(ring: URL) {
    self.ring = ring
  }

  func start() throws {
    let session = AVAudioSession.sharedInstance()
    // Measurement: none of the voice processing a call would want, which
    // would take the music for noise.
    try session.setCategory(
      .playAndRecord,
      mode: .measurement,
      options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP]
    )
    try session.setActive(true)
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    shared = SoundRing(writingTo: ring, sampleRate: format.sampleRate, seconds: MicRecorder.keptSeconds)
    input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, when in
      self?.heard(buffer, at: when)
    }
    engine.prepare()
    try engine.start()
  }

  func stop() {
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
  }

  private func heard(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime) {
    guard let data = buffer.floatChannelData else { return }
    let count = Int(buffer.frameLength)
    let channels = Int(buffer.format.channelCount)
    let rate = buffer.format.sampleRate
    guard count > 0, channels > 0 else { return }
    var mixed = [Float](repeating: 0, count: count)
    var sum = 0.0
    for i in 0..<count {
      var value: Float = 0
      for c in 0..<channels { value += data[c][i] }
      value /= Float(channels)
      mixed[i] = value
      sum += Double(value * value)
    }
    level = (sum / Double(count)).squareRoot()
    // About two seconds to follow the room's level.
    let blend = min(1, Double(count) / rate / 2)
    slow += (level - slow) * blend
    if slow > 0 {
      gain = min(MicRecorder.mostGain, max(1, MicRecorder.aim / slow))
    }
    let samples = mixed.map { Int16(max(-1, min(1, Double($0) * gain)) * 32767) }
    let starts = when.isHostTimeValid
      ? AVAudioTime.seconds(forHostTime: when.hostTime)
      : CACurrentMediaTime() - Double(count) / rate
    shared?.append(samples, endingAt: starts + Double(count) / rate)
  }
}
#endif
