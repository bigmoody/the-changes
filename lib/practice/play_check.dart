// Listening to what you actually play, while the band plays.
//
// The app already knows which chord is sounding and which note it asked you
// to land on, and it can already hear pitch (that's the tuner). Put the two
// together and it can tell you whether you found the note — change by
// change, and as a score at the end.
//
// The microphone hears concert pitch, so the checking is done against the
// tune as the band plays it, never against a chart written for a
// transposing instrument.
//
// Two rules make it fair rather than merely correct:
//
//  • Any octave counts. Landing on the 3rd is landing on the 3rd, whether
//    you play it under the band or above it.
//  • A note on the last beat of a chord also counts towards the next one.
//    Anticipating the change is good playing, not a miss — and the pitch
//    detector is a beat-fraction behind what you played anyway.

import '../music/chord.dart';
import '../music/chord_drill.dart';
import '../music/tune.dart';
import '../music/tuning.dart';

/// One chord you were asked to land on, and what you played on it.
class AimedChord {
  AimedChord({
    required this.chord,
    required this.startBeat,
    required this.endBeat,
    required this.chorus,
    required this.degrees,
  });

  final Chord chord;

  /// Beats of the tune this chord covers, and which time round it was.
  /// A chord written out over several bars runs on: it's one place to land,
  /// however many times the chart repeats the symbol.
  final int startBeat;
  int endBeat;
  final int chorus;

  /// The degrees asked for on this chord — "3", "b7" — as they're written.
  final List<String> degrees;

  /// Notes heard while it sounded, as pitch classes (0 = C).
  final heard = <int>{};

  /// The pitch classes that would count as landing on it.
  Set<int> get targets => {
    for (final degree in degrees) chord.pitchClassFor(degree),
  };

  /// Whether anything at all was played on this chord.
  bool get played => heard.isNotEmpty;

  /// Whether one of the notes asked for was among them.
  bool get hit => heard.intersection(targets).isNotEmpty;

  /// What to call the notes asked for: "E♭ (♭3)".
  String get asked => [
    for (final degree in degrees)
      '${chord.noteFor(degree)} (${prettyDegree(degree)})',
  ].join(' · ');
}

/// Marks each change as it goes by: did you land on the note or not?
///
/// It's driven from outside — the practice screen says where the band has
/// got to, and the microphone says what it heard — so all of this is plain
/// maths that can be tested without either.
class PlayCheck {
  PlayCheck({required this.tune, required this.target, this.anticipation = 1});

  /// The tune as the band plays it: concert pitch, which is what the
  /// microphone hears.
  final Tune tune;
  final DrillTarget target;

  /// How many beats before a chord change a note still counts towards the
  /// chord coming up.
  final int anticipation;

  /// Every change that has gone by, oldest first.
  final _done = <AimedChord>[];
  List<AimedChord> get done => List.unmodifiable(_done);

  /// The change sounding now, if it's one that can be scored.
  AimedChord? get current => _current;
  AimedChord? _current;

  /// The one before it, kept so a note played a hair late still lands.
  AimedChord? _previous;

  int? _beat;
  int? _chorus;

  /// How many changes have been scored, and how many you found.
  int get asked => _done.length;
  int get hits => _done.where((c) => c.hit).length;
  int get misses => asked - hits;

  /// Nought to one, or null before anything has been scored.
  double? get accuracy => _done.isEmpty ? null : hits / _done.length;

  /// Notes played in the last beat before a change, waiting for it.
  final _pending = <int>{};

  /// Whether this chord can be scored at all: a chord with no 7th can't be
  /// asked for its 7th.
  List<String>? _degreesOn(Chord chord) {
    final degrees = [
      for (final number in target.numbers) ?degreeFor(chord, number),
    ];
    return degrees.isEmpty ? null : degrees;
  }

  /// Where the band has got to. Closes off any change that has gone by.
  void moveTo(int tuneBeat, int chorus) {
    if (tuneBeat == _beat && chorus == _chorus) return;
    _beat = tuneBeat;
    _chorus = chorus;
    final slot = tune.slotAtBeat(tuneBeat);
    final open = _current;
    if (open != null && open.chorus == chorus) {
      if (open.startBeat == slot.startBeat) return; // still the same bar
      // The next bar holds the same chord: one change, not two. The chart
      // repeats the symbol to be read, but there's nothing new to land on.
      if (slot.startBeat == open.endBeat &&
          slot.chord.display == open.chord.display) {
        open.endBeat = slot.endBeat;
        return;
      }
    }
    // The chord changed: score the one that has just finished.
    if (open != null) {
      _done.add(open);
      _previous = open;
    }
    final degrees = _degreesOn(slot.chord);
    if (degrees == null) {
      _current = null;
    } else {
      _current = AimedChord(
        chord: slot.chord,
        startBeat: slot.startBeat,
        endBeat: slot.endBeat,
        chorus: chorus,
        degrees: degrees,
      );
      // Anything played into the change belongs to this chord.
      _current!.heard.addAll(_pending);
    }
    _pending.clear();
  }

  /// A note the microphone heard, at concert pitch. [midi] may be
  /// fractional; anything more than a quarter-tone off a note is too vague
  /// to call, and is dropped.
  void note(double midi) {
    final near = noteNear(midi);
    if (near.cents.abs() > 45) return;
    final pitchClass = near.midi % 12;
    final playing = _current;
    final beat = _beat;
    if (playing == null || beat == null) return;
    playing.heard.add(pitchClass);
    // Heard right at the top of a chord? The detector runs a moment behind
    // what you played, so it may well have been the end of the one before.
    if (beat - playing.startBeat < anticipation) {
      _previous?.heard.add(pitchClass);
    }
    // Played into the last beat: it counts towards the change coming up.
    if (playing.endBeat - beat <= anticipation) _pending.add(pitchClass);
  }

  /// Ends the run: the change still sounding is scored if it was played on,
  /// and nothing more is counted.
  void finish() {
    final open = _current;
    if (open != null && open.played) _done.add(open);
    _current = null;
    _previous = null;
    _pending.clear();
  }

  /// "9 of 12 changes", or what it's waiting for.
  String describe() {
    if (_done.isEmpty) return 'Listening…';
    return '$hits of ${_done.length}';
  }
}
