// Whether a recording of real players will fit a chart they never played.
//
// A take is three files of people playing one set of changes once. The app
// already knows how to move it: resample for the tempo, shift the pitch
// back for the key, and measure how hard that is working. What it did not
// know is whether the changes under the chart in front of you are the
// changes those people played, and without that a take belongs to the one
// tune it was imported against. Record a blues in F and you have a real
// band for exactly one blues.
//
// They are the same changes if they are the same changes moved. So: every
// shift from nought to eleven semitones is tried, and one of them has to
// line the two charts up bar for bar, chord for chord, with the same
// shape on every one of them and the same number of beats.
//
// Strict about what matters and deliberately not about what does not.
// C6 against CΔ7 is yes, because a bass player walks the same notes under
// both and the difference is somebody's pen. Cm7 against C7 is no, and
// has to be no, because that is the wrong 3rd under everybody's solo. The
// line between those two is [ChordShape], and it is drawn there for this
// reason as much as any.
//
// What this must never do is say yes when it is not sure. A band playing
// the wrong changes under a chart is worse than no band at all: it does
// not sound like a mistake, it sounds like you are playing the mistake.

import 'chord_shape.dart';
import 'tune.dart';

/// How a take lines up with a chart it did not come from.
///
/// [semitones] is how far the recording has to move to sit under the
/// chart, nought to eleven.
typedef ChangesMatch = ({int semitones, int bars});

/// How far [recorded] has to move to be [chart]'s changes, or null where
/// it is not them at any distance.
///
/// Both tunes are taken as written. A chart shown transposed for a B♭
/// player is still the same music, so pass the concert chart, which is
/// what the controller calls `tune` rather than `chart`.
ChangesMatch? movesOnto(Tune recorded, Tune chart) {
  if (recorded.barCount != chart.barCount) return null;
  if (recorded.beatsPerBar != chart.beatsPerBar) return null;
  if (recorded.barCount == 0) return null;

  for (var semitones = 0; semitones < 12; semitones++) {
    if (_fits(recorded, chart, semitones)) {
      return (semitones: semitones, bars: chart.barCount);
    }
  }
  return null;
}

/// Whether [recorded] moved up [semitones] is [chart], bar for bar.
bool _fits(Tune recorded, Tune chart, int semitones) {
  for (var bar = 0; bar < chart.barCount; bar++) {
    final was = recorded.bars[bar];
    final now = chart.bars[bar];
    // Two chords in a bar against one is a different bar, whatever the
    // chords are: the players changed in the middle of it and the chart
    // does not, or the other way about.
    if (was.length != now.length) return false;
    for (var i = 0; i < was.length; i++) {
      if (was[i].beats != now[i].beats) return false;
      if (shapeOf(was[i].chord) != shapeOf(now[i].chord)) return false;
      if ((was[i].chord.root + semitones) % 12 != now[i].chord.root % 12) {
        return false;
      }
      // A slash chord is a different chord: the bass player is being told
      // what to play, and a take that does not have that note underneath
      // is not playing these changes.
      if ((was[i].chord.bass + semitones) % 12 != now[i].chord.bass % 12) {
        return false;
      }
    }
  }
  return true;
}
