// Pause and Stop for any example that is playing, on every screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/screens/snippet_controls.dart';
import 'package:play_along/theme.dart';

void main() {
  testWidgets('it shows while something plays and goes when stopped', (
    tester,
  ) async {
    final player = PracticePlayer();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(body: Center(child: SnippetControls(player: player))),
      ),
    );
    expect(find.byKey(const ValueKey('snippet-controls')), findsNothing);

    player.snippetState.value = SnippetState.playing;
    await tester.pumpAndSettle();
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);

    // Held, it offers to carry on.
    player.snippetState.value = SnippetState.paused;
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('snippet-stop')));
    await tester.pumpAndSettle();
    expect(player.snippetState.value, SnippetState.idle);
    expect(find.byKey(const ValueKey('snippet-controls')), findsNothing);
  });
}
