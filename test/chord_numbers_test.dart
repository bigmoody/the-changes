import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/chord_numbers.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/music/user_progression.dart';

List<String> _roman(String chords, String key) => [
  for (final symbol in chords.split(' ')) romanFor(Chord.parse(symbol), key),
];

List<String> _nashville(String chords, String key) => [
  for (final symbol in chords.split(' '))
    nashvilleFor(Chord.parse(symbol), key),
];

void main() {
  test('a ii–V–I is the same three numbers in every major key', () {
    for (final (key, chords) in const [
      ('C', 'Dm7 G7 CΔ7'),
      ('F', 'Gm7 C7 FΔ7'),
      ('B♭', 'Cm7 F7 BbΔ7'),
      ('E♭', 'Fm7 Bb7 EbΔ7'),
      ('E', 'F#m7 B7 EΔ7'),
      ('D♭', 'Ebm7 Ab7 DbΔ7'),
    ]) {
      expect(_roman(chords, key), ['ii7', 'V7', 'IΔ7'], reason: key);
      expect(_nashville(chords, key), ['2-7', '5', '1Δ7'], reason: key);
    }
  });

  test('a minor ii–V–i keeps the flat five and the flat nine', () {
    // The ii of a minor key is half-diminished and its V has a ♭9; both are
    // worth seeing, so the suffix keeps them. The minus is left off 2ø7
    // because the ø has already said the chord is minor-sounding.
    expect(_roman('Dø7 G7b9 Cm6', 'C minor'), ['iiø7', 'V7♭9', 'i6']);
    expect(_nashville('Dø7 G7b9 Cm6', 'C minor'), ['2ø7', '5♭9', '1-6']);
    // The same turn in another minor key, and on to a minor 7th home chord.
    expect(_roman('Aø7 D7b9 Gm7', 'G minor'), ['iiø7', 'V7♭9', 'i7']);
    expect(_nashville('Aø7 D7b9 Gm7', 'G minor'), ['2ø7', '5♭9', '1-7']);
  });

  test('a minor key counts from the natural minor scale', () {
    // In C minor the E♭, A♭ and B♭ are the notes of the key, so they are
    // the 3, 6 and 7 with nothing in front of them — the way a player says
    // "the flat six" only when a chord is outside the key.
    expect(_roman('EbΔ7 Ab7 Bb7 Dm7', 'C minor'), [
      'IIIΔ7',
      'VI7',
      'VII7',
      'ii7',
    ]);
    // A note raised out of the natural minor is marked sharp, not natural:
    // in C minor an E major chord is ♯III and the leading-tone diminished
    // chord is ♯vii°7. The accidental always means "this far from the
    // reference scale", which also shows which note has been raised.
    expect(_roman('E7 Bo7 A7', 'C minor'), ['♯III7', '♯vii°7', '♯VI7']);
    expect(_nashville('E7 Bo7 A7', 'C minor'), ['♯3', '♯7°7', '♯6']);
  });

  test('chromatic chords are named the way players name them', () {
    // A tritone sub is the flat two; a secondary dominant on the sixth is
    // still the sixth; and the chord a tritone from home is the sharp four,
    // which is what players call it.
    expect(romanFor(Chord.parse('Db7'), 'C'), '♭II7');
    expect(romanFor(Chord.parse('A7'), 'C'), 'VI7');
    expect(romanFor(Chord.parse('F#h7'), 'C'), '♯ivø7');
    // The same sound spelled the other way reads the same: a chord a tritone
    // from home is the ♯iv whether the chart wrote F♯ or G♭, because the
    // spelling of a root is chosen for the player's fingers, not for the
    // analysis.
    expect(romanFor(Chord.parse('Gbh7'), 'C'), '♯ivø7');
    expect(romanFor(Chord.parse('Bb7'), 'C'), '♭VII7');
    expect(romanFor(Chord.parse('Ebo7'), 'C'), '♭iii°7');
    expect(_nashville('Db7 A7 F#h7 Bb7', 'C'), ['♭2', '6', '♯4ø7', '♭7']);
  });

  test('a chord from outside the key is named by its sound', () {
    // All the Things You Are is in A♭ and its bridge is written EΔ7, because
    // no one wants to read F♭Δ7. Counting letters would call that ♯VΔ7, and
    // every player calls it the flat six.
    expect(romanFor(Chord.parse('EΔ7'), 'A♭'), '♭VIΔ7');
    // Cherokee's bridge, the same way: it goes up a semitone to ♭II, which
    // is how a player describes it, rather than down from ♯I.
    expect(_roman('C#m7 F#7 BΔ7', 'B♭'), ['♭iii7', '♭VI7', '♭IIΔ7']);
    // And nothing ever needs two accidentals: counted by letter a D♭ in B
    // major would be ♭♭III, and it simply sounds like the 2.
    expect(romanFor(Chord.parse('Db'), 'B'), 'II');
    // Same again in A, where a G♭ would count as ♭♭7 and sounds like the 6th.
    expect(romanFor(Chord.parse('Gb7'), 'A'), 'VI7');
  });

  test('a diminished chord keeps the spelling that says where it goes', () {
    // Donna Lee, in A♭: the B°7 climbs into the Cm7, so it is the sharpened
    // second and the reading says so. A diminished chord is the one kind
    // read exactly as the chart spells it, because the spelling is what
    // says where it is going: the very same four notes written D°7 are on
    // their way somewhere else and read as the sharpened fourth.
    expect(_roman('Bo7 Cm7', 'A♭'), ['♯ii°7', 'iii7']);
    expect(romanFor(Chord.parse('Do7'), 'A♭'), '♯iv°7');
    // A jazz blues' ♯iv°7, in both of the keys it is usually played in.
    expect(romanFor(Chord.parse('Bo7'), 'F'), '♯iv°7');
    expect(romanFor(Chord.parse('Eo7'), 'B♭'), '♯iv°7');
  });

  test('the case of the numeral follows the chord, not the key', () {
    // Lower case for the minor-sounding chords — anything with a ♭3 — and
    // upper case for the rest, including a sus chord, which has no 3rd at
    // all but functions as a dominant.
    expect(_roman('C CΔ7 C7 C7sus4 Csus4 C+', 'C'), [
      'I',
      'IΔ7',
      'I7',
      'I7sus4',
      'Isus4',
      'I+',
    ]);
    expect(_roman('Cm Cm7 Cm6 CmΔ7 Ch7 Co7 Co', 'C'), [
      'i',
      'i7',
      'i6',
      'iΔ7',
      'iø7',
      'i°7',
      'i°',
    ]);
  });

  test('a chord written several ways reads as one numeral', () {
    for (final symbol in ['Dm7', 'D-7', 'Dmin7']) {
      expect(romanFor(Chord.parse(symbol), 'C'), 'ii7', reason: symbol);
    }
    for (final symbol in ['CΔ7', 'C^7', 'Cmaj7', 'CM7']) {
      expect(romanFor(Chord.parse(symbol), 'C'), 'IΔ7', reason: symbol);
    }
    for (final symbol in ['Dø7', 'Dm7b5', 'D-7b5']) {
      expect(romanFor(Chord.parse(symbol), 'C'), 'iiø7', reason: symbol);
    }
  });

  test('a slash bass is shown as the degree it is', () {
    expect(romanFor(Chord.parse('C/E'), 'C'), 'I/3');
    expect(nashvilleFor(Chord.parse('C/E'), 'C'), '1/3');
    expect(romanFor(Chord.parse('Dm7/G'), 'C'), 'ii7/5');
    expect(nashvilleFor(Chord.parse('Dm7/G'), 'C'), '2-7/5');
    expect(romanFor(Chord.parse('BbΔ7/D'), 'B♭'), 'IΔ7/3');
    // A bass note outside the key gets its accidental like any degree.
    expect(romanFor(Chord.parse('C/Ab'), 'C'), 'I/♭6');
    // A slash that only names the root again isn't worth showing.
    expect(romanFor(Chord.parse('C7/C'), 'C'), 'I7');
  });

  test('Dorian keys count as minor, so the vamp starts at home', () {
    // So What's Dm7 is the i chord of D Dorian, not the ii of C.
    expect(_roman('Dm7 Ebm7', 'D Dorian'), ['i7', '♭ii7']);
    expect(_nashville('Dm7 Ebm7', 'D Dorian'), ['1-7', '♭2-7']);
    // Chameleon: the 6th of Dorian is raised out of the natural minor, so
    // its IV7 reads as a plain IV rather than a flat one.
    expect(_roman('Bbm7 Eb7', 'B♭ Dorian'), ['i7', 'IV7']);
  });

  test('a Nashville blues reads the way a session player writes one', () {
    // The 7 of a dominant chord is assumed, so a blues is bare numbers.
    const blues = 'F7 Bb7 F7 F7 Bb7 Bb7 F7 F7 C7 Bb7 F7 C7';
    expect(_nashville(blues, 'F'), [
      '1', '4', '1', '1', '4', '4', '1', '1', '5', '4', '1', '5', //
    ]);
    // The Roman numerals still tell a dominant from a plain triad.
    expect(_roman('F F7 FΔ7', 'F'), ['I', 'I7', 'IΔ7']);
    expect(_nashville('F7alt F7#9 F13 F7sus4', 'F'), [
      '1alt',
      '1♯9',
      '1(13)',
      '1sus4',
    ]);
    // A suffix that is itself a number goes in brackets, since "16" would
    // read as sixteen rather than as a six chord.
    expect(_nashville('F6 F6/9 Dm6 D9', 'F'), [
      '1(6)',
      '1(6/9)',
      '6-6',
      '6(9)',
    ]);
  });

  test('standards read the way a player would call the changes', () {
    // Autumn Leaves in G minor: the whole A section is diatonic, which is
    // the point of playing it — iv–VII–III–VI–ii–V–i.
    expect(_roman('Cm7 F7 BbΔ7 EbΔ7 Aø7 D7 Gm6', 'G minor'), [
      'iv7',
      'VII7',
      'IIIΔ7',
      'VIΔ7',
      'iiø7',
      'V7',
      'i6',
    ]);
    // Blue Bossa's bridge is a ii–V–I a semitone above home.
    expect(_roman('Ebm7 Ab7 DbΔ7', 'C minor'), ['iii7', 'VI7', '♭IIΔ7']);
    // Solar, with its minor-major home chord.
    expect(_roman('CmΔ7 Gm7 C7 FΔ7', 'C minor'), ['iΔ7', 'v7', 'I7', 'IVΔ7']);
    // All of Me: a string of secondary dominants.
    expect(_roman('C6 E7 A7 Dm7 G7', 'C'), ['I6', 'III7', 'VI7', 'ii7', 'V7']);
  });

  test('every key the app offers names its own tonic chord 1', () {
    for (final key in UserProgression.keys) {
      final minor = key.contains('minor');
      final tonic = key.split(' ').first + (minor ? 'm' : '');
      final chord = Chord.parse(tonic);
      expect(romanFor(chord, key), minor ? 'i' : 'I', reason: key);
      expect(nashvilleFor(chord, key), minor ? '1-' : '1', reason: key);
    }
    expect(UserProgression.keys, hasLength(24), reason: 'all 24 keys covered');
  });

  test('every quality on every root reads in every key', () {
    // The sweep that catches an unhandled quality: no numeral may come out
    // empty, or carrying a "null" or a "?" from a lookup that missed.
    const roots = ['C', 'F#', 'Bb', 'A', 'Eb'];
    for (final key in UserProgression.keys) {
      for (final quality in chordQualities) {
        for (final root in roots) {
          final chord = Chord.parse('$root${quality.symbols.first}');
          for (final numeral in [
            romanFor(chord, key),
            nashvilleFor(chord, key),
          ]) {
            expect(
              numeral,
              matches(RegExp(r'^[♭♯]*([IVX]+|[iv]+|[1-7])')),
              reason: '${chord.display} in $key',
            );
            expect(numeral, isNot(contains('null')));
            expect(numeral, isNot(contains('?')));
          }
        }
      }
    }
  });

  test('every chord of every tune in the library reads as a number', () {
    for (final tune in [...standards, ...practiceProgressions]) {
      for (final slot in tune.slots) {
        final roman = romanFor(slot.chord, tune.key);
        final nashville = nashvilleFor(slot.chord, tune.key);
        final where = '${slot.chord.display} in ${tune.title} (${tune.key})';
        expect(roman, isNotEmpty, reason: where);
        expect(nashville, isNotEmpty, reason: where);
        expect(roman, matches(RegExp(r'^[♭♯]*[IViv]')), reason: where);
        expect(nashville, matches(RegExp(r'^[♭♯]*[1-7]')), reason: where);
        for (final numeral in [roman, nashville]) {
          expect(numeral, isNot(contains('null')), reason: where);
          expect(numeral, isNot(contains('?')), reason: where);
        }
      }
    }
  });

  test('moving a tune keeps the same functions, spelling aside', () {
    // What the numbers are for: the reading doesn't change when a singer
    // wants the tune somewhere else.
    //
    // Usually the numeral is identical, but it can't be promised to be.
    // The numeral follows how the chord is spelled on the chart, and
    // moving a tune respells any root that changes between sharps and
    // flats — about one chord in twenty-five, and ordinary dominants and
    // major 7ths as often as passing diminished ones. A Foggy Day's is a
    // G♯°7 in F and an A♭°7 in A♭, reading ♯ii°7 and ♭iii°7. Same sound,
    // same job, and the numeral matches the chord printed right above it,
    // which is what matters when the two are read together.
    var respelled = 0;
    var counted = 0;
    for (final tune in standards) {
      final moved = tune.transposed(3);
      for (var i = 0; i < tune.slots.length; i++) {
        counted++;
        final before = romanFor(tune.slots[i].chord, tune.key);
        final after = romanFor(moved.slots[i].chord, moved.key);
        if (before == after) continue;
        respelled++;
        expect(
          _soundingDegree(moved.slots[i].chord, moved.key),
          _soundingDegree(tune.slots[i].chord, tune.key),
          reason:
              '${tune.title} bar ${tune.slots[i].barIndex + 1}: '
              '$before became $after',
        );
      }
    }
    expect(
      respelled / counted,
      lessThan(0.06),
      reason: 'a respelling is the exception, not the rule',
    );
  });
}

/// How far the chord's root is above the key's tonic in semitones — what
/// the chord sounds like, whatever it's spelled as.
int _soundingDegree(Chord chord, String key) {
  final tonic = parseNoteName(
    RegExp(r'^[A-G][♭♯b#]?').stringMatch(key) ?? 'C',
  )!;
  return (chord.root - pitchClassOf(tonic) + 12) % 12;
}
