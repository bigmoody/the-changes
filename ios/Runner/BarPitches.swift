// Which notes sound in each half of each bar: for placing the bars heard
// in the tune (see form_finder.dart), by matching them to the chart's
// chords. Builds being worked on only.
//
// A long FFT (8192 points at 22050 Hz, steps of 2048), its power folded
// into the twelve pitch classes twice: from 55 Hz to 2 kHz for the
// harmony, and from 30 to 130 Hz for the bass, which most often plays the
// root. Tried on four broadcasts of St. Thomas, with the bar numbers
// someone listening tapped: matched to the chart, eight bars of this put
// the band in the right bar of the tune 141 times in 143.

#if DEBUG
import Accelerate
import Foundation

struct BarPitches {
  static let fftSize = 8192
  static let hop = 2048

  private let window: [Float]
  private let setup: vDSP_DFT_Setup
  /// The pitch class of each FFT bin, or -1 outside the range.
  private let harmony: [Int]
  private let bass: [Int]

  init() {
    let n = BarPitches.fftSize
    window = (0..<n).map { Float(0.5 - 0.5 * cos(2 * Double.pi * Double($0) / Double(n))) }
    setup = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(n), .FORWARD)!
    func classes(_ low: Double, _ high: Double) -> [Int] {
      (0...(n / 2)).map { k in
        let f = LogMel.sampleRate * Double(k) / Double(n)
        guard f >= low, f < high else { return -1 }
        let semitones = Int((12 * log2(f / 440)).rounded())
        return ((semitones + 9) % 12 + 12) % 12
      }
    }
    harmony = classes(55, 2000)
    bass = classes(30, 130)
  }

  /// For each bar between [downbeats] (seconds from the window's start),
  /// 48 numbers: the harmony and the bass of its first half, then of its
  /// second, twelve pitch classes each from C.
  func callAsFunction(_ window: [Float], downbeats: [Double]) -> [[Float]] {
    let frames = spectra(window)
    let rate = LogMel.sampleRate / Double(BarPitches.hop)
    return zip(downbeats, downbeats.dropFirst()).map { start, end in
      let middle = (start + end) / 2
      var out = [Float]()
      for (from, to) in [(start, middle), (middle, end)] {
        let first = max(0, Int((from * rate).rounded(.up)))
        let last = min(frames.count, Int((to * rate).rounded(.up)))
        var sum = [Float](repeating: 0, count: 24)
        if first < last {
          for f in first..<last {
            for i in 0..<24 { sum[i] += frames[f][i] }
          }
          for i in 0..<24 { sum[i] /= Float(last - first) }
        }
        out += sum
      }
      return out
    }
  }

  /// Each step's harmony and bass, 24 numbers: frames centred on each
  /// step, the first on the sound's first sample.
  func spectra(_ sound: [Float]) -> [[Float]] {
    let n = BarPitches.fftSize
    let half = n / 2
    let count = sound.count / BarPitches.hop + 1
    var real = [Float](repeating: 0, count: half)
    var imaginary = [Float](repeating: 0, count: half)
    var outReal = [Float](repeating: 0, count: half)
    var outImaginary = [Float](repeating: 0, count: half)
    var frame = [Float](repeating: 0, count: n)
    var out = [[Float]]()
    out.reserveCapacity(count)
    for f in 0..<count {
      let centre = f * BarPitches.hop
      for i in 0..<n {
        let at = centre - half + i
        frame[i] = at >= 0 && at < sound.count ? sound[at] * window[i] : 0
      }
      for i in 0..<half {
        real[i] = frame[2 * i]
        imaginary[i] = frame[2 * i + 1]
      }
      vDSP_DFT_Execute(setup, real, imaginary, &outReal, &outImaginary)
      var pitches = [Float](repeating: 0, count: 24)
      for k in 1..<half {
        let power = outReal[k] * outReal[k] + outImaginary[k] * outImaginary[k]
        if harmony[k] >= 0 { pitches[harmony[k]] += power }
        if bass[k] >= 0 { pitches[12 + bass[k]] += power }
      }
      out.append(pitches.map { $0.squareRoot() })
    }
    return out
  }
}
#endif
