// What Beat This! hears: a log-scaled mel spectrogram, made here the way
// its own code makes it (beat_this/preprocessing.py, LogMelSpect, which
// is torchaudio's MelSpectrogram): sound at 22050 Hz, a 1024-point FFT
// every 441 samples (50 frames a second), centred frames padded by
// reflection, a periodic Hann window, the FFT divided by the square root
// of its length, magnitudes, 128 Slaney mel bands from 30 Hz to 11 kHz
// without normalising them, then log(1 + 1000 x).
//
// Kept apart from everything else so it can be checked on a Mac against
// the Python it copies: on twenty seconds of St. Thomas from a broadcast,
// within 0.0001 of it everywhere.

#if DEBUG
import Accelerate
import Foundation

struct LogMel {
  static let sampleRate = 22050.0
  static let fftSize = 1024
  static let hop = 441
  static let bands = 128
  static let lowest = 30.0
  static let highest = 11000.0

  private let window: [Float]
  /// The mel filters, one row of bands for each FFT bin.
  private let filters: [Float]
  private let setup: vDSP_DFT_Setup

  init() {
    let n = LogMel.fftSize
    // Periodic: the window of n + 1 points with the last one left off.
    window = (0..<n).map { Float(0.5 - 0.5 * cos(2 * Double.pi * Double($0) / Double(n))) }
    filters = LogMel.melFilters()
    setup = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(n), .FORWARD)!
  }

  /// Frames of bands, frame after frame, from sound at 22050 Hz.
  func callAsFunction(_ sound: [Float]) -> [Float] {
    let n = LogMel.fftSize
    let half = n / 2
    let bins = half + 1
    let frames = sound.count / LogMel.hop + 1
    let padded = LogMel.reflect(sound, by: half)
    var magnitudes = [Float](repeating: 0, count: frames * bins)
    var real = [Float](repeating: 0, count: half)
    var imaginary = [Float](repeating: 0, count: half)
    var outReal = [Float](repeating: 0, count: half)
    var outImaginary = [Float](repeating: 0, count: half)
    var frame = [Float](repeating: 0, count: n)
    // vDSP's real DFT comes out twice the size of the textbook one; the
    // half undoes that, and the rest is torch's division by the root of
    // the length.
    let scale = Float(0.5 / sqrt(Double(n)))
    for f in 0..<frames {
      let start = f * LogMel.hop
      padded.withUnsafeBufferPointer { all in
        vDSP_vmul(all.baseAddress! + start, 1, window, 1, &frame, 1, vDSP_Length(n))
      }
      // Even samples in the real half, odd in the imaginary: the packing
      // a real DFT of n points is done as a complex one of n / 2.
      for i in 0..<half {
        real[i] = frame[2 * i]
        imaginary[i] = frame[2 * i + 1]
      }
      vDSP_DFT_Execute(setup, real, imaginary, &outReal, &outImaginary)
      let row = f * bins
      // The first pair holds the lowest and highest bins, which are real.
      magnitudes[row] = abs(outReal[0]) * scale
      magnitudes[row + half] = abs(outImaginary[0]) * scale
      for k in 1..<half {
        let re = outReal[k]
        let im = outImaginary[k]
        magnitudes[row + k] = (re * re + im * im).squareRoot() * scale
      }
    }
    var mel = [Float](repeating: 0, count: frames * LogMel.bands)
    vDSP_mmul(
      magnitudes, 1, filters, 1, &mel, 1,
      vDSP_Length(frames), vDSP_Length(LogMel.bands), vDSP_Length(bins)
    )
    var thousand: Float = 1000
    vDSP_vsmul(mel, 1, &thousand, &mel, 1, vDSP_Length(mel.count))
    var count = Int32(mel.count)
    var logged = [Float](repeating: 0, count: mel.count)
    vvlog1pf(&logged, mel, &count)
    return logged
  }

  /// The sound with [by] samples mirrored on to each end, the edge sample
  /// itself not repeated.
  private static func reflect(_ x: [Float], by pad: Int) -> [Float] {
    guard x.count > pad else {
      return [Float](repeating: 0, count: pad) + x + [Float](repeating: 0, count: pad)
    }
    var out = [Float]()
    out.reserveCapacity(x.count + 2 * pad)
    for i in stride(from: pad, to: 0, by: -1) { out.append(x[i]) }
    out.append(contentsOf: x)
    for i in 1...pad { out.append(x[x.count - 1 - i]) }
    return out
  }

  private static func hzToMel(_ f: Double) -> Double {
    let step = 200.0 / 3
    let logStep = log(6.4) / 27
    return f < 1000 ? f / step : 1000 / step + log(f / 1000) / logStep
  }

  private static func melToHz(_ m: Double) -> Double {
    let step = 200.0 / 3
    let logStep = log(6.4) / 27
    let edge = 1000 / step
    return m < edge ? m * step : 1000 * exp(logStep * (m - edge))
  }

  /// Triangles between evenly spaced mel points, as torchaudio makes them.
  private static func melFilters() -> [Float] {
    let bins = fftSize / 2 + 1
    let low = hzToMel(lowest)
    let high = hzToMel(highest)
    let points = (0..<(bands + 2)).map {
      melToHz(low + (high - low) * Double($0) / Double(bands + 1))
    }
    var out = [Float](repeating: 0, count: bins * bands)
    for k in 0..<bins {
      let f = sampleRate / 2 * Double(k) / Double(bins - 1)
      for b in 0..<bands {
        let down = (f - points[b]) / (points[b + 1] - points[b])
        let up = (points[b + 2] - f) / (points[b + 2] - points[b + 1])
        out[k * bands + b] = Float(max(0, min(down, up)))
      }
    }
    return out
  }
}
#endif
