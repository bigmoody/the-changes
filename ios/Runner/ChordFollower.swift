// Where a band is in the tune when Beat This! cannot hear it: a band with
// no drums. Builds being worked on only.
//
// Beat This! hears the beat mostly in the drums. Without them, on Blue
// Monk through a microphone, it heard about 70 for a tune at 130, and its
// barlines were scattered. The piano still comps on the beat: the notes
// starting between 200 Hz and 2 kHz, found every 12 ms, repeat at the beat,
// and their autocorrelation gave 125 to 133 in nine stretches of twelve.
// Given that beat, only which of its beats starts the bar and which bar
// of the chart it is are left, and the chords tell them: the harmony and
// bass heard (BarPitches.swift) against the chart's chords, each half bar,
// every choice tried. On thirty seconds of Blue Monk with no drums, five
// stretches in six put it in the bar that was tapped. The best choice was
// seldom far ahead of the next, so one answer is not taken on its own
// (see tap_follower.dart).

#if DEBUG
import Accelerate
import Foundation

final class ChordFollower {
  /// The chart, half a bar at a time: the chord's notes, and its bass.
  struct Half {
    let tones: [Float]
    let bass: Int

    /// From the app's: its pitch classes and its bass.
    static func from(_ half: [String: Any]) -> Half {
      var tones = [Float](repeating: 0, count: 12)
      for pc in half["pcs"] as? [Int] ?? [] { tones[(pc % 12 + 12) % 12] = 1 }
      return Half(tones: tones, bass: ((half["bass"] as? Int ?? 0) % 12 + 12) % 12)
    }
  }

  /// What it made of the sound: the tempo, a bar it says starts at
  /// [barStart] seconds from the sound's start, which bar of the chart
  /// that is, and how far its best guess led the next.
  struct Heard {
    let tempo: Double
    let barStart: Double
    let bar: Int
    let lead: Double
  }

  private let chart: [Half]
  private let beatsPerBar: Int
  private let pitches = BarPitches()
  private let pulse = Pulse()

  /// From the chart as the app sends it: each half bar's notes and bass.
  static func from(_ chart: Any?, beatsPerBar: Any?) -> ChordFollower? {
    guard let halves = chart as? [[String: Any]], let perBar = beatsPerBar as? Int,
      halves.count >= 2, halves.count % 2 == 0
    else { return nil }
    return ChordFollower(
      chart: halves.map(Half.from),
      beatsPerBar: perBar
    )
  }

  init(chart: [Half], beatsPerBar: Int) {
    self.chart = chart
    self.beatsPerBar = beatsPerBar
  }

  /// [sound] at LogMel.sampleRate, thirty seconds or so.
  func callAsFunction(_ sound: [Float]) -> Heard? {
    let rate = LogMel.sampleRate
    guard chart.count >= 2, let (tempo, phase) = pulse.find(sound) else { return nil }
    let beat = 60 / tempo
    // The chords, a step at a time.
    let steps = pitches.spectra(sound)
    let stepTime = Double(BarPitches.hop) / rate
    let bar = beat * Double(beatsPerBar)
    let halves = chart.count
    var scores = [(score: Double, origin: Double, bar: Int)]()
    for first in 0..<beatsPerBar {
      let origin = phase + Double(first) * beat
      var harmony = [Int: [Float]]()
      var bass = [Int: [Float]]()
      for (i, step) in steps.enumerated() {
        let h = Int(((Double(i) * stepTime - origin) / (bar / 2)).rounded(.down))
        var hm = harmony[h] ?? [Float](repeating: 0, count: 12)
        var bs = bass[h] ?? [Float](repeating: 0, count: 12)
        for c in 0..<12 {
          hm[c] += step[c]
          bs[c] += step[12 + c]
        }
        harmony[h] = hm
        bass[h] = bs
      }
      for k in 0..<(halves / 2) {
        var sum = 0.0
        for (h, hm) in harmony {
          let half = chart[(((h + 2 * k) % halves) + halves) % halves]
          sum += cosine(hm, half.tones)
          let bs = bass[h]!
          let length = (bs.reduce(0) { $0 + $1 * $1 }).squareRoot()
          if length > 0 { sum += 0.5 * Double(bs[half.bass] / length) }
        }
        scores.append((sum / Double(harmony.count), origin, k))
      }
    }
    scores.sort { $0.score > $1.score }
    guard scores.count >= 2 else { return nil }
    let best = scores[0]
    // The last whole bar in the sound, and which bar of the chart it is.
    let end = Double(sound.count) / rate
    let bars = ((end - bar - best.origin) / bar).rounded(.down)
    return Heard(
      tempo: tempo,
      barStart: best.origin + bars * bar,
      bar: ((best.bar + Int(bars)) % (halves / 2) + halves / 2) % (halves / 2),
      lead: best.score - scores[1].score
    )
  }

  private func cosine(_ a: [Float], _ b: [Float]) -> Double {
    var dot: Float = 0
    var aa: Float = 0
    var bb: Float = 0
    for i in 0..<a.count {
      dot += a[i] * b[i]
      aa += a[i] * a[i]
      bb += b[i] * b[i]
    }
    return aa == 0 || bb == 0 ? 0 : Double(dot / (aa * bb).squareRoot())
  }
}

/// The beat in the notes starting, for when there are no drums to hear it
/// in: its tempo, and where its beats fall.
struct Pulse {
  static let size = 1024
  static let hop = 256

  /// The tempos tried. A tune quicker than 200 is heard at half its tempo,
  /// one slower than 90 at twice it.
  static let slowest = 90.0
  static let quickest = 200.0

  private let window: [Float]
  private let setup: vDSP_DFT_Setup

  init() {
    let n = Pulse.size
    window = (0..<n).map { Float(0.5 - 0.5 * cos(2 * Double.pi * Double($0) / Double(n))) }
    setup = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(n), .FORWARD)!
  }

  /// The tempo of [sound] (at LogMel.sampleRate, ten seconds or more), and
  /// the seconds from its start to its first beat.
  func find(_ sound: [Float]) -> (tempo: Double, phase: Double)? {
    let fps = LogMel.sampleRate / Double(Pulse.hop)
    let onsets = starts(sound)
    guard onsets.count > Int(10 * fps) else { return nil }
    let offset = Double(Pulse.size / 2) / LogMel.sampleRate
    let tempo = self.tempo(onsets, fps: fps)
    // At either end of the tempos tried, the band's is likely beyond it:
    // a guitar at 205 to 212 came out as 200 every time.
    guard tempo > Pulse.slowest + 1, tempo < Pulse.quickest - 1 else { return nil }
    let beat = 60 / tempo
    // Where the beats fall: the phase whose beats land on most onsets.
    var phase = 0.0
    var most = -1.0
    for step in 0..<Int(beat / 0.01) {
      let ph = Double(step) * 0.01
      var sum = 0.0
      var at = ph
      while at < Double(onsets.count) / fps {
        sum += value(onsets, at: (at - offset) * fps)
        at += beat
      }
      if sum > most {
        most = sum
        phase = ph
      }
    }
    return (tempo, phase)
  }

  /// How strongly notes start between 200 Hz and 2 kHz, every hop: the rise
  /// in log level, added up, less its average over the last second.
  private func starts(_ sound: [Float]) -> [Double] {
    let n = Pulse.size
    let half = n / 2
    let rate = LogMel.sampleRate
    let low = Int((200 * Double(n) / rate).rounded(.up))
    let high = Int(2000 * Double(n) / rate)
    var real = [Float](repeating: 0, count: half)
    var imaginary = [Float](repeating: 0, count: half)
    var outReal = [Float](repeating: 0, count: half)
    var outImaginary = [Float](repeating: 0, count: half)
    var frame = [Float](repeating: 0, count: n)
    var last = [Float](repeating: 0, count: high - low + 1)
    var out = [Double]()
    var start = 0
    while start + n <= sound.count {
      for i in 0..<n { frame[i] = sound[start + i] * window[i] }
      for i in 0..<half {
        real[i] = frame[2 * i]
        imaginary[i] = frame[2 * i + 1]
      }
      vDSP_DFT_Execute(setup, real, imaginary, &outReal, &outImaginary)
      var rise = 0.0
      for k in low...high {
        let magnitude = (outReal[k] * outReal[k] + outImaginary[k] * outImaginary[k]).squareRoot()
        let level = log1p(100 * magnitude)
        if start > 0 { rise += Double(max(0, level - last[k - low])) }
        last[k - low] = level
      }
      out.append(rise)
      start += Pulse.hop
    }
    // Less the average about it, a second wide.
    let width = Int(rate / Double(Pulse.hop))
    var sums = [Double](repeating: 0, count: out.count + 1)
    for i in 0..<out.count { sums[i + 1] = sums[i] + out[i] }
    return (0..<out.count).map { i in
      let from = max(0, i - width / 2)
      let to = min(out.count, i + width - width / 2)
      return max(0, out[i] - (sums[to] - sums[from]) / Double(to - from))
    }
  }

  /// The tempo whose beats the onsets repeat at most, one to four beats
  /// apart.
  private func tempo(_ onsets: [Double], fps: Double) -> Double {
    let mean = onsets.reduce(0, +) / Double(onsets.count)
    let centred = onsets.map { $0 - mean }
    let longest = Int(4 * 60 / Pulse.slowest * fps) + 2
    var ac = [Double](repeating: 0, count: longest)
    for lag in 0..<longest {
      var sum = 0.0
      for i in 0..<(centred.count - lag) { sum += centred[i] * centred[i + lag] }
      ac[lag] = sum
    }
    var best = Pulse.slowest
    var most = -Double.infinity
    var bpm = Pulse.slowest
    while bpm <= Pulse.quickest {
      var sum = 0.0
      for k in 1...4 { sum += value(ac, at: Double(k) * 60 / bpm * fps) }
      if sum > most {
        most = sum
        best = bpm
      }
      bpm += 0.5
    }
    return best
  }

  private func value(_ values: [Double], at index: Double) -> Double {
    guard index >= 0 else { return 0 }
    let i = Int(index)
    guard i + 1 < values.count else { return 0 }
    let f = index - Double(i)
    return values[i] * (1 - f) + values[i + 1] * f
  }
}
#endif
