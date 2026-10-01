// The spacebar starting and stopping the band.
//
// Written against the widget rather than against a whole practice screen,
// because what matters is the two rules: space plays, and space while
// somebody is typing is a space.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/play_shortcuts.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

void main() {
  testWidgets('space plays, without anything having been tapped first', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PlayPauseShortcut(
          onPlayPause: () => taps++,
          child: const Scaffold(body: Text('chart')),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(taps, 1);

    // And again, because it is a toggle rather than a start.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(taps, 2);
  });

  testWidgets('and does nothing while something is being typed into', (
    tester,
  ) async {
    // A space in the search box is a space.
    var taps = 0;
    final field = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: PlayPauseShortcut(
          onPlayPause: () => taps++,
          child: Scaffold(body: TextField(focusNode: field)),
        ),
      ),
    );
    field.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(taps, 0);
  });

  testWidgets('other keys are left alone', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PlayPauseShortcut(
          onPlayPause: () => taps++,
          child: const Scaffold(body: Text('chart')),
        ),
      ),
    );
    for (final key in [
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.arrowRight,
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.pumpAndSettle();
    expect(taps, 0);
  });

  testWidgets('and the practice screen is wired to it', (tester) async {
    // The widget above is only worth having if a real screen uses it, and
    // the wiring is the part a refactor could quietly undo.
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
    expect(find.byType(PlayPauseShortcut), findsOneWidget);
  });
}
