// Bebop scales: seven-note scales with an eighth note put in, so that the
// chord tones land on the beat.
//
// This is the most mechanical thing in bebop and the least mysterious. A
// major scale has seven notes. Run it in quavers from the root and after
// one bar you have played eight of them, so the next bar starts on the 2nd,
// and from there the notes falling on the beats are whatever happens to
// land there. Put one extra note in and the scale is eight long, a bar of
// quavers is exactly one octave, and every beat of every bar lands on a
// chord tone for as long as you care to keep going.
//
// That is the whole trick, and it is why bebop lines can run for four bars
// of unbroken quavers and still sound like the chords rather than like a
// scale. The passing note is not decoration: it is the thing that keeps
// everything else in place.
//
// Where the extra note goes is not a matter of taste either. It goes where
// it makes the chord tones come out on the beats, which means next to the
// note it is passing between, sharing its letter: B♭ and B♮ in a dominant
// scale, not B♭ and C♭.

import 'chord.dart';

/// A seven-note scale with its passing note, and the chord it is for.
class BebopScale {
  const BebopScale({
    required this.name,
    required this.short,
    required this.quality,
    required this.plain,
    required this.plainName,
    required this.degrees,
    required this.added,
    required this.tones,
    required this.about,
  });

  final String name;

  /// For the chip. All three names end in "Bebop" and the screen is
  /// already called that, so the three of them fit across a phone.
  final String short;

  /// The chord quality it is played over, as the app writes it.
  final String quality;

  /// The seven-note scale it is built from, and what that is called.
  final List<String> plain;
  final String plainName;

  /// All eight, from the root up.
  final List<String> degrees;

  /// The one that was put in.
  final String added;

  /// The chord tones: what lands on the beat when it works.
  final List<String> tones;

  final String about;

  /// Where [added] sits in [degrees].
  int get addedAt => degrees.indexOf(added);
}

const bebopScales = <BebopScale>[
  BebopScale(
    name: 'Dominant Bebop',
    short: 'Dominant',
    quality: '7',
    plainName: 'Mixolydian',
    plain: ['1', '2', '3', '4', '5', '6', 'b7'],
    degrees: ['1', '2', '3', '4', '5', '6', 'b7', '7'],
    added: '7',
    tones: ['1', '3', '5', 'b7'],
    about:
        'The natural 7th goes in above the ♭7, so the scale climbs '
        'B♭–B–C into the root. This is the one to learn first: it is for '
        'the V chord, and the V chord is where most of the trouble is.',
  ),
  BebopScale(
    name: 'Major Bebop',
    short: 'Major',
    quality: '6',
    plainName: 'Ionian',
    plain: ['1', '2', '3', '4', '5', '6', '7'],
    degrees: ['1', '2', '3', '4', '5', '#5', '6', '7'],
    added: '#5',
    tones: ['1', '3', '5', '6'],
    about:
        'The passing note sits between the 5th and the 6th, which lands '
        'the 6th on a beat rather than the 7th, so this one belongs to '
        'the 6th chord, and that is why a major tune so often wants a 6 '
        'where you expected a Δ7. Written as a ♯5 going up and a ♭6 '
        'coming down.',
  ),
  BebopScale(
    name: 'Minor Bebop',
    short: 'Minor',
    quality: 'm7',
    plainName: 'Dorian',
    plain: ['1', '2', 'b3', '4', '5', '6', 'b7'],
    degrees: ['1', '2', 'b3', '4', '5', '6', 'b7', '7'],
    added: '7',
    tones: ['1', 'b3', '5', 'b7'],
    about:
        'Dorian with a natural 7th put in on top, the same place the '
        'dominant scale takes it, which makes sense, since a ii and the V '
        'after it are the same seven notes. You will also see a minor '
        'bebop scale with a ♮3 wedged above the ♭3: a good sound, but it '
        'does not keep the chord tones on the beat from the root, so it is '
        'not the one to learn this from.',
  ),
];

/// One note of a run: which degree it is, whether it falls on a beat, and
/// whether it is a chord tone.
typedef RunNote = ({String degree, bool onBeat, bool isTone});

/// [scale] run as quavers from the root for [bars] bars of four.
///
/// Eight quavers to a bar, so the notes on the beats are the even ones.
/// Nothing here knows or cares how long the scale is: that is the point,
/// and it is why an eight-note scale comes out differently from a seven.
List<RunNote> runOf(List<String> degrees, Set<String> tones, {int bars = 2}) =>
    [
      for (var i = 0; i < bars * 8; i++)
        (
          degree: degrees[i % degrees.length],
          onBeat: i.isEven,
          isTone: tones.contains(degrees[i % degrees.length]),
        ),
    ];

/// How many beats of the run land on a chord tone, out of [bars] × 4.
int tonesOnBeats(List<String> degrees, Set<String> tones, {int bars = 2}) =>
    runOf(
      degrees,
      tones,
      bars: bars,
    ).where((note) => note.onBeat && note.isTone).length;

/// The scale spelled from [root], one name per degree.
///
/// The passing note shares a letter with the note it passes (B♭ then B♮,
/// not B♭ then C♭), which falls out of spelling each degree by its number.
List<String> spell(List<String> degrees, String root, String quality) {
  final chord = Chord.parse('$root$quality');
  return [for (final degree in degrees) chord.noteFor(degree)];
}

/// Semitones above the root for each degree.
List<int> semitonesOf(List<String> degrees) => [
  for (final degree in degrees) degreeToSemitones(degree),
];
