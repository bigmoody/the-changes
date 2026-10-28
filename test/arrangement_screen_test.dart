// The Arrangement sheet on the practice screen: setting up a performance,
// and what it says back about it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/arrangement.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: PracticeScreen(
        tune: standards.firstWhere((t) => t.title == 'Blue Bossa'),
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('arrangement')));
  await tester.pumpAndSettle();
}

/// The sheet scrolls, so a control lower down has to be brought into view
/// before it can be tapped.
Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    target,
    80,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
}

bool _isOn(WidgetTester tester, String key) {
  final widget = tester.widget(find.byKey(ValueKey(key)));
  return switch (widget) {
    ChoiceChip(:final selected) => selected,
    FilterChip(:final selected) => selected,
    SwitchListTile(:final value) => value,
    _ => throw StateError('$key is a ${widget.runtimeType}'),
  };
}

void main() {
  testWidgets('set up a performance: four choruses, head in and out', (
    tester,
  ) async {
    await _open(tester);
    // A tune knows when to stop: in, a chorus to blow on, out.
    expect(_isOn(tester, 'choruses-3'), isTrue);
    expect(_isOn(tester, 'choruses-keep'), isFalse);

    await _tap(tester, 'choruses-4');
    await _tap(tester, 'head-in-out');

    expect(_isOn(tester, 'choruses-4'), isTrue);
    expect(_isOn(tester, 'choruses-keep'), isFalse);
    expect(_isOn(tester, 'head-in-out'), isTrue);
    // It says how many are left over to solo on.
    expect(find.textContaining('with 2 choruses to solo'), findsOneWidget);
  });

  testWidgets('trading and laying out, then Reset puts it all back', (
    tester,
  ) async {
    await _open(tester);
    await _tap(tester, 'trading-fours');
    await _tap(tester, 'lay-out-chords');

    expect(_isOn(tester, 'trading-fours'), isTrue);
    expect(_isOn(tester, 'lay-out-chords'), isTrue);
    expect(
      find.textContaining('You take 4, whoever answers takes 4'),
      findsOneWidget,
    );

    // Who answers only comes up once there is trading to answer, and it
    // starts where it always did, with the drummer.
    expect(_isOn(tester, 'trade-with-drums'), isTrue);
    await _tap(tester, 'trade-with-time');
    expect(_isOn(tester, 'trade-with-time'), isTrue);
    expect(find.textContaining('Nobody fills them'), findsOneWidget);

    await _tap(tester, 'arrangement-reset');
    expect(_isOn(tester, 'trading-off'), isTrue);
    expect(_isOn(tester, 'lay-out-chords'), isFalse);
    // With nobody trading there is nothing to answer, so the choice goes.
    expect(find.byKey(const ValueKey('trade-with-drums')), findsNothing);
    expect(_isOn(tester, 'choruses-3'), isTrue);
  });

  testWidgets('a tempo ramp, and what it says it will do', (tester) async {
    await _open(tester);
    expect(find.textContaining('Ramp it and every time round'), findsOneWidget);

    await _tap(tester, 'choruses-keep');
    await _tap(tester, 'ramp-5');
    expect(_isOn(tester, 'ramp-5'), isTrue);
    // Blue Bossa starts at its own tempo; the ceiling is shown as a tempo,
    // not as "+40", so you know what you are letting yourself in for.
    expect(_isOn(tester, 'climb-40'), isTrue, reason: 'a sensible default');
    expect(
      find.textContaining(RegExp(r'Starts at \d+ and reaches \d+ on chorus 9')),
      findsOneWidget,
    );

    // With a fixed number of choruses it says where it actually ends up,
    // rather than promising a tempo the performance never reaches.
    await _tap(tester, 'choruses-4');
    expect(
      find.textContaining(RegExp(r'ends at \d+ on the last chorus')),
      findsOneWidget,
    );
    await _tap(tester, 'choruses-keep');

    await _tap(tester, 'climb-none');
    expect(_isOn(tester, 'climb-none'), isTrue);
    expect(find.text('No Limit'), findsOneWidget);

    // Off again, and the "Up To" row goes with it.
    await _tap(tester, 'ramp-0');
    expect(find.byKey(const ValueKey('climb-40')), findsNothing);
  });

  testWidgets('the part that can lay out is named after who plays it', (
    tester,
  ) async {
    await _open(tester);
    // The piano has the chords unless the guitar is switched on.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('lay-out-chords')),
        matching: find.text('Piano'),
      ),
      findsOneWidget,
    );
  });

  test('the controller carries the arrangement, and starts on no chorus', () {
    final controller = PracticeController(
      tune: standards.first,
      player: PracticePlayer(),
      settings: AppSettings.inMemory(),
    );
    addTearDown(controller.dispose);
    expect(
      controller.arrangement,
      const Arrangement(choruses: AppSettings.defaultChoruses),
    );
    expect(controller.chorus, isNull);
    expect(controller.chorusPlan, isNull);
    controller.setArrangement(const Arrangement(choruses: 4));
    expect(controller.arrangement.choruses, 4);
    expect(controller.isFinishing, isFalse);
  });

  test('the groove brings the tempo with it, and only when it has to', () {
    final tune = standards.firstWhere((t) => t.title == 'Route 66');
    final controller = PracticeController(
      tune: tune,
      player: PracticePlayer(),
      settings: AppSettings.inMemory(),
    );
    addTearDown(controller.dispose);
    final written = controller.tempo;
    expect(written, greaterThan(140), reason: 'a shuffle at a fair lick');

    // Funk tops out at 140: too fast a tempo comes down to meet it.
    controller.setStyle(BandStyle.of(Feel.funk));
    expect(controller.tempo, 140);

    // A samba starts at 150: too slow a tempo goes up to meet it.
    controller.setStyle(BandStyle.of(Feel.samba));
    expect(controller.tempo, 150);

    // Swing is every tempo there is, so it leaves the tempo where it is.
    controller.setStyle(BandStyle.of(Feel.swing));
    expect(controller.tempo, 150);
  });
}
