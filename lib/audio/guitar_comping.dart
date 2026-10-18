// What the guitarist comps, when the band has a guitar instead of a piano.
//
// The guitarist hears the same harmony as the pianist (rootless four-note
// voicings of 3rd, 7th, 9th and 13th, altered when a dominant resolves to a
// minor chord), but plays them the way a guitar lays them out: drop-2 shapes
// on the top four or middle four strings, drop-3 shapes with the bass note
// on the 6th or 5th string, every one within a four-fret reach. Of those,
// the shape nearest the last one is chosen, so the top voice moves by step
// and the hand barely shifts, as a good comper's does.
//
// The rhythm is the guitar's own in each style:
//
//  • Swing: the pianist's rhythmic sense (the Charleston, pushes into the
//    next chord, off-beat stabs, and space when a chord is simply held),
//    played as quick, clean downstrokes.
//  • Bossa (and other straight-eighth Latin): the voicing plucked with the
//    fingers on one of the bossa guitar's two-bar figures.
//  • Calypso: the strum (down, down-up, up-down-up).
//  • Funk: short, high chops on the sixteenths, on the top three strings;
//    one riff held for a four-bar phrase, the way a funk player locks in.
//  • Soul (funk under 95 BPM, like Mercy, Mercy, Mercy): small chords on 2
//    and 4, the backbeat, with a light pickup now and then.
//  • Held: one strum on each change, left to ring.

import 'dart:math' as math;

import '../music/chord.dart';
import '../music/comping.dart';
import '../music/guitar_voicing.dart';
import '../music/tune.dart';
import 'piano_comping.dart';

enum Strum { down, up, together }

typedef GuitarHit = ({
  double beat,
  double length,
  double velocity,
  List<int> notes,
  Strum strum,
});

/// A rhythm across a whole bar: (beat, length, how hard, stroke).
typedef _Bar = List<(double, double, double, Strum)>;

/// Where a guitarist's comping hand sits: the lowest note of the shape
/// around A2–E3, mid-neck, above the bass, below a soloist.
const guitarCompHome = 53;

/// The highest note a comping shape reaches: D5.
const guitarCompTop = 74;

/// String sets for four-note shapes, low to high (0 = low E). Drop-2 on the
/// top four and the middle four; drop-3 with the 5th or 4th string skipped.
const _drop2Sets = [
  [2, 3, 4, 5],
  [1, 2, 3, 4],
];
const _drop3Sets = [
  [0, 2, 3, 4],
  [1, 3, 4, 5],
];

/// Every playable four-note comping shape for [chord], as MIDI notes low to
/// high: the pianist's rootless voicing (3rd, 7th, 9th, 13th …), in each
/// inversion, as drop-2 and drop-3 shapes on the strings that take them,
/// with no fret more than three above the lowest one.
List<List<int>> guitarCompVoicings(Chord chord, {Chord? resolvingTo}) {
  final tones = <int>{
    for (final note in voicingsFor(chord, resolvingTo: resolvingTo).first)
      note % 12,
  }.toList();
  if (tones.length < 4) {
    // A sus or odd chord that doubles a note: add the root to fill it out.
    tones.add(chord.root);
  }
  // In order up the octave, so each rotation is a close voicing.
  tones.sort();
  final shapes = <String, List<int>>{};
  for (var rotation = 0; rotation < tones.length; rotation++) {
    // A close voicing starting on this note, within an octave.
    final close = <int>[];
    for (var i = 0; i < 4; i++) {
      final pc = tones[(rotation + i) % tones.length];
      var note = close.isEmpty ? pc : close.last + (pc - close.last) % 12;
      if (close.isNotEmpty && note == close.last) note += 12;
      close.add(note);
    }
    final drop2 = [close[2] - 12, close[0], close[1], close[3]];
    final drop3 = [close[1] - 12, close[0], close[2], close[3]];
    for (final (shape, sets) in [(drop2, _drop2Sets), (drop3, _drop3Sets)]) {
      shape.sort();
      for (final strings in sets) {
        for (var octave = -2; octave <= 6; octave++) {
          final notes = [for (final n in shape) n + 12 * octave];
          final frets = [
            for (var i = 0; i < 4; i++) notes[i] - guitarTuning[strings[i]],
          ];
          if (frets.any((f) => f < 1 || f > 14)) continue;
          final span = frets.reduce(math.max) - frets.reduce(math.min);
          if (span > 3) continue;
          // Nothing above the D on the 10th fret of the top string: higher
          // than that a comping guitar turns thin and bright.
          if (notes.last > guitarCompTop) continue;
          shapes[notes.join(',')] = notes;
        }
      }
    }
  }
  return shapes.values.toList();
}

class GuitarComper {
  GuitarComper(this.random)
    : _comper = Comper(
        random,
        shapes: guitarCompVoicings,
        home: guitarCompHome,
      );

  final math.Random random;

  /// The pianist's rhythmic sense and voice-leading, with guitar shapes.
  final Comper _comper;

  /// The last shape played, so the next moves as little as it can.
  List<int>? get previousVoicing => _comper.previousVoicing;
  set previousVoicing(List<int>? voicing) => _comper.previousVoicing = voicing;

  _Bar? _bar;
  int _figure = 0;
  int _riff = 0;

  List<GuitarHit> comp(
    Chord chord,
    int beats, {
    required PianoStyle style,
    required Feel groove,
    required double beatInBar,
    required int bar,
    Chord? next,
    int tempo = 120,
    CompFigure? figure,
    int beatsPerBar = 4,
    bool startsSection = false,
    bool intoSection = false,
    required double swing,
  }) {
    if (style == PianoStyle.swing) {
      // Swing: the comper's own rhythms, played as quick downstrokes.
      return [
        for (final hit in _comper.comp(
          chord,
          beats,
          Feel.swing,
          next: next,
          figure: figure,
          beatInBar: beatInBar,
          beatsPerBar: beatsPerBar,
          startsSection: startsSection,
          intoSection: intoSection,
          swing: swing,
        ))
          (
            beat: hit.beat,
            length: hit.length,
            velocity: hit.velocity,
            notes: hit.notes,
            strum: Strum.down,
          ),
      ];
    }

    // A new bar picks its rhythm; two chords sharing it share the rhythm.
    if (beatInBar == 0 || _bar == null) {
      _bar = _barFor(style, groove, bar, tempo);
    }
    final voicing = _comper.voice(chord, next);
    if (voicing.isEmpty) return const [];
    final notes = switch (style) {
      PianoStyle.straight when groove == Feel.funk => voicing.sublist(
        voicing.length - 3,
      ), // small, high shapes
      // La pompe is played on small grips, three or four strings of it.
      // There is a bassist for the bottom, and a chop that has to be in
      // and out inside a fraction of a beat cannot be six strings wide:
      // the low ones arrive late and the chord blurs where it should
      // crack.
      PianoStyle.laPompe => voicing.sublist(math.max(0, voicing.length - 4)),
      _ => voicing,
    };

    if (style == PianoStyle.held) {
      return [
        (
          beat: 0,
          length: beats - 0.05,
          velocity: 0.7,
          notes: notes,
          strum: Strum.down,
        ),
      ];
    }
    final end = beatInBar + beats;
    return [
      for (final (beat, length, velocity, strum) in _bar!)
        if (beat >= beatInBar && beat < end)
          (
            beat: beat - beatInBar,
            // Never ringing into the next chord.
            length: math.min(length, end - beat - 0.05),
            velocity: velocity * (0.9 + random.nextDouble() * 0.1),
            notes: strum == Strum.up
                ? notes.sublist(1) // an upstroke catches the top strings
                : notes,
            strum: strum,
          ),
    ];
  }

  /// The bossa guitar's two-bar figures, in beats: (bar one, bar two).
  static const _bossaFigures = [
    // With the clave: 1, the "and" of 2, 4 | 2, the "and" of 3.
    ([0.0, 1.5, 3.0], [1.0, 2.5]),
    // Anticipating: 1, the "and" of 2, the "and" of 3 | the "and" of 1,
    // 3, the "and" of 4 (into the next bar).
    ([0.0, 1.5, 2.5], [0.5, 2.0, 3.5]),
    // João Gilberto's lilt: 1, the "and" of 1, the "and" of 2, the "and"
    // of 3 | the "and" of 1, 2, the "and" of 3.
    ([0.0, 0.5, 1.5, 2.5], [0.5, 1.0, 2.5]),
  ];

  _Bar _barFor(PianoStyle style, Feel groove, int bar, int tempo) {
    switch (style) {
      case PianoStyle.calypso:
        return random.nextDouble() < 0.6
            ? [
                (0, 0.35, 0.72, Strum.down),
                (1, 0.35, 0.55, Strum.down),
                (1.5, 0.45, 0.8, Strum.up),
                (2.5, 0.4, 0.75, Strum.up),
                (3, 0.35, 0.6, Strum.down),
                (3.5, 0.45, 0.8, Strum.up),
              ]
            : [
                (0, 0.35, 0.72, Strum.down),
                (1.5, 0.8, 0.8, Strum.up),
                (2.5, 0.4, 0.75, Strum.up),
                (3.5, 0.45, 0.8, Strum.up),
              ];
      case PianoStyle.laPompe:
        // "The pump": four downstrokes a bar, all of them short, with 2
        // and 4 the ones that carry. The accent comes from the arm
        // dropping rather than from a harder pick, and the left hand
        // mutes straight after the stroke, which is where the drum-like
        // sound comes from and why the lengths here are so short.
        //
        // The quick upstroke that lifts into 1 and 3 is a grace note,
        // and a grace note is a length of time rather than a fraction of
        // a beat: it is "played very quickly no matter what the tempo
        // is". So it is twenty-five milliseconds before the stroke it
        // leads to, worked back into beats at this tempo. Written as a
        // fixed fraction of a beat it dragged further and further off
        // the beat as the tempo came down, which is the sound of a
        // player who is not quite with it.
        //
        // The lift into beat 1 belongs to the bar before, which is where
        // it sounds, so each bar carries the one into the next.
        final grace = 0.025 * tempo / 60;
        return [
          (0, 0.22, 0.62, Strum.down),
          (1, 0.3, 0.85, Strum.down),
          (2 - grace, 0.08, 0.28, Strum.up),
          (2, 0.22, 0.62, Strum.down),
          (3, 0.3, 0.85, Strum.down),
          (4 - grace, 0.08, 0.28, Strum.up),
        ];
      case PianoStyle.held || PianoStyle.swing:
        return const [];
      case PianoStyle.straight when groove == Feel.funk && tempo < 95:
        // Soul: the backbeat, with a pickup into the next bar now and then.
        return [
          (1, 0.45, 0.72, Strum.down),
          (3, 0.45, 0.72, Strum.down),
          if (random.nextDouble() < 0.3) (3.5, 0.3, 0.5, Strum.up),
        ];
      case PianoStyle.straight when groove == Feel.funk:
        // Chops on the sixteenths, heavier on 2 and 4; the same riff for a
        // four-bar phrase, then perhaps another.
        const figures = [
          [0.0, 0.75, 1.0, 1.75, 2.5, 3.0, 3.75],
          [0.25, 1.0, 1.5, 2.25, 3.0, 3.5],
          [0.0, 1.0, 1.25, 2.0, 2.75, 3.0],
        ];
        if (bar % 4 == 0 && random.nextDouble() < 0.4) {
          _riff = random.nextInt(figures.length);
        }
        return [
          for (final beat in figures[_riff])
            (
              beat,
              0.14,
              beat == 1 || beat == 3 ? 0.8 : 0.55,
              beat % 0.5 == 0 ? Strum.down : Strum.up,
            ),
        ];
      case PianoStyle.straight:
        // A new figure every two bars, favouring the plain clave.
        if (bar.isEven) {
          final roll = random.nextDouble();
          _figure = roll < 0.5 ? 0 : (roll < 0.8 ? 1 : 2);
        }
        final (first, second) = _bossaFigures[_figure];
        return [
          for (final beat in bar.isEven ? first : second)
            (beat, 0.9, beat == 0 ? 0.58 : 0.5, Strum.together),
        ];
    }
  }
}
