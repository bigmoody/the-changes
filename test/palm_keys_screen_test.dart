// The palm key diagram: whether it shows a fingering somebody can trust.
//
// The exercises on this page are a matter of teaching and can be argued
// about. The fingerings are not: they are either what the horn does or
// they are wrong, and somebody will trust them and practise them. So
// these tests check the diagram says the same thing the data says, and
// that the one surprising part of it, the right hand coming back for the
// top two notes, actually reaches the screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/palm_keys.dart';
import 'package:play_along/screens/palm_keys_screen.dart';
import 'package:play_along/theme.dart';

class _FakePlayer extends PracticePlayer {
  @override
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
    int pickUpBeats = 0,
    PlayableRecording? recording,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  void setVolume(Instrument instrument, double volume) {}
}

Future<void> open(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: PalmKeysScreen(player: _FakePlayer()),
    ),
  );
  await tester.pumpAndSettle();
}

String line(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('fingering-line'))).data!;

/// Whether a key on the map is drawn held down.
bool down(WidgetTester tester, SaxKey key) {
  final box = tester.widget<Container>(
    find.byKey(ValueKey('palm-key-${key.name}')),
  );
  final theme = appTheme(Brightness.light);
  final decoration = box.decoration! as BoxDecoration;
  return decoration.color == theme.colorScheme.tertiary;
}

void main() {
  group('the fingering diagram', () {
    testWidgets('it opens on F, which is what people come here for', (
      tester,
    ) async {
      await open(tester);
      expect(line(tester), startsWith('F:'));
      expect(find.byKey(const ValueKey('palm-key-palmF')), findsOneWidget);
    });

    testWidgets('every fingering can be asked for', (tester) async {
      await open(tester);
      for (final fingering in palmFingerings) {
        await tester.tap(find.byKey(ValueKey('fingering-${fingering.name}')));
        await tester.pumpAndSettle();
        expect(line(tester), startsWith('${fingering.name}:'));
        // Said in words as well as drawn, because a diagram with no
        // names in it is a thing to be decoded.
        for (final key in fingering.keys) {
          expect(
            line(tester),
            contains(key.label),
            reason: '${fingering.name} holds ${key.label}',
          );
        }
      }
    });

    testWidgets('the line says which hand, not just which letter', (
      tester,
    ) async {
      // "Octave + D + E♭ + F + E" reads as five palm keys, of which
      // there are three. On the map a key is a shape in a place and the
      // letter is enough; in a line the places are gone.
      await open(tester);
      expect(line(tester), 'F: Octave + palm D + palm E♭ + palm F + side E');
      await tester.tap(find.byKey(const ValueKey('fingering-E')));
      await tester.pumpAndSettle();
      expect(line(tester), 'E: Octave + palm D + palm E♭ + side E');
      await tester.tap(find.byKey(const ValueKey('fingering-D')));
      await tester.pumpAndSettle();
      expect(line(tester), 'D: Octave + palm D');
    });

    testWidgets('the map lights up exactly the keys that are held', (
      tester,
    ) async {
      await open(tester);
      for (final fingering in palmFingerings) {
        await tester.tap(find.byKey(ValueKey('fingering-${fingering.name}')));
        await tester.pumpAndSettle();
        for (final key in [
          SaxKey.palmD,
          SaxKey.palmEFlat,
          SaxKey.palmF,
          SaxKey.sideE,
        ]) {
          expect(
            down(tester, key),
            fingering.keys.contains(key),
            reason:
                '${fingering.name}: ${key.label} should be '
                '${fingering.keys.contains(key) ? 'down' : 'up'}',
          );
        }
      }
    });

    testWidgets('the right hand is on the page for E and F', (tester) async {
      // The part everybody is surprised by, and the whole of the
      // difference between E♭ and E. If it only lived in the data it
      // would be the one thing the page got wrong by omission.
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('fingering-E♭')));
      await tester.pumpAndSettle();
      expect(down(tester, SaxKey.sideE), isFalse);

      await tester.tap(find.byKey(const ValueKey('fingering-E')));
      await tester.pumpAndSettle();
      expect(down(tester, SaxKey.sideE), isTrue);
      expect(find.textContaining('right-hand side'), findsWidgets);
    });

    testWidgets('the diagram is on screen when the screen opens', (
      tester,
    ) async {
      // It is the first thing on the page and the reason somebody came.
      await open(tester);
      expect(find.byKey(const ValueKey('palm-key-palmD')), findsOneWidget);
      expect(find.byKey(const ValueKey('fingering-line')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
