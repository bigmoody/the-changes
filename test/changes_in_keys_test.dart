// The common changes, round all twelve keys.
//
// The thing worth testing is that it walks the keys on its own: that is
// the whole difference between this and writing a ii-V-I out by hand
// twelve times, and it is the part a person cannot check at a glance
// because it happens while they are playing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/changes_to_run.dart';
import 'package:play_along/screens/changes_in_keys_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

import 'support/fake_player.dart';

/// A band that plays nothing, but says which chorus it is on when asked.
class _FakePlayer extends FakePlayer {
  int? chorus;

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

  @override
  PlaybackPosition? position() =>
      chorus == null ? null : PlaybackPosition(tuneBeat: 0, chorus: chorus);
}

void main() {
  late _FakePlayer player;
  late AppSettings settings;

  Future<void> open(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(393, 1400) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    player = _FakePlayer();
    settings = AppSettings.inMemory();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
        home: ChangesInKeysScreen(player: player, settings: settings),
      ),
    );
    await tester.pumpAndSettle();
  }

  String textOf(Key key) {
    final widget = find.byKey(key).evaluate().single.widget;
    if (widget is Text) return widget.data!;
    // A key written in its own colour is a KeyText, which draws a Text of
    // its own underneath.
    return (find
                .descendant(of: find.byKey(key), matching: find.byType(Text))
                .evaluate()
                .single
                .widget
            as Text)
        .data!;
  }

  group('nothing to set up', () {
    testWidgets('it opens on a ii-V-I in C, written out', (tester) async {
      await open(tester);
      expect(textOf(const ValueKey('round-key')), 'Key of C');
      expect(textOf(const ValueKey('round-bar-0')), 'Dm7');
      expect(textOf(const ValueKey('round-bar-1')), 'G7');
      expect(textOf(const ValueKey('round-bar-2')), contains('C'));
      expect(textOf(const ValueKey('round-progress')), '1 of 12');
    });

    testWidgets('all twelve keys are there to jump to', (tester) async {
      await open(tester);
      for (var move = 0; move < 12; move++) {
        expect(find.byKey(ValueKey('round-key-$move')), findsOneWidget);
      }
    });

    testWidgets('and other changes can be picked without building them', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('changes-pick')));
      await tester.pumpAndSettle();
      for (final one in changesToRun) {
        expect(find.text(one.title), findsWidgets, reason: one.title);
      }
      await tester.tap(find.text('Minor ii V i').last);
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('round-bar-0')), contains('m7♭5'));
    });
  });

  group('the whole forms are there too', () {
    testWidgets('a blues, all twelve bars of it, starting in F', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('changes-pick')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blues').last);
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('round-key')), 'Key of F');
      expect(textOf(const ValueKey('round-bar-0')), 'F7');
      expect(find.byKey(const ValueKey('round-bar-11')), findsOneWidget);
      expect(find.byKey(const ValueKey('round-bar-12')), findsNothing);
    });

    testWidgets('and rhythm changes, starting in B flat', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('changes-pick')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rhythm changes').last);
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('round-key')), contains('B'));
      expect(textOf(const ValueKey('round-bar-0')), contains('B♭'));
      expect(
        find.byKey(const ValueKey('round-bar-31')),
        findsOneWidget,
        reason: 'thirty-two bars, written out as they are played',
      );
    });

    testWidgets('a whole form moves round the keys like anything else', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('changes-pick')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blues').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('round-key')), contains('B'));
      expect(textOf(const ValueKey('round-bar-0')), contains('B♭7'));
    });

    testWidgets('but they are not offered for saving a lick over', (
      tester,
    ) async {
      // Thirty-two bars is the best part of a minute to wait for the two
      // you wanted to keep.
      expect(
        shortChanges.map((one) => one.title),
        isNot(contains('Rhythm changes')),
      );
      expect(changesToRun.length, shortChanges.length + 2);
    });
  });

  group('going round', () {
    testWidgets('next key is a fourth up, and the changes move with it', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('round-key')), 'Key of F');
      expect(textOf(const ValueKey('round-bar-0')), 'Gm7');
      expect(textOf(const ValueKey('round-bar-1')), 'C7');
    });

    testWidgets('a key is spelled, not named both ways', (tester) async {
      // A key is B flat or A sharp depending on where it came from.
      // Naming both on a heading and on twelve chips helps nobody.
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('round-key')), 'Key of B♭');
      final chip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('round-key-10')),
      );
      expect((chip.label as Text).data, 'B♭');
    });

    testWidgets('a key can be jumped to', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('round-key-3')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('round-key')), contains('E'));
    });

    testWidgets('and going back wraps rather than sticking', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('previous-key')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('round-progress')), '12 of 12');
    });
  });

  group('moving on by itself', () {
    testWidgets('it is on to begin with, after two times round', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Move on by Itself'), findsOneWidget);
      expect(textOf(const ValueKey('choruses-each')), '2');
      expect(find.textContaining('After 2 times round'), findsOneWidget);
    });

    testWidgets('how many times round can be changed', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('more-choruses')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('choruses-each')), '3');
      await tester.tap(find.byKey(const ValueKey('fewer-choruses')));
      await tester.tap(find.byKey(const ValueKey('fewer-choruses')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('choruses-each')), '1');
    });

    testWidgets('turning it off says so, and the counter goes', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('move-on')));
      await tester.pumpAndSettle();
      expect(find.text('Stays put until you move it'), findsOneWidget);
      expect(find.byKey(const ValueKey('choruses-each')), findsNothing);
    });
  });

  group('it really does move on, which is the whole point', () {
    /// Lets the band's clock tick with [chorus] times round gone by.
    Future<void> roundsGoneBy(WidgetTester tester, int chorus) async {
      player.chorus = chorus - 1; // the clock counts from nought
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();
    }

    testWidgets('after the set number of times round, it changes key', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(textOf(const ValueKey('round-key')), 'Key of C');

      await roundsGoneBy(tester, 2);
      expect(
        textOf(const ValueKey('round-key')),
        'Key of C',
        reason: 'two times round is not yet more than two',
      );

      await roundsGoneBy(tester, 3);
      expect(textOf(const ValueKey('round-key')), 'Key of F');
      expect(textOf(const ValueKey('round-bar-0')), 'Gm7');
    });

    testWidgets('and the key it left is marked as played', (tester) async {
      await open(tester);
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await roundsGoneBy(tester, 3);
      final chip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('round-key-0')),
      );
      expect(chip.avatar, isNotNull, reason: 'C has been played');
    });

    testWidgets('turned off, it stays where it is', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('move-on')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await roundsGoneBy(tester, 6);
      expect(textOf(const ValueKey('round-key')), 'Key of C');
    });

    testWidgets('fewer times round means it moves sooner', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('fewer-choruses')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await roundsGoneBy(tester, 2);
      expect(textOf(const ValueKey('round-key')), 'Key of F');
    });
  });

  group('what a transposing player sees', () {
    testWidgets('the key and the changes are both in their key', (
      tester,
    ) async {
      await open(tester);
      await settings.setInstrument(ChartInstrument.bFlat);
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('round-key')), 'Key of D');
      expect(textOf(const ValueKey('round-bar-0')), 'Em7');
    });

    testWidgets('and the chips are their keys too', (tester) async {
      await open(tester);
      await settings.setInstrument(ChartInstrument.eFlat);
      await tester.pumpAndSettle();
      // E flat instruments read a major sixth above concert: C becomes A.
      expect(textOf(const ValueKey('round-key')), 'Key of A');
    });
  });
}
