// The palm key fingering diagrams: whether they show something a player
// can trust.
//
// The exercises on this page are a matter of teaching and can be argued
// about. The fingerings are not: they are either what the horn does or
// they are wrong, and somebody will trust them and practise them. So
// these check that every hole and key is drawn in the state the data
// says, that the surprising parts reach the screen, and that no note is
// quietly missing from the chart.

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

/// Whether a drawn key or hole is filled in, which is what the diagram
/// uses to mean held down.
bool filled(WidgetTester tester, String note, SaxKey key) {
  final box = tester.widget<Container>(
    find.byKey(ValueKey('$note-${key.name}')),
  );
  final ink = (box.decoration! as BoxDecoration).color;
  return ink == appTheme(Brightness.light).colorScheme.onSurface;
}

/// Every key a saxophone has, which is every key the diagram draws.
const _everyKey = SaxKey.values;

void main() {
  group('the fingering diagrams', () {
    testWidgets('all seven are on the page, either side of the join', (
      tester,
    ) async {
      await open(tester);
      for (final fingering in joinFingerings) {
        expect(
          find.byKey(ValueKey('fingering-name-${fingering.name}')),
          findsOneWidget,
          reason: fingering.name,
        );
      }
      expect(find.text('Up to the Join'), findsOneWidget);
      expect(find.text('On the Palm Keys'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every hole and key is drawn as the fingering says', (
      tester,
    ) async {
      // The whole of the claim. A diagram that disagreed with the data
      // would be the data being right and the player being told wrong.
      await open(tester);
      for (final fingering in joinFingerings) {
        for (final key in _everyKey) {
          expect(
            filled(tester, fingering.name, key),
            fingering.keys.contains(key),
            reason: '${fingering.name}: ${key.said}',
          );
        }
      }
    });

    testWidgets('the right hand is drawn on E and F and not on E flat', (
      tester,
    ) async {
      // The part everybody is surprised by, and the whole of the
      // difference between E♭ and E.
      await open(tester);
      expect(filled(tester, 'E♭', SaxKey.sideE), isFalse);
      expect(filled(tester, 'E', SaxKey.sideE), isTrue);
      expect(filled(tester, 'F', SaxKey.sideE), isTrue);
      expect(find.textContaining('side of the right hand'), findsOneWidget);
    });

    testWidgets('C sharp is drawn as nothing held but the octave key', (
      tester,
    ) async {
      // The hard one coming down, because there is no shape to arrive
      // at, and the diagram has to show that rather than look unfinished.
      await open(tester);
      for (final key in _everyKey) {
        expect(
          filled(tester, 'C♯', key),
          key == SaxKey.octave,
          reason: key.said,
        );
      }
    });

    testWidgets('the octave key is down on all seven', (tester) async {
      await open(tester);
      for (final fingering in joinFingerings) {
        expect(
          filled(tester, fingering.name, SaxKey.octave),
          isTrue,
          reason: fingering.name,
        );
      }
    });

    testWidgets('it is a saxophone, not a column of holes', (tester) async {
      // The thing that was wrong before: a thumb key over two stacks of
      // three is a clarinet, and a player can tell at a glance. Every
      // key the horn has is drawn on every note, held or not.
      await open(tester);
      for (final key in SaxKey.values) {
        expect(
          find.byKey(ValueKey('F-${key.name}')),
          findsOneWidget,
          reason: 'the F diagram should draw ${key.said}',
        );
      }
      // The ones a clarinet has no idea about.
      for (final key in [
        SaxKey.frontF,
        SaxKey.bis,
        SaxKey.palmD,
        SaxKey.sideFSharp,
        SaxKey.lhGSharp,
        SaxKey.rhEFlat,
      ]) {
        expect(find.byKey(ValueKey('B-${key.name}')), findsOneWidget);
      }
    });

    testWidgets('the key map names the ones this page is about', (
      tester,
    ) async {
      await open(tester);
      expect(find.byKey(const ValueKey('map-palmD')), findsOneWidget);
      for (final name in ['palm D', 'palm E♭', 'palm F', 'side E']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
    });

    testWidgets('the chart is on screen when the screen opens', (tester) async {
      // It is near the top of the page and the reason somebody came.
      await open(tester);
      expect(find.byKey(const ValueKey('fingering-name-D')), findsOneWidget);
      expect(find.byKey(const ValueKey('fingering-name-F')), findsOneWidget);
    });
  });
}
