// Beat This! (Foscarin, Schlüter and Widmer, ISMIR 2024; MIT code and
// weights, github.com/CPJKU/beat_this), run on twenty seconds of sound:
// where the beats and the barlines were in it.
//
// The model is its "final0" checkpoint turned into Core ML by
// tool/beat_this/convert.py for exactly this window, and the picking of
// beats from what it says is its own "minimal" postprocessing
// (beat_this/model/postprocessor.py), copied here. Kept apart from the
// app so it can be checked on a Mac against the Python it copies.

#if DEBUG
import AVFoundation
import CoreML
import Foundation

final class BeatTracker {
  /// Model frames, 50 a second: a window of just under twenty seconds.
  static let frames = 1000
  /// Frames padded on to each end, which the model was not trained to
  /// read, and thrown away again after it.
  static let border = 6
  static let framesPerSecond = 50.0
  /// The sound that makes exactly [frames] frames of spectrogram.
  static let samples = (frames - 1) * LogMel.hop

  private let model: MLModel
  private let mel = LogMel()

  init(model url: URL) throws {
    let configuration = MLModelConfiguration()
    // Not the Neural Engine: on an iPad Pro (2021) getting this model
    // ready for it the first time had not finished after a minute, with
    // nothing to say why. The graphics chip and processor need no such
    // wait.
    configuration.computeUnits = .cpuAndGPU
    model = try MLModel(contentsOf: url, configuration: configuration)
  }

  /// The beats and barlines in [sound], at 22050 Hz, in seconds from its
  /// start. Shorter sound is heard as silence before it.
  func track(_ sound: [Float]) throws -> (beats: [Double], downbeats: [Double]) {
    let spectrogram = mel(BeatTracker.window(sound))
    let length = BeatTracker.frames + 2 * BeatTracker.border
    let input = try MLMultiArray(
      shape: [1, NSNumber(value: length), NSNumber(value: LogMel.bands)],
      dataType: .float32
    )
    let pointer = input.dataPointer.bindMemory(to: Float.self, capacity: length * LogMel.bands)
    pointer.initialize(repeating: 0, count: length * LogMel.bands)
    spectrogram.withUnsafeBufferPointer {
      (pointer + BeatTracker.border * LogMel.bands)
        .update(from: $0.baseAddress!, count: BeatTracker.frames * LogMel.bands)
    }
    let output = try model.prediction(
      from: MLDictionaryFeatureProvider(dictionary: ["spect": input])
    )
    let beat = BeatTracker.unpadded(output.featureValue(for: "beat")?.multiArrayValue)
    let downbeat = BeatTracker.unpadded(output.featureValue(for: "downbeat")?.multiArrayValue)
    let beats = BeatTracker.peaks(beat).map { $0 / BeatTracker.framesPerSecond }
    // Each barline moved on to the beat nearest it, as Beat This! does.
    var downbeats = BeatTracker.peaks(downbeat).map { d -> Double in
      let t = d / BeatTracker.framesPerSecond
      return beats.min(by: { abs($0 - t) < abs($1 - t) }) ?? t
    }
    downbeats = Array(Set(downbeats)).sorted()
    return (beats, downbeats)
  }

  /// The window the model hears of [sound]: its last [samples], with
  /// silence before it if it is shorter. Times it finds are from its start.
  static func window(_ sound: [Float]) -> [Float] {
    var window = sound.suffix(samples).map { $0 }
    if window.count < samples {
      window = [Float](repeating: 0, count: samples - window.count) + window
    }
    return window
  }

  /// [sound] at [rate] made into 22050 Hz, the rate the model hears at.
  static func resample(_ sound: [Float], from rate: Double) -> [Float] {
    if rate == LogMel.sampleRate { return sound }
    guard
      let from = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
      let to = AVAudioFormat(standardFormatWithSampleRate: LogMel.sampleRate, channels: 1),
      let converter = AVAudioConverter(from: from, to: to),
      let input = AVAudioPCMBuffer(pcmFormat: from, frameCapacity: AVAudioFrameCount(sound.count)),
      let output = AVAudioPCMBuffer(
        pcmFormat: to,
        frameCapacity: AVAudioFrameCount(Double(sound.count) * LogMel.sampleRate / rate) + 64
      )
    else { return [] }
    converter.sampleRateConverterQuality = AVAudioQuality.max.rawValue
    input.frameLength = AVAudioFrameCount(sound.count)
    sound.withUnsafeBufferPointer {
      input.floatChannelData![0].update(from: $0.baseAddress!, count: sound.count)
    }
    var given = false
    var error: NSError?
    converter.convert(to: output, error: &error) { _, status in
      if given {
        status.pointee = .endOfStream
        return nil
      }
      given = true
      status.pointee = .haveData
      return input
    }
    return Array(UnsafeBufferPointer(start: output.floatChannelData![0], count: Int(output.frameLength)))
  }

  /// What the model said for the window, without the borders.
  private static func unpadded(_ array: MLMultiArray?) -> [Float] {
    guard let array else { return [] }
    return (border..<(border + frames)).map { array[$0].floatValue }
  }

  /// Frames where the model is surer than even of a beat and surest
  /// within 70 ms either side; runs of neighbouring frames made one, at
  /// their average.
  private static func peaks(_ logits: [Float]) -> [Double] {
    var found = [Int]()
    for i in logits.indices where logits[i] > 0 {
      let lo = max(0, i - 3)
      let hi = min(logits.count - 1, i + 3)
      if logits[lo...hi].max() == logits[i] { found.append(i) }
    }
    var out = [Double]()
    guard var p = found.first.map(Double.init) else { return out }
    var count = 1.0
    for next in found.dropFirst().map(Double.init) {
      if next - p <= 1 {
        count += 1
        p += (next - p) / count
      } else {
        out.append(p)
        p = next
        count = 1
      }
    }
    out.append(p)
    return out
  }
}
#endif
