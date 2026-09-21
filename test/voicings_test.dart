// Voicings: whether each named arrangement is the arrangement it is
// named after.
//
// These are not opinions. Drop 2 is the second voice from the top moved
// down an octave, and a test can say so exactly; a shell is root, 3rd
// and 7th and nothing else. So the tests check the definitions rather
// than that something plausible came out.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/guitar_voicing.dart';
import 'package:play_along/music/voicings.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/screens/voicings_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

class _FakePlayer extends PracticePlayer {
  @override
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
    int pickUpBeats = 0,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  void setVolume(Instrument instrument, double volume) {}
}

Chord get _cmaj7 => Chord.parse('C^7');
List<String> _notesOf(List<VoicedNote> v) => [for (final n in v) n.note];

void main() {
  group('close position', () {
    test('is the chord stacked in thirds inside an octave', () {
      expect(_notesOf(Voicing.close.on(_cmaj7)), ['C', 'E', 'G', 'B']);
      expect(spanOf(Voicing.close.on(_cmaj7)), lessThanOrEqualTo(12));
    });

    test('it never goes past an octave, whatever the chord', () {
      // The claim the drops are measured against.
      for (final symbol in ['C^7', 'Dm7', 'G7', 'Cm7', 'Cø7', 'C6']) {
        final close = Voicing.close.on(Chord.parse(symbol));
        expect(spanOf(close), lessThanOrEqualTo(12), reason: symbol);
      }
    });
  });

  group('the drops', () {
    test('drop 2 moves the second voice from the top down an octave', () {
      // The definition, checked against the definition: everything else
      // stays where it was and one note is exactly twelve lower.
      final close = Voicing.close.on(_cmaj7);
      final dropped = Voicing.drop2.on(_cmaj7);
      expect(_notesOf(dropped), ['G', 'C', 'E', 'B']);

      final second = close[close.length - 2];
      final moved = dropped.firstWhere((n) => n.moved);
      expect(moved.note, second.note);
      expect(moved.pitch, second.pitch - 12);
    });

    test('drop 3 moves the third voice instead', () {
      final close = Voicing.close.on(_cmaj7);
      final dropped = Voicing.drop3.on(_cmaj7);
      expect(_notesOf(dropped), ['E', 'C', 'G', 'B']);
      final third = close[close.length - 3];
      expect(dropped.firstWhere((n) => n.moved).pitch, third.pitch - 12);
    });

    test('exactly one voice moves, and the rest are untouched', () {
      for (final voicing in [Voicing.drop2, Voicing.drop3]) {
        for (final symbol in ['C^7', 'Dm7', 'G7']) {
          final chord = Chord.parse(symbol);
          final close = Voicing.close.on(chord);
          final dropped = voicing.on(chord);
          expect(
            dropped.where((n) => n.moved),
            hasLength(1),
            reason: '$voicing on $symbol',
          );
          // Same four notes, still: a drop rearranges, it does not
          // change which notes are in the chord.
          expect(
            dropped.map((n) => n.note).toSet(),
            close.map((n) => n.note).toSet(),
            reason: '$voicing on $symbol',
          );
        }
      }
    });

    test('a drop is wider than an octave, which is what it is for', () {
      for (final voicing in [Voicing.drop2, Voicing.drop3]) {
        for (final symbol in ['C^7', 'Dm7', 'G7']) {
          expect(
            spanOf(voicing.on(Chord.parse(symbol))),
            greaterThan(12),
            reason: '$voicing on $symbol',
          );
        }
      }
      // And drop 3 opens a bigger hole than drop 2.
      expect(
        spanOf(Voicing.drop3.on(_cmaj7)),
        greaterThan(spanOf(Voicing.drop2.on(_cmaj7))),
      );
    });

    test('the drops are the only ones that move anything', () {
      for (final voicing in Voicing.values) {
        final moved = voicing.on(_cmaj7).where((n) => n.moved);
        expect(moved.isNotEmpty, voicing.isADrop, reason: voicing.name);
      }
    });
  });

  group('leaving notes out', () {
    test('a shell is the root, the 3rd and the 7th', () {
      final shell = Voicing.shell.on(_cmaj7);
      expect(_notesOf(shell), ['C', 'E', 'B']);
      expect(shell.map((n) => n.degree), [
        'root',
        '3rd',
        '7th',
      ], reason: 'no 5th, and never missed');
    });

    test('it keeps the notes that say what the chord is', () {
      // A shell has to tell a minor 7th from a dominant, or it is not
      // carrying the chord.
      final minor = Voicing.shell.on(Chord.parse('Dm7'));
      final dominant = Voicing.shell.on(Chord.parse('D7'));
      expect(_notesOf(minor), isNot(_notesOf(dominant)));
      for (final shell in [minor, dominant]) {
        expect(shell, hasLength(3));
        expect(shell.map((n) => n.degree), contains('root'));
      }
    });

    test('the rootless forms leave the root to the bass', () {
      for (final voicing in [Voicing.rootlessA, Voicing.rootlessB]) {
        for (final symbol in ['C^7', 'Dm7', 'G7']) {
          final chord = Chord.parse(symbol);
          expect(
            voicing.on(chord).map((n) => n.degree),
            isNot(contains('root')),
            reason: '$voicing on $symbol',
          );
        }
      }
    });

    test('A has the 3rd at the bottom and B has the 7th', () {
      expect(Voicing.rootlessA.on(_cmaj7).first.degree, '3rd');
      expect(Voicing.rootlessB.on(_cmaj7).first.degree, '7th');
      final dm7 = Chord.parse('Dm7');
      expect(Voicing.rootlessA.on(dm7).first.degree, '♭3rd');
      expect(Voicing.rootlessB.on(dm7).first.degree, '♭7th');
    });

    test('they are the band\'s own, not a second copy of them', () {
      // The pianist plays voicingsFor; this reads the same function, so
      // the screen cannot come to teach something the band does not do.
      for (final symbol in ['C^7', 'Dm7', 'G7']) {
        final chord = Chord.parse(symbol);
        final band = voicingsFor(chord);
        expect(
          Voicing.rootlessA.on(chord).map((n) => n.pitch),
          band.first,
          reason: symbol,
        );
        expect(
          Voicing.rootlessB.on(chord).map((n) => n.pitch),
          band.last,
          reason: symbol,
        );
      }
    });
  });

  group('naming the notes', () {
    test('a 6th over a chord with a 7th is called the 13th', () {
      // What a player would say, and what the rootless forms use it as.
      expect(degreeIn(Chord.parse('G7'), Chord.parse('G7').root + 9), '13th');
      expect(degreeIn(Chord.parse('C6'), Chord.parse('C6').root + 9), '6th');
    });

    test('every note of every voicing knows what it is', () {
      for (final voicing in Voicing.values) {
        for (final symbol in ['C^7', 'Dm7', 'G7']) {
          for (final note in voicing.on(Chord.parse(symbol))) {
            expect(note.degree, isNotEmpty, reason: '$voicing on $symbol');
            expect(note.note, isNotEmpty);
          }
        }
      }
    });

    test('each one says what it is and where you would use it', () {
      for (final voicing in Voicing.values) {
        expect(voicing.label, isNotEmpty);
        expect(voicing.about.length, greaterThan(80), reason: voicing.name);
      }
    });
  });

  group('on the neck', () {
    test('a shape sounds exactly the notes it was asked for', () {
      // Exact, not approximate: the same notes in the same octaves, or
      // it is a different voicing wearing the same name.
      for (final voicing in Voicing.values) {
        for (final symbol in ['C^7', 'Dm7', 'G7']) {
          final chord = Chord.parse(symbol);
          final pitches = [for (final n in voicing.on(chord)) n.pitch];
          final shape = shapeForPitches(pitches);
          if (shape == null) continue;
          final sounded = shape.pitches;
          final wanted = [for (final p in pitches) p - pitches.first];
          final got = [for (final p in sounded) p - sounded.first];
          expect(got, wanted, reason: '$voicing on $symbol');
          expect(
            sounded.first % 12,
            pitches.first % 12,
            reason: '$voicing on $symbol starts on the right note',
          );
        }
      }
    });

    test('drop 2 comes out on adjacent strings', () {
      // The reason guitarists care about it at all.
      final pitches = [for (final n in Voicing.drop2.on(_cmaj7)) n.pitch];
      final shape = shapeForPitches(pitches)!;
      final played = [
        for (final (i, fret) in shape.frets.indexed)
          if (fret != null) i,
      ];
      expect(played.last - played.first, played.length - 1);
    });

    test('a shape a hand cannot span is not offered', () {
      for (final voicing in Voicing.values) {
        for (final symbol in ['C^7', 'Dm7', 'G7']) {
          final shape = shapeForPitches([
            for (final n in voicing.on(Chord.parse(symbol))) n.pitch,
          ]);
          if (shape == null) continue;
          final fretted = shape.frets.whereType<int>().where((f) => f > 0);
          if (fretted.isEmpty) continue;
          expect(
            fretted.reduce(GuitarVoicing.max) -
                fretted.reduce(GuitarVoicing.min),
            lessThan(5),
            reason: '$voicing on $symbol',
          );
        }
      }
    });

    test('it moves the shape to where the neck is', () {
      // The pitches come from a piano range and a guitar sounds an
      // octave below written, so the search keeps the intervals and the
      // bass note and lets the octave fall where it can be played.
      final low = shapeForPitches([30, 42])!;
      expect(low.pitches.first % 12, 30 % 12, reason: 'the same bass note');
      expect(low.pitches[1] - low.pitches.first, 12, reason: 'same interval');
      expect(
        low.pitches.first,
        greaterThanOrEqualTo(40),
        reason: 'on a string',
      );
    });

    test('nothing is invented when the guitar cannot do it', () {
      expect(shapeForPitches([60]), isNull, reason: 'one note is not a shape');
      expect(
        shapeForPitches([48, 49, 50, 51, 52, 53, 54]),
        isNull,
        reason: 'seven notes, six strings',
      );
      // A semitone apart is perfectly playable across two strings, which
      // is worth knowing before assuming otherwise.
      expect(shapeForPitches([60, 61]), isNotNull);
    });
  });

  group('the two-note shells', () {
    test('each is the root and one other note', () {
      expect(_notesOf(Voicing.rootSeventh.on(_cmaj7)), ['C', 'B']);
      expect(_notesOf(Voicing.rootThird.on(_cmaj7)), ['C', 'E']);
      for (final voicing in [Voicing.rootSeventh, Voicing.rootThird]) {
        for (final symbol in ['C^7', 'Dm7', 'G7']) {
          final notes = voicing.on(Chord.parse(symbol));
          expect(notes, hasLength(2), reason: '$voicing on $symbol');
          expect(notes.first.degree, 'root', reason: '$voicing on $symbol');
        }
      }
    });

    test('the note on top is the one that says what the chord is', () {
      // A shell with the 5th on top would not tell a m7 from a 7.
      for (final voicing in [Voicing.rootSeventh, Voicing.rootThird]) {
        for (final symbol in ['Dm7', 'D7']) {
          final top = voicing.on(Chord.parse(symbol)).last.degree;
          expect(top, isNot('5th'), reason: '$voicing on $symbol');
        }
      }
      expect(
        Voicing.rootThird.on(Chord.parse('Dm7')).last.note,
        isNot(Voicing.rootThird.on(Chord.parse('D7')).last.note),
      );
    });

    test('alternating them keeps the top note still', () {
      // The whole reason there are two forms, and the claim the screen
      // makes out loud, so it had better be true both ways round.
      final iiVI = [Chord.parse('Dm7'), Chord.parse('G7'), Chord.parse('C^7')];
      for (final from7th in [true, false]) {
        final rows = alternatingShells(iiVI, from7th: from7th);
        final tops = [for (final row in rows) row.last.pitch];
        for (var i = 1; i < tops.length; i++) {
          expect(
            (tops[i] - tops[i - 1]).abs(),
            lessThanOrEqualTo(2),
            reason: 'from7th $from7th, step $i: $tops',
          );
        }
      }
    });

    test('it really does alternate rather than repeat one form', () {
      final iiVI = [Chord.parse('Dm7'), Chord.parse('G7'), Chord.parse('C^7')];
      final rows = alternatingShells(iiVI);
      expect(rows[0].last.degree, '♭7th');
      expect(rows[1].last.degree, '3rd');
      expect(rows[2].last.degree, '7th');
      // Starting the other way round swaps every one of them.
      final other = alternatingShells(iiVI, from7th: false);
      for (var i = 0; i < rows.length; i++) {
        expect(other[i].last.degree, isNot(rows[i].last.degree), reason: '$i');
      }
    });

    test('without the voice leading it would leap, which is the point', () {
      // Each voicing on its own is placed in its own register. Left
      // like that the hand jumps an octave between notes a semitone
      // apart, so the run has to move them.
      final plain = [
        for (final symbol in ['Dm7', 'G7', 'C^7'])
          Voicing.rootThird.on(Chord.parse(symbol)).last.pitch,
      ];
      final leaps = [
        for (var i = 1; i < plain.length; i++) (plain[i] - plain[i - 1]).abs(),
      ];
      expect(leaps.any((l) => l > 2), isTrue, reason: 'unled: $plain');
    });
  });

  group('the names', () {
    test('every one says where its name comes from', () {
      for (final voicing in Voicing.values) {
        expect(voicing.whyCalled.length, greaterThan(80), reason: voicing.name);
        expect(
          voicing.whyCalled,
          isNot(voicing.about),
          reason: '${voicing.name}: what it is called is not what it is for',
        );
      }
    });

    test('the drops explain that the counting starts at the top', () {
      // The one thing that trips everybody up, so it has to be said and
      // not implied.
      for (final voicing in [Voicing.drop2, Voicing.drop3]) {
        expect(
          voicing.whyCalled.toLowerCase(),
          contains('top'),
          reason: voicing.name,
        );
      }
    });
  });

  group('shells on the guitar', () {
    test('the shape is the root, the 7th and the 3rd, in that order', () {
      for (final symbol in ['G^7', 'Gm7', 'G7', 'C^7', 'Cm7', 'C7']) {
        final chord = Chord.parse(symbol);
        for (final string in [0, 1]) {
          final shape = shellShape(chord, rootString: string)!;
          final sounded = shape.pitches;
          expect(sounded, hasLength(3), reason: '$symbol on $string');
          expect(
            sounded.first % 12,
            chord.root % 12,
            reason: '$symbol starts on its root',
          );
          // Climbing, and the middle note is the 7th rather than the 3rd.
          expect(sounded[1], greaterThan(sounded[0]), reason: symbol);
          expect(sounded[2], greaterThan(sounded[1]), reason: symbol);
          final above = (sounded[1] - sounded[0]) % 12;
          expect(above, anyOf(9, 10, 11), reason: '$symbol: a 7th or a 6th');
        }
      }
    });

    test('it skips a string in the middle, which is the whole shape', () {
      for (final string in [0, 1]) {
        final shape = shellShape(Chord.parse('C7'), rootString: string)!;
        final played = [
          for (final (i, fret) in shape.frets.indexed)
            if (fret != null) i,
        ];
        expect(played, [string, string + 2, string + 3]);
      }
    });

    test('a hand can reach it', () {
      for (final symbol in ['G^7', 'Gm7', 'G7', 'C^7', 'Cm7', 'C7', 'F^7']) {
        for (final string in [0, 1]) {
          final shape = shellShape(Chord.parse(symbol), rootString: string);
          if (shape == null) continue;
          final fretted = shape.frets.whereType<int>().where((f) => f > 0);
          if (fretted.isEmpty) continue;
          expect(
            fretted.reduce(GuitarVoicing.max) -
                fretted.reduce(GuitarVoicing.min),
            lessThan(5),
            reason: '$symbol on $string',
          );
        }
      }
    });

    test('the standard shapes really do come out', () {
      // The ones in every guitar book, which is the check that this is
      // the vocabulary and not merely something that works.
      String written(GuitarVoicing v) =>
          v.frets.map((f) => f?.toString() ?? 'x').join(' ');
      expect(
        written(shellShape(Chord.parse('G^7'), rootString: 0)!),
        '3 x 4 4 x x',
      );
      expect(
        written(shellShape(Chord.parse('Gm7'), rootString: 0)!),
        '3 x 3 3 x x',
      );
      expect(
        written(shellShape(Chord.parse('G7'), rootString: 0)!),
        '3 x 3 4 x x',
      );
      expect(
        written(shellShape(Chord.parse('C^7'), rootString: 1)!),
        'x 3 x 4 5 x',
      );
      expect(
        written(shellShape(Chord.parse('Cm7'), rootString: 1)!),
        'x 3 x 3 4 x',
      );
      expect(
        written(shellShape(Chord.parse('C7'), rootString: 1)!),
        'x 3 x 3 5 x',
      );
    });

    test('a chord with no 3rd or 7th has no shell', () {
      expect(shellShape(Chord.parse('Csus4'), rootString: 0), isNull);
      // And there is nowhere to put one off the top two strings.
      expect(shellShape(Chord.parse('C7'), rootString: 4), isNull);
    });
  });

  group('the screen', () {
    Future<void> open(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: VoicingsScreen(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester, String value, String near) async {
      final chip = find.byKey(ValueKey('pick-$value'));
      await tester.dragUntilVisible(
        chip,
        find.byKey(ValueKey('pick-$near')),
        const Offset(-140, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    testWidgets('the stack is on screen when it opens', (tester) async {
      await open(tester);
      final stack = find.byKey(const ValueKey('the-voicing'));
      expect(stack, findsOneWidget);
      expect(tester.getRect(stack).bottom, lessThan(852));
      for (final note in ['C', 'E', 'G', 'B']) {
        expect(find.text(note), findsOneWidget, reason: note);
      }
    });

    testWidgets('picking drop 2 marks the voice that moved', (tester) async {
      await open(tester);
      await pick(tester, 'drop2', 'close');
      expect(find.text('5th, dropped'), findsOneWidget);
      expect(
        find.textContaining('second voice down from the top'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('it says the span, and that a drop breaks the octave', (
      tester,
    ) async {
      await open(tester);
      expect(find.textContaining('sits inside an octave'), findsOneWidget);
      await pick(tester, 'drop2', 'close');
      expect(find.textContaining('never goes past twelve'), findsOneWidget);
    });

    testWidgets('close has nothing to compare, the others do', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('play-close')), findsNothing);
      await pick(tester, 'drop2', 'close');
      expect(find.byKey(const ValueKey('play-close')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('play-close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play-voicing')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing the chord redraws it', (tester) async {
      await open(tester);
      final chip = find.byKey(const ValueKey('pick-G7'));
      await tester.scrollUntilVisible(
        chip,
        120,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('voicings-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('F'), findsOneWidget, reason: 'the ♭7 of G7');
      expect(tester.takeException(), isNull);
    });

    testWidgets('it is drawn on the keys and on the neck', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('the-keys')), findsOneWidget);
      expect(find.byKey(const ValueKey('the-shape')), findsOneWidget);
    });

    testWidgets('a voicing with no guitar shape says so', (tester) async {
      await open(tester);
      await pick(tester, 'rootlessB', 'close');
      expect(find.byKey(const ValueKey('not-on-a-guitar')), findsOneWidget);
      expect(find.byKey(const ValueKey('the-shape')), findsNothing);
      expect(find.textContaining('cannot reach them'), findsOneWidget);
      // The keys can still show it: it is the guitar that cannot.
      expect(find.byKey(const ValueKey('the-keys')), findsOneWidget);
    });

    testWidgets('it says where the name comes from', (tester) async {
      await open(tester);
      await pick(tester, 'drop2', 'close');
      expect(find.byKey(const ValueKey('why-called')), findsOneWidget);
      expect(find.textContaining('counts down from the top'), findsOneWidget);
    });

    testWidgets('the guitar shells turn up under the shell', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('the-shells')), findsNothing);
      await pick(tester, 'shell', 'close');
      final shells = find.byKey(const ValueKey('the-shells'));
      await tester.scrollUntilVisible(
        shells,
        140,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('voicings-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(shells, findsOneWidget);
      expect(find.text('Root on the 6th string'), findsOneWidget);
      expect(find.text('Root on the 5th string'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the two-note shell shows why there are two', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('alternating')), findsNothing);
      await pick(tester, 'rootSeventh', 'close');
      final run = find.byKey(const ValueKey('alternating'));
      await tester.scrollUntilVisible(
        run,
        140,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('voicings-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(run, findsOneWidget);
      expect(
        find.textContaining('moves 1 semitone, then not at all'),
        findsOneWidget,
      );
      final button = find.byKey(const ValueKey('play-alternating'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('it opens from Learn', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: LearnPage(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      final card = find.byKey(const ValueKey('learn-voicings'));
      await tester.scrollUntilVisible(card, 100);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(VoicingsScreen), findsOneWidget);
    });
  });
}
