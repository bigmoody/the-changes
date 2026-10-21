// Which tune a band is playing, from its changes. Builds being worked on
// only.
//
// A recording can't be recognised the way a record is: every band plays
// the tune in its own key, at its own tempo, with its own voicings. What
// stays the same is the changes, moved. So the beat is found in the notes
// starting (Pulse, in ChordFollower.swift), the harmony and bass heard each
// half bar (BarPitches.swift), and every chart is tried against them: in
// all twelve keys, from every bar, with each beat of the beat found as the
// first of the bar, and at the tempo found, twice it and half it. The
// charts that fit best come first.
//
// Tunes on the same changes fit equally well: a blues is a blues and
// rhythm changes are rhythm changes, whatever the head. The answer is a
// short list, not a name.

#if DEBUG
import Foundation

final class TuneFinder {
  /// One chart to try: each half bar's notes and bass.
  struct Chart {
    let id: String
    let beatsPerBar: Int
    let halves: [ChordFollower.Half]
  }

  /// How well a chart fits: moved up [semitones] from the chart's key,
  /// with its bar [bar] starting [barStart] seconds into the sound.
  struct Fit {
    let id: String
    let score: Double
    let semitones: Int
    let tempo: Double
    let barStart: Double
    let bar: Int
  }

  private let charts: [Chart]
  /// Every different half bar in the charts, and which each chart's are.
  private let kinds: [ChordFollower.Half]
  private let chartKinds: [[Int]]
  private let pitches = BarPitches()
  private let pulse = Pulse()

  init(charts: [Chart]) {
    self.charts = charts.filter { $0.halves.count >= 2 && $0.halves.count % 2 == 0 }
    var kinds = [ChordFollower.Half]()
    var index = [String: Int]()
    chartKinds = self.charts.map { chart in
      chart.halves.map { half in
        let key = "\(half.tones)|\(half.bass)"
        if let i = index[key] { return i }
        index[key] = kinds.count
        kinds.append(half)
        return kinds.count - 1
      }
    }
    self.kinds = kinds
  }

  /// From the charts as the app sends them.
  static func from(_ charts: Any?) -> TuneFinder? {
    guard let list = charts as? [[String: Any]] else { return nil }
    return TuneFinder(
      charts: list.compactMap { chart in
        guard let id = chart["id"] as? String, let perBar = chart["beatsPerBar"] as? Int,
          let halves = chart["halves"] as? [[String: Any]]
        else { return nil }
        return Chart(id: id, beatsPerBar: perBar, halves: halves.map(ChordFollower.Half.from))
      }
    )
  }

  /// The charts that fit [sound] (at LogMel.sampleRate, thirty seconds or
  /// so), best first.
  func callAsFunction(_ sound: [Float]) -> [Fit] {
    guard !charts.isEmpty, let (tempo, phase) = pulse.find(sound) else { return [] }
    let rate = LogMel.sampleRate
    let steps = pitches.spectra(sound)
    let stepTime = Double(BarPitches.hop) / rate
    let end = Double(sound.count) / rate
    // Each half bar's tones, the same length whatever their loudness.
    let unitTones = kinds.map { unit($0.tones) }
    var best = [Int: Fit]()
    for perBar in Set(charts.map(\.beatsPerBar)) {
      let which = charts.indices.filter { charts[$0].beatsPerBar == perBar }
      // The beat found, twice as quick and half as quick; for half as
      // quick, every other beat found may be the first.
      for (times, firsts) in [(1.0, perBar), (2.0, perBar), (0.5, 2 * perBar)] {
        let beat = 60 / (tempo * times)
        let found = 60 / tempo
        let bar = beat * Double(perBar)
        guard (60...320).contains(tempo * times), bar <= end / 3 else { continue }
        for first in 0..<firsts {
          let origin = phase + Double(first) * min(beat, found)
          let heard = halves(steps, stepTime: stepTime, origin: origin, length: bar / 2, end: end)
          guard heard.count >= 4 else { continue }
          // How well each half bar heard fits each kind of half bar, in
          // each key.
          var fits = [[Double]](repeating: [Double](repeating: 0, count: 12 * kinds.count), count: heard.count)
          for (h, half) in heard.enumerated() {
            for (u, kind) in kinds.enumerated() {
              for t in 0..<12 {
                var dot: Float = 0
                for c in 0..<12 { dot += half.harmony[(c + t) % 12] * unitTones[u][c] }
                fits[h][12 * u + t] = Double(dot) + 0.5 * Double(half.bass[(kind.bass + t) % 12])
              }
            }
          }
          for c in which {
            let kindsHere = chartKinds[c]
            let count = kindsHere.count
            var scores = [Double]()
            scores.reserveCapacity(6 * count)
            var top = (score: -1.0, k: 0, t: 0)
            for k in 0..<(count / 2) {
              for t in 0..<12 {
                var sum = 0.0
                for (h, half) in heard.enumerated() {
                  sum += fits[h][12 * kindsHere[(half.index + 2 * k) % count] + t]
                }
                let score = sum / Double(heard.count)
                scores.append(score)
                if score > top.score { top = (score, k, t) }
              }
            }
            // A chart that sits on one chord fits most music about as well
            // from any bar and in many keys. What tells is how far the best
            // fit stands out from the chart's others.
            let mean = scores.reduce(0, +) / Double(scores.count)
            let spread = (scores.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(scores.count)).squareRoot()
            guard spread > 0 else { continue }
            let standsOut = (top.score - mean) / spread
            if standsOut > best[c]?.score ?? -.infinity {
              // Which bar of the chart the last whole bar is.
              let bars = ((end - bar - origin) / bar).rounded(.down)
              best[c] = Fit(
                id: charts[c].id, score: standsOut, semitones: top.t, tempo: tempo * times,
                barStart: origin + bars * bar,
                bar: (TuneFinder.before / 2 + top.k + Int(bars)) % (count / 2))
            }
          }
        }
      }
    }
    return best.values.sorted { $0.score > $1.score }
  }

  private struct Heard {
    let index: Int
    let harmony: [Float]
    let bass: [Float]
  }

  /// Half bars counted from a barline this many before [origin], so that
  /// none is counted below nought and an even count is a barline.
  private static let before = 1000

  /// The harmony and bass of each whole half bar about [origin], the same
  /// length whatever their loudness.
  private func halves(
    _ steps: [[Float]], stepTime: Double, origin: Double, length: Double, end: Double
  ) -> [Heard] {
    var out = [Heard]()
    var h = Int(((0 - origin) / length).rounded(.up))
    while origin + Double(h + 1) * length <= end {
      let from = Int(((origin + Double(h) * length) / stepTime).rounded(.up))
      let to = min(steps.count, Int(((origin + Double(h + 1) * length) / stepTime).rounded(.up)))
      if from < to {
        var harmony = [Float](repeating: 0, count: 12)
        var bass = [Float](repeating: 0, count: 12)
        for s in from..<to {
          for c in 0..<12 {
            harmony[c] += steps[s][c]
            bass[c] += steps[s][12 + c]
          }
        }
        out.append(Heard(index: h + TuneFinder.before, harmony: unit(harmony), bass: unit(bass)))
      }
      h += 1
    }
    return out
  }

  private func unit(_ values: [Float]) -> [Float] {
    let length = (values.reduce(0) { $0 + $1 * $1 }).squareRoot()
    return length > 0 ? values.map { $0 / length } : values
  }
}
#endif
