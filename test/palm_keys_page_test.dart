// The palm keys page: what it says about the exercise on it.
//
// The progressions need explaining in a way the scales do not. A line
// whose degrees say "5" over a chord nobody has been told about is a
// riddle, and the odd-looking degrees have a reason that is the lesson
// rather than a quirk.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/screens/palm_keys_screen.dart';
import 'package:play_along/theme.dart';

class _FakePlayer extends PracticePlayer {
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

Future<void> pick(WidgetTester tester, String shape) async {
  await tester.tap(find.byKey(ValueKey('shape-$shape')));
  await tester.pumpAndSettle();
}

/// Brings something below the fold into view: the page is a long one and
/// the list only builds what it needs.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  // The page itself, not the stave's own sideways scroll.
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the page explains what is on it', () {
    testWidgets('a scale is left to speak for itself', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('palm-changes')), findsNothing);
      expect(find.textContaining('One line through the three'), findsNothing);
    });

    testWidgets('a ii–V–I names its chords', (tester) async {
      // Degrees that say "5" over a chord nobody has named is a riddle.
      await open(tester);
      await pick(tester, 'ii–V–I');
      final changes = find.byKey(const ValueKey('palm-changes'));
      await scrollTo(tester, changes);
      final chords = tester.widget<Text>(changes);
      expect(chords.data, contains('Dm7'));
      expect(chords.data, contains('G7'));
    });

    testWidgets('and says why the V starts on its 5th', (tester) async {
      // The odd-looking degree is the lesson rather than a quirk.
      await open(tester);
      await pick(tester, 'ii–V–I');
      await scrollTo(tester, find.textContaining('One line through the three'));
      expect(find.textContaining('nearest note above'), findsOneWidget);
      await scrollTo(tester, find.textContaining('where the harmony resolves'));
    });

    testWidgets('guide tones get their own reason instead', (tester) async {
      await open(tester);
      await pick(tester, 'Guide Tones');
      await scrollTo(tester, find.textContaining('the two that move'));
      expect(find.textContaining('where the harmony resolves'), findsNothing);
    });

    testWidgets('the chords follow the key', (tester) async {
      await open(tester);
      await pick(tester, 'ii–V–I');
      await tester.tap(find.byKey(const ValueKey('palm-key-F')));
      await tester.pumpAndSettle();
      final changes = find.byKey(const ValueKey('palm-changes'));
      await scrollTo(tester, changes);
      final chords = tester.widget<Text>(changes);
      expect(chords.data, contains('Gm7'));
      expect(chords.data, contains('C7'));
    });
  });
}
