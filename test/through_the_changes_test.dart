// Through the Changes: the screen.
//
// The two things worth testing here are the two things a player would
// notice first if they broke. A tenor player has to see the line in the
// key they read, or the page is useless to exactly the instrument it was
// written for. And the numbers in the card have to follow the exercise
// that is showing, or the comparison is decoration.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/screens/stave_figure.dart';
import 'package:play_along/screens/through_the_changes_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

import 'support/fake_player.dart';

class _FakePlayer extends FakePlayer {
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

void main() {
  Future<AppSettings> open(
    WidgetTester tester, {
    ChartInstrument instrument = ChartInstrument.concert,
  }) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final settings = AppSettings.inMemory();
    await settings.setInstrument(instrument);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: ThroughTheChangesScreen(
          player: _FakePlayer(),
          settings: settings,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  /// Scrolls [finder] into view. The page is a lazy list, so a widget
  /// further down it does not exist until something has scrolled to it,
  /// and one further up has stopped existing again. [step] is negative to
  /// go back towards the top.
  Future<void> reach(
    WidgetTester tester,
    Finder finder, {
    double step = 120,
  }) async {
    await tester.scrollUntilVisible(
      finder,
      step,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('through-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String value, String near) async {
    // The chip rows are near the top, so anything read further down the
    // page has to be scrolled back away from before they exist again.
    await reach(tester, find.byKey(ValueKey('pick-$near')), step: -120);
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

  /// Every chord symbol written over the line, in order.
  List<String> chordsOver(WidgetTester tester) => [
    for (final figure in tester.widgetList<StaveFigure>(
      find.byType(StaveFigure),
    ))
      for (final column in figure.columns) ?column.over,
  ];

  testWidgets('it opens on the blues, written out', (tester) async {
    await open(tester);
    expect(find.text('Through the Changes'), findsOneWidget);
    await reach(tester, find.byKey(const ValueKey('written-out')));
    expect(chordsOver(tester), contains('F7'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tenor player reads it in their own key', (tester) async {
    await open(tester, instrument: ChartInstrument.bFlat);
    await reach(tester, find.byKey(const ValueKey('written-out')));
    final chords = chordsOver(tester);
    // An F blues comes out as a G blues for a B♭ instrument, and the IV
    // with it: this is the reason the app has the setting at all.
    expect(chords, contains('G7'));
    expect(chords, contains('C7'));
    expect(chords, isNot(contains('F7')));
  });

  testWidgets('changing instrument rewrites what is already on screen', (
    tester,
  ) async {
    // The test above starts in the player's key, which is not the same
    // thing at all: it passes whether or not the page is listening to the
    // setting. This one changes it while the page is up, which is what a
    // player actually does, and is how the page came to sit in the old
    // key until the clef was touched.
    final settings = await open(tester);
    await reach(tester, find.byKey(const ValueKey('written-out')));
    expect(chordsOver(tester), contains('F7'));
    await settings.setInstrument(ChartInstrument.bFlat);
    await tester.pumpAndSettle();
    final chords = chordsOver(tester);
    expect(chords, contains('G7'));
    expect(chords, isNot(contains('F7')));
  });

  testWidgets('the exercise is the same notes whoever reads it', (
    tester,
  ) async {
    // The range is a concert one, so the line is the same sounds for
    // everybody and only the writing moves. If it were worked out in the
    // player's own key instead, a tenor and an alto would be practising
    // different lines over the same twelve bars and the card under them
    // would quietly disagree about how far the changes are.
    Future<List<String?>> card(ChartInstrument instrument) async {
      await open(tester, instrument: instrument);
      await reach(tester, find.byKey(const ValueKey('the-cost')));
      return [
        for (final key in ['worst-jump', 'smooth-changes', 'against-root'])
          tester.widget<Text>(find.byKey(ValueKey(key))).data,
      ];
    }

    final concert = await card(ChartInstrument.concert);
    for (final instrument in [ChartInstrument.bFlat, ChartInstrument.eFlat]) {
      expect(
        await card(instrument),
        concert,
        reason: '${instrument.symbol} was given a different exercise',
      );
    }
  });

  testWidgets('the numbers follow the exercise showing', (tester) async {
    await open(tester);
    await reach(tester, find.byKey(const ValueKey('the-cost')));
    final connected = tester
        .widget<Text>(find.byKey(const ValueKey('worst-jump')))
        .data;
    // The comparison is only offered against the exercise it answers.
    expect(find.byKey(const ValueKey('against-root')), findsOneWidget);

    await pick(tester, 'fromTheRoot', 'nearest');
    await reach(tester, find.byKey(const ValueKey('the-cost')));
    final naive = tester
        .widget<Text>(find.byKey(const ValueKey('worst-jump')))
        .data;
    expect(naive, isNot(connected));
    expect(
      find.byKey(const ValueKey('against-root')),
      findsNothing,
      reason: 'from the root has nothing to compare itself with',
    );
  });

  testWidgets('changing the changes rewrites the line', (tester) async {
    await open(tester);
    await pick(tester, 'The Bridge', 'Blues in F');
    await reach(tester, find.byKey(const ValueKey('written-out')));
    final chords = chordsOver(tester);
    expect(chords, contains('D7'));
    expect(chords, contains('G7'));
    expect(chords, isNot(contains('B♭7')));
    // The bridge starts at bar 17 and its numbers say so.
    expect(find.text('17'), findsOneWidget);
  });

  testWidgets('the bass clef is a different page, not a lower one', (
    tester,
  ) async {
    await open(tester);
    await reach(tester, find.byKey(const ValueKey('through-clef')));
    final treble = tester
        .widgetList<StaveFigure>(find.byType(StaveFigure))
        .first
        .clef;
    expect(treble, Clef.treble);
    await tester.tap(find.text('Bass'));
    await tester.pumpAndSettle();
    await reach(tester, find.byKey(const ValueKey('written-out')));
    final figures = tester.widgetList<StaveFigure>(find.byType(StaveFigure));
    expect(figures.every((figure) => figure.clef == Clef.bass), isTrue);
    // The chords are the player's own, untouched: a clef is not a key.
    expect(chordsOver(tester), contains('F7'));
  });

  testWidgets('the stave makes room for notes that leave it', (tester) async {
    // Written for an F instrument the same line sits a fifth higher, and
    // with fixed room above the stave its ledger lines came up through
    // the chord symbols. The room has to follow the notes.
    await open(tester, instrument: ChartInstrument.f);
    await reach(tester, find.byKey(const ValueKey('written-out')));
    final figures = tester.widgetList<StaveFigure>(find.byType(StaveFigure));
    expect(
      figures.any((figure) => figure.above > 4),
      isTrue,
      reason: 'nothing made room for the notes above the stave',
    );
  });

  testWidgets('hearing it does not throw without a sample bank', (
    tester,
  ) async {
    await open(tester);
    await reach(tester, find.byKey(const ValueKey('play-line')));
    await tester.tap(find.byKey(const ValueKey('play-line')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
