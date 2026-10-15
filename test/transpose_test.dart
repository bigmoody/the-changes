import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/tune_library.dart';

List<String> chords(dynamic tune, int bars) => [
  for (final bar in tune.bars.take(bars))
    for (final slot in bar) slot.chord.display as String,
];

void main() {
  final byTitle = {for (final tune in standards) tune.title: tune};

  test('minor keys use the key\'s own spelling', () {
    final autumn = byTitle['Autumn Leaves']!.transposed(
      -3,
    ); // G minor → E minor
    expect(autumn.key, 'E minor');
    expect(chords(autumn, 8), [
      'Am7', 'D7', 'GΔ7', 'CΔ7', 'F♯ø7', 'B7', 'Em6', 'Em6', //
    ]);
  });

  test('flat keys stay flat, and double flats are respelled', () {
    final giantSteps = byTitle['Giant Steps']!.transposed(-1); // B → B♭
    expect(giantSteps.key, 'B♭');
    // B♭7 down a semitone would be "B𝄫7"; it should read A7.
    expect(chords(giantSteps, 2), ['B♭Δ7', 'D♭7', 'G♭Δ7', 'A7']);
  });

  test('blues in B♭ up a fourth is in E♭', () {
    final freddie = byTitle['Freddie Freeloader']!.transposed(5);
    expect(freddie.key, 'E♭');
    expect(chords(freddie, 12).toSet(), {'E♭7', 'A♭7', 'B♭7', 'D♭7'});
  });

  test('transposing keeps form and bar count, and 12 semitones is a no-op', () {
    final cherokee = byTitle['Cherokee']!;
    final moved = cherokee.transposed(2);
    expect(moved.barCount, cherokee.barCount);
    expect(moved.form, cherokee.form);
    expect(moved.key, 'C');
    expect(identical(cherokee.transposed(12), cherokee), isTrue);
  });

  test('mode names in the key label are left alone', () {
    final soWhat = byTitle['So What']!;
    expect(soWhat.keyLabelBy(2), 'E Dorian');
    expect(soWhat.transposed(2).bars.first.single.chord.display, 'Em7');
    expect(byTitle['Major ii–V–I in three keys'], isNull); // not a standard
  });

  test('every standard can be moved to every key', () {
    for (final tune in standards) {
      for (var semitones = -5; semitones <= 6; semitones++) {
        final moved = tune.transposed(semitones);
        for (final slot in moved.slots) {
          expect(slot.chord.display, isNot(contains('𝄫')), reason: tune.title);
          expect(slot.chord.display, isNot(contains('𝄪')), reason: tune.title);
        }
      }
    }
  });

  test('no chord in any key is rooted on C♭, F♭, E♯, B♯, D♯ or A♯', () {
    for (final tune in [...standards, ...practiceProgressions]) {
      for (var semitones = 0; semitones < 12; semitones++) {
        for (final slot in tune.transposed(semitones).slots) {
          final symbol = slot.chord.display;
          // D♯ and A♯ among them: nobody writes a chord on either,
          // whatever its quality, and the drill deals out E♭ and B♭ for
          // major, dominant and minor alike. An E♭ part of The Girl from
          // Ipanema used to read E♭Δ7 in bar 17 and D♯m7 in bar 21, the
          // same note twice over, because the concert chart writes G♭Δ7
          // in one and F♯m7 in the other and a letter-at-a-time
          // transposition carries that difference across.
          for (final awkward in ['C♭', 'F♭', 'E♯', 'B♯', 'D♯', 'A♯']) {
            expect(
              symbol,
              isNot(startsWith(awkward)),
              reason: '${tune.title} +$semitones',
            );
            expect(
              symbol,
              isNot(contains('/$awkward')),
              reason: '${tune.title} +$semitones',
            );
          }
        }
      }
    }
    // Equinox for a B♭ player: its A7 is written B7.
    final equinox = standards.firstWhere((t) => t.title == 'Equinox');
    expect(
      {for (final s in equinox.transposed(2).slots) s.chord.display},
      {'E♭m7', 'A♭m7', 'B7', 'B♭7'},
    );
  });
}
