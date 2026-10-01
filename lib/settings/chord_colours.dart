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
// Enharmonics share a colour: C♯ and D♭ are one pitch and one entry. Some
// people do see those two apart, and if that turns out to matter it is a
// second map rather than a different idea, but twelve is the honest
// default and twenty-one would be a lot to fill in to find out.

import 'package:flutter/painting.dart';

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
  const ChordColours([this.byPitchClass = const {}]);

  /// Pitch class (0 = C) to the colour it looks like.
  final Map<int, Color> byPitchClass;

  bool get isEmpty => byPitchClass.isEmpty;
  bool get isNotEmpty => byPitchClass.isNotEmpty;

  Color? of(int pitchClass) => byPitchClass[pitchClass % 12];

  /// The same again with [pitchClass] set to [colour], or cleared when
  /// that is null.
  ChordColours set(int pitchClass, Color? colour) {
    final out = {...byPitchClass};
    if (colour == null) {
      out.remove(pitchClass % 12);
    } else {
      out[pitchClass % 12] = colour;
    }
    return ChordColours(out);
  }

  Map<String, int> toJson() => {
    for (final entry in byPitchClass.entries)
      '${entry.key}': entry.value.toARGB32(),
  };

  static ChordColours fromJson(Map<String, Object?> json) => ChordColours({
    for (final entry in json.entries)
      if (int.tryParse(entry.key) case final pitch?
          when pitch >= 0 && pitch < 12)
        if (entry.value case final int argb) pitch: Color(argb),
  });
}

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
