// Naming what you hear, on screen.
//
// The questions are tested where they are made. What matters here is the
// teaching: that nothing gives the answer away before it is chosen, that
// getting it wrong says what it was and why, and that both can be heard
// one after the other, which is the only part of this that teaches
// anything.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/music/ear_training.dart';
import 'package:play_along/screens/ear_training_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

import 'support/fake_player.dart';

class _FakePlayer extends FakePlayer {
  @override
  void setVolume(Instrument instrument, double volume) {}
}

void main() {
  Future<void> open(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(393, 1400) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
        home: EarTrainingScreen(
          player: _FakePlayer(),
          settings: AppSettings.inMemory(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String textOf(Key key) =>
      (find.byKey(key).evaluate().single.widget as Text).data!;

  /// The names offered, in the order shown.
  List<String> choicesOn(WidgetTester tester) => [
    for (final question in earQuestions)
      if (find
          .byKey(ValueKey('ear-choice-${question.name}'))
          .evaluate()
          .isNotEmpty)
        question.name,
  ];

  Future<void> answer(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(ValueKey('ear-choice-$name')));
    await tester.pumpAndSettle();
  }

  group('before an answer is in', () {
    testWidgets('it offers choices and gives nothing away', (tester) async {
      await open(tester);
      expect(choicesOn(tester), hasLength(4));
      expect(find.byKey(const ValueKey('ear-verdict')), findsNothing);
      expect(find.byKey(const ValueKey('ear-next')), findsNothing);
      expect(find.text('Play It'), findsOneWidget);
      // No chords shown: they would name the answer.
      for (final name in choicesOn(tester)) {
        final tile = tester.widget<ListTile>(
          find.byKey(ValueKey('ear-choice-$name')),
        );
        expect(tile.subtitle, isNull, reason: name);
        expect(tile.trailing, isNull, reason: name);
      }
    });

    testWidgets('nothing is scored yet', (tester) async {
      await open(tester);
      expect(textOf(const ValueKey('ear-score')), isEmpty);
    });

    testWidgets('the group can be changed and says what it asks', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text(EarGroup.quality.label));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('ear-about')), EarGroup.quality.about);
      // The choices are from that group now.
      final names = choicesOn(tester).toSet();
      for (final question in earQuestions) {
        if (names.contains(question.name)) {
          expect(question.group, EarGroup.quality);
        }
      }
    });
  });

  group('answering', () {
    testWidgets('getting it right says so and scores it', (tester) async {
      await open(tester);
      // The test cannot know which is right, so it finds out the way the
      // screen does: by what the verdict says afterwards.
      await answer(tester, choicesOn(tester).first);
      final verdict = textOf(const ValueKey('ear-verdict'));
      final score = textOf(const ValueKey('ear-score'));
      if (verdict.startsWith('Yes')) {
        expect(score, '1 of 1');
      } else {
        expect(score, '0 of 1');
        expect(verdict, startsWith('It was '));
      }
    });

    testWidgets('it always says what it was, and why', (tester) async {
      await open(tester);
      await answer(tester, choicesOn(tester).first);
      expect(find.byKey(const ValueKey('ear-verdict')), findsOneWidget);
      final why = textOf(const ValueKey('ear-why'));
      expect(why, isNotEmpty);
      // The explanation belongs to the right answer, not the one picked.
      final named = earQuestions.firstWhere((q) => q.about == why);
      expect(textOf(const ValueKey('ear-verdict')), contains(named.name));
    });

    testWidgets('afterwards every choice shows its chords and can be heard', (
      tester,
    ) async {
      await open(tester);
      await answer(tester, choicesOn(tester).first);
      for (final name in choicesOn(tester)) {
        final tile = tester.widget<ListTile>(
          find.byKey(ValueKey('ear-choice-$name')),
        );
        expect(tile.subtitle, isNotNull, reason: name);
        expect(
          find.byKey(ValueKey('ear-hear-$name')),
          findsOneWidget,
          reason: name,
        );
      }
    });

    testWidgets('the chords shown are spelled, not typed', (tester) async {
      // C^7 and Dh7 are how they are written down in the source, not how
      // anybody reads them.
      await open(tester);
      await answer(tester, choicesOn(tester).first);
      for (final name in choicesOn(tester)) {
        final tile = tester.widget<ListTile>(
          find.byKey(ValueKey('ear-choice-$name')),
        );
        final shown = (tile.subtitle! as Text).data!;
        expect(shown, isNot(contains('^')), reason: name);
        expect(shown, isNot(contains('h7')), reason: name);
        expect(shown, isNot(contains('b9')), reason: name);
      }
    });

    testWidgets('right and wrong are told apart by a mark, not a colour', (
      tester,
    ) async {
      // The app's accent is a red pencil mark and the error colour is
      // red too, so the two states looked the same. A tick and a cross
      // say which is which whatever the palette does.
      await open(tester);
      for (var go = 0; go < 12; go++) {
        await answer(tester, choicesOn(tester).first);
        final wrong = textOf(const ValueKey('ear-verdict'))
            .startsWith('It was ');
        expect(find.byIcon(Icons.check), findsOneWidget);
        expect(find.byIcon(Icons.close), wrong ? findsOneWidget : findsNothing);
        if (wrong) return;
        await tester.tap(find.byKey(const ValueKey('ear-next')));
        await tester.pumpAndSettle();
      }
      fail('never got one wrong in twelve tries');
    });

    testWidgets('answering twice does not score twice', (tester) async {
      await open(tester);
      final names = choicesOn(tester);
      await answer(tester, names.first);
      await answer(tester, names.last);
      expect(textOf(const ValueKey('ear-score')).split(' ').last, '1');
    });

    testWidgets('a wrong answer offers to hear yours against it', (
      tester,
    ) async {
      await open(tester);
      // Answer every choice in turn across fresh questions until one is
      // wrong, which it will be within a few goes.
      for (var go = 0; go < 12; go++) {
        await answer(tester, choicesOn(tester).first);
        if (textOf(const ValueKey('ear-verdict')).startsWith('It was ')) {
          expect(find.byKey(const ValueKey('ear-hear-yours')), findsOneWidget);
          return;
        }
        await tester.tap(find.byKey(const ValueKey('ear-next')));
        await tester.pumpAndSettle();
      }
      fail('never got one wrong in twelve tries');
    });
  });

  group('moving on', () {
    testWidgets('next clears the answer and asks another', (tester) async {
      await open(tester);
      await answer(tester, choicesOn(tester).first);
      await tester.tap(find.byKey(const ValueKey('ear-next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ear-verdict')), findsNothing);
      expect(find.byKey(const ValueKey('ear-next')), findsNothing);
      expect(find.text('Play It'), findsOneWidget);
    });

    testWidgets('the score keeps count across questions', (tester) async {
      await open(tester);
      for (var i = 0; i < 3; i++) {
        await answer(tester, choicesOn(tester).first);
        await tester.tap(find.byKey(const ValueKey('ear-next')));
        await tester.pumpAndSettle();
      }
      expect(textOf(const ValueKey('ear-score')).split(' ').last, '3');
    });

    testWidgets('changing group starts the count again', (tester) async {
      await open(tester);
      await answer(tester, choicesOn(tester).first);
      await tester.tap(find.text(EarGroup.movement.label));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('ear-score')), isEmpty);
      expect(find.byKey(const ValueKey('ear-verdict')), findsNothing);
    });
  });

  group('without the recorded instruments', () {
    testWidgets('it says so rather than playing silence', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('ear-play')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('ear-problem')), contains('still loading'));
    });
  });
}
