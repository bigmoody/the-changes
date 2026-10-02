// Colouring the chords, for people who already see them in colour.
//
// Chromesthesia is not one shared palette. Two synaesthetes who both see D
// as a colour rarely see the same colour, and the mapping is stable for
// life in the person who has it. So there is no scheme to choose from
// here: twelve roots, and you say what each one looks like. A palette we
// invented would be exactly as useless to somebody with this as no colour
// at all, and more annoying.
//
// It is keyed by pitch class rather than by chord quality, because that is
// what the colour belongs to. A D7 and a Dm9 are both D.
//
// Enharmonics share a colour by default: C♯ and D♭ are one pitch and one
// entry. That is the honest starting point, because twelve is what most
// people have and seventeen would be a lot to fill in to find out.
//
// It did turn out to matter, though, so there is a second map. Plenty of
// synaesthetes see C♯ and D♭ apart, because what they are seeing is
// attached to the written letter as much as to the sound. So a colour can
// be set against a spelling, and that one wins where it is set; anything
// not set falls back to the pitch underneath, which means turning the
// split on never blanks a chart and turning it off never loses the work.

import 'package:flutter/painting.dart';

import '../music/chord.dart';

/// The twelve roots, as somebody choosing colours would read them.
const pitchClassNames = [
  'C',
  'C♯ / D♭',
  'D',
  'D♯ / E♭',
  'E',
  'F',
  'F♯ / G♭',
  'G',
  'G♯ / A♭',
  'A',
  'A♯ / B♭',
  'B',
];

/// What colour each root is, for the person using the app.
///
/// Empty is the usual case: nobody is given a colour they did not choose.
class ChordColours {
  const ChordColours([
    this.byPitchClass = const {},
    this.bySpelling = const {},
  ]);

  /// Pitch class (0 = C) to the colour it looks like.
  final Map<int, Color> byPitchClass;

  /// A written note to the colour it looks like, where that differs from
  /// the colour of the pitch under it. Only the accidentals are ever in
  /// here: a natural has one spelling and lives in [byPitchClass].
  final Map<Spelling, Color> bySpelling;

  bool get isEmpty => byPitchClass.isEmpty && bySpelling.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// How many colours somebody has actually chosen, counted the way they
  /// would count them: every answer they gave, split or not.
  int get chosen => byPitchClass.length + bySpelling.length;

  Color? of(int pitchClass) => byPitchClass[pitchClass % 12];

  /// The colour of a pitch that was heard rather than read.
  ///
  /// Somebody keeping their sharps and flats apart may never have
  /// answered for the pitch itself, only for its two spellings. The tuner
  /// still has to draw that pitch in something, so it borrows from a
  /// spelling of it: the sharp first, because a tuner that shows one name
  /// shows the sharp. Only when the split is on, or turning it off would
  /// leak colours somebody had put away.
  Color? ofPitch(int pitchClass, {bool split = true}) {
    if (of(pitchClass) case final theirs?) return theirs;
    if (!split) return null;
    for (final note in accidentalSpellings) {
      if (pitchClassOf(note) == pitchClass % 12) {
        if (bySpelling[note] case final theirs?) return theirs;
      }
    }
    return null;
  }

  /// The colour of a written note.
  ///
  /// [split] is whether sharps and flats are being kept apart. With it
  /// off the spellings are left where they are rather than thrown away,
  /// so the switch can go back and forth without costing anybody their
  /// answers.
  Color? ofSpelling(Spelling note, {bool split = true}) {
    if (split) {
      if (bySpelling[note] case final theirs?) return theirs;
    }
    return of(pitchClassOf(note));
  }

  /// The same again with [pitchClass] set to [colour], or cleared when
  /// that is null.
  ChordColours set(int pitchClass, Color? colour) {
    final out = {...byPitchClass};
    if (colour == null) {
      out.remove(pitchClass % 12);
    } else {
      out[pitchClass % 12] = colour;
    }
    return ChordColours(out, bySpelling);
  }

  /// The same again with one written note set to [colour], or cleared.
  ChordColours setSpelling(Spelling note, Color? colour) {
    final out = {...bySpelling};
    if (colour == null) {
      out.remove(note);
    } else {
      out[note] = colour;
    }
    return ChordColours(byPitchClass, out);
  }

  /// One flat map, with pitch classes under their number and spellings
  /// under their name. The two cannot collide, and anything saved before
  /// the spellings existed still reads back exactly as it did.
  Map<String, int> toJson() => {
    for (final entry in byPitchClass.entries)
      '${entry.key}': entry.value.toARGB32(),
    for (final entry in bySpelling.entries)
      noteNameOf(entry.key): entry.value.toARGB32(),
  };

  static ChordColours fromJson(Map<String, Object?> json) => ChordColours(
    {
      for (final entry in json.entries)
        if (int.tryParse(entry.key) case final pitch?
            when pitch >= 0 && pitch < 12)
          if (entry.value case final int argb) pitch: Color(argb),
    },
    {
      for (final entry in json.entries)
        if (int.tryParse(entry.key) == null)
          if (parseNoteName(entry.key) case final note?)
            if (entry.value case final int argb) note: Color(argb),
    },
  );
}

/// The ten written accidentals, in the order somebody reading a keyboard
/// would meet them. Naturals are not here: they have one spelling each and
/// are already answered by their pitch class.
const accidentalSpellings = <Spelling>[
  (letter: 0, accidental: 1), // C♯
  (letter: 1, accidental: -1), // D♭
  (letter: 1, accidental: 1), // D♯
  (letter: 2, accidental: -1), // E♭
  (letter: 3, accidental: 1), // F♯
  (letter: 4, accidental: -1), // G♭
  (letter: 4, accidental: 1), // G♯
  (letter: 5, accidental: -1), // A♭
  (letter: 5, accidental: 1), // A♯
  (letter: 6, accidental: -1), // B♭
];

/// How bright a colour is to the eye, 0 to 1.
///
/// The usual weighting: the eye is far more sensitive to green than to
/// blue, so a saturated blue is much darker than it looks like it should
/// be, which is exactly the case that goes invisible on dark paper.
double luminanceOf(Color colour) => colour.computeLuminance();

/// [colour], lifted or dropped only as far as it has to be to be read
/// against [background].
///
/// The hue and the saturation are left alone, because they are the part
/// somebody actually sees: a deep blue D stays a blue D. Only its
/// lightness moves, and only when it would otherwise be unreadable, which
/// in practice means dark colours on the dark theme and pale ones on the
/// paper.
///
/// A chart nobody can read is not a kindness to anybody, and brightness
/// shifting with the light is something every colour does anyway.
Color readableOn(Color colour, Color background, {double leastContrast = 3}) {
  if (_contrast(colour, background) >= leastContrast) return colour;
  final hsl = HSLColor.fromColor(colour);
  final darkBackground = background.computeLuminance() < 0.5;
  // Walk the lightness towards whichever end of the range helps, and stop
  // the moment it is readable rather than going all the way.
  for (var step = 1; step <= 20; step++) {
    final lightness =
        (darkBackground
                ? hsl.lightness + step * 0.04
                : hsl.lightness - step * 0.04)
            .clamp(0.0, 1.0);
    final moved = hsl.withLightness(lightness).toColor();
    if (_contrast(moved, background) >= leastContrast) return moved;
    if (lightness == 0 || lightness == 1) break;
  }
  // Nothing in that hue reads against this background, which happens for
  // a mid grey on a mid grey. Black or white is better than invisible.
  return darkBackground ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
}

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05));
}
