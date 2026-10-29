// Where each mode is heard: a tune in the library and the bar where the
// mode is the sound, or a song most people already know.
//
// A mode is remembered by a sound, not by a list of degrees. "Dorian has a
// natural 6th" is forgotten by Thursday; "Dorian is So What" is not. Every
// bar named here is checked against the app's own chart of the tune (see
// mode_examples_test.dart), so tapping one plays the place it describes.

/// One place a mode is heard.
class ModeExample {
  const ModeExample(this.text, {this.tune});

  /// What to listen for, and where.
  final String text;

  /// The tune in the library it is heard in, to play with the band. Null
  /// for a song that is not a jazz standard.
  final String? tune;
}

/// The examples for each mode, by its name in `modes`.
const modeExamples = <String, List<ModeExample>>{
  'Ionian': [
    ModeExample(
      'The C6 that opens it: the plain major sound of home.',
      tune: 'Take the "A" Train',
    ),
    ModeExample(
      'Joy to the World: the first line is the major scale straight down.',
    ),
    ModeExample('Do-Re-Mi, from The Sound of Music: the scale, with words.'),
  ],
  'Dorian': [
    ModeExample(
      'D Dorian for sixteen bars, then E♭ Dorian for the bridge.',
      tune: 'So What',
    ),
    ModeExample('The same form as So What, at a gallop.', tune: 'Impressions'),
    ModeExample(
      'Am7 to D7 and back, and both are A Dorian: the F♯ in the D7 is '
      "Dorian's natural 6th.",
      tune: 'Oye Como Va',
    ),
    ModeExample(
      'Scarborough Fair: the natural 6th is what makes it sound old rather '
      'than sad.',
    ),
  ],
  'Phrygian': [
    ModeExample(
      'Bars 1 and 2: E minor sliding up to FΔ7. That F is the ♭2 of E '
      'Phrygian.',
      tune: 'Nardis',
    ),
    ModeExample(
      'Flamenco: A minor, G, F, E, coming down the guitar, lands on E '
      'Phrygian.',
    ),
  ],
  'Lydian': [
    ModeExample(
      'The FΔ7 in bar 2. The tune is in E minor, so the B is natural, and '
      'F with a B natural is F Lydian.',
      tune: 'Nardis',
    ),
    ModeExample(
      'The FΔ7 that opens the bridge, in a C major tune: F Lydian again.',
      tune: 'Take the "A" Train',
    ),
    ModeExample("Joe Satriani's Flying in a Blue Dream, built on the ♯4."),
  ],
  'Mixolydian': [
    ModeExample(
      'Every chord of a blues is a dominant 7th, and Mixolydian fits each '
      'one.',
      tune: 'Freddie Freeloader',
    ),
    ModeExample(
      'Norwegian Wood, by The Beatles: a major tune with a ♭7 in the melody.',
    ),
    ModeExample('Sweet Home Alabama: D, C, G round and round is D Mixolydian.'),
  ],
  'Aeolian': [
    ModeExample(
      'The vi chord of any major key: Am7 in C is A Aeolian, all white '
      'notes. (Not the ii or the iv of a minor key: those are Dorian.)',
    ),
    ModeExample(
      'All Along the Watchtower: C♯m, B, A, round and round, is C♯ Aeolian.',
    ),
  ],
  'Locrian': [
    ModeExample(
      'The Dø7 in bar 5, the ii of a minor ii–V–i into C minor.',
      tune: 'Blue Bossa',
    ),
    ModeExample(
      'Hardly any song lives in Locrian: it is a scale for one chord, not a '
      'key.',
    ),
  ],
  'Melodic minor': [
    ModeExample(
      'Bar 2: C minor with a B natural under it. That B is melodic '
      "minor's natural 7th.",
      tune: 'My Funny Valentine',
    ),
    ModeExample(
      'It opens on CmΔ7 for two bars: C melodic minor.',
      tune: 'Solar',
    ),
    ModeExample(
      'The Cm6 at the end of the first eight bars: melodic minor has the '
      'natural 6th the chord asks for.',
      tune: 'Blue Bossa',
    ),
  ],
  'Dorian ♭2': [
    ModeExample(
      'The E♭7sus4 bars of the bridge, played darker: E♭ Dorian ♭2 makes '
      'them sus♭9.',
      tune: 'Maiden Voyage',
    ),
  ],
  'Lydian augmented': [
    ModeExample(
      'Over a Δ7♯5, which stands in for a plain Δ7 when the melody has the '
      '♯5. In C melodic minor it starts on E♭: E♭Δ7♯5.',
    ),
  ],
  'Lydian dominant': [
    ModeExample(
      'Bars 3 and 4, D7♯11: the chord names the ♯11 for you.',
      tune: 'Take the "A" Train',
    ),
    ModeExample(
      'The G7 in bars 3 and 4, a II7 in F: the ♯11 (C♯) is the colour that '
      'fits.',
      tune: 'The Girl from Ipanema',
    ),
    ModeExample('The F7♯11 in bar 9.', tune: 'Footprints'),
  ],
  'Mixolydian ♭6': [
    ModeExample(
      'The D7 in the second bar of the B section, going to Gm6: a dominant '
      'heading '
      'for a minor chord, so its 13th comes down to a ♭13.',
      tune: 'Autumn Leaves',
    ),
  ],
  'Locrian ♮2': [
    ModeExample(
      'The Eø7 of bar 1. The natural 2nd (F♯) softens Locrian\'s ♭2, which '
      'sits awkwardly on the chord.',
      tune: 'Stella by Starlight',
    ),
  ],
  'Altered': [
    ModeExample('The F♯7alt in bar 7.', tune: 'Wave'),
    ModeExample(
      'E7♯9 to A7♯9 in bar 10: two altered dominants a fourth apart.',
      tune: 'Footprints',
    ),
  ],
  'Harmonic minor': [
    ModeExample(
      'Bø7, E7♭9, Am7: the minor ii–V–i that runs all through it comes from '
      'A harmonic minor.',
      tune: 'Summertime',
    ),
  ],
  'Locrian ♮6': [
    ModeExample(
      'The Bø7: B to B in A harmonic minor, the key the tune lives in.',
      tune: 'Summertime',
    ),
  ],
  'Ionian ♯5': [
    ModeExample(
      'Mode 3 of harmonic minor. In A harmonic minor it runs C to C, over '
      'a CΔ7♯5 on the way back to A minor.',
    ),
  ],
  'Dorian ♯4': [
    ModeExample(
      'The Dm7 in bar 5, if you stay in A harmonic minor: D Dorian with a '
      'G♯.',
      tune: 'Summertime',
    ),
  ],
  'Phrygian dominant': [
    ModeExample(
      'The G7♭9 in bar 6, going home to C minor.',
      tune: 'Blue Bossa',
    ),
    ModeExample(
      'Every E7♭9, each one heading for A minor.',
      tune: 'Summertime',
    ),
    ModeExample('Hava Nagila: the sound of a great deal of klezmer.'),
  ],
  'Lydian ♯2': [
    ModeExample(
      'Mode 6 of harmonic minor. In A harmonic minor it runs F to F: over '
      'an FΔ7 in an A minor tune, with a G♯ for colour.',
    ),
  ],
  'Ultralocrian': [
    ModeExample(
      'Mode 7 of harmonic minor: the G♯o7 that leads up into A minor.',
    ),
  ],
  'Whole tone': [
    ModeExample('The G7♯5 in bars 17 and 18.', tune: 'Stella by Starlight'),
    ModeExample(
      "Debussy's Voiles, and Thelonious Monk, who ran whole-tone scales down "
      'the piano.',
    ),
  ],
  'Half-whole diminished': [
    ModeExample(
      'The D7♭9 that ends the second eight bars.',
      tune: 'Stella by Starlight',
    ),
  ],
  'Whole-half diminished': [
    ModeExample('The B♭o7 in bar 2.', tune: 'Wave'),
    ModeExample(
      'The F♯o7 in the B section, climbing from FΔ7 to G7.',
      tune: 'St. Thomas',
    ),
  ],
  'Major pentatonic': [
    ModeExample(
      'Over the C6 bars: none of the five notes can clash.',
      tune: 'Take the "A" Train',
    ),
    ModeExample('Amazing Grace: the tune uses these five notes and no others.'),
  ],
  'Minor pentatonic': [
    ModeExample('The Fm7 bars: F minor pentatonic.', tune: 'Cantaloupe Island'),
    ModeExample('Where most blues and rock guitar solos start.'),
  ],
  'Blues scale': [
    ModeExample(
      'Any blues, and this one more than most.',
      tune: 'Tenor Madness',
    ),
    ModeExample(
      'The riff of Sunshine of Your Love, by Cream: D blues scale, ♭5 and '
      'all.',
    ),
  ],
  'Dominant pentatonic': [
    ModeExample(
      'Every chord of it, the same five notes moved to each root.',
      tune: 'Freddie Freeloader',
    ),
  ],
};
