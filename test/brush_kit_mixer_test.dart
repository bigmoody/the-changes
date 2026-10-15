// Choosing the kit, in the mixer.
//
// The row used to appear only once a SoundFont had been imported, which
// was right while the only alternative to the band's own kit was one you
// had to go and find. With brushes in the app there is always a choice to
// make, so the row is always there.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

Future<void> openMixer(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: PracticeScreen(
        tune: standards.firstWhere((tune) => tune.title == 'A Foggy Day'),
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Mixer'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the kit row is there without anything imported', (tester) async {
    await openMixer(tester);
    expect(find.byKey(const ValueKey('drum-sound')), findsOneWidget);
  });

  testWidgets('and offers both of the band\'s own kits', (tester) async {
    await openMixer(tester);
    expect(find.text('Sticks'), findsOneWidget);
    expect(find.text('Brushes'), findsOneWidget);
  });

  testWidgets('but not a kit nobody has imported', (tester) async {
    // A segment for a kit that is not there is a button that can only
    // disappoint.
    await openMixer(tester);
    expect(find.text('Imported Kit'), findsNothing);
  });

  testWidgets('and the brushes can be chosen', (tester) async {
    await openMixer(tester);
    // Scrolled into view first: the sheet grew a Voice row under the Kit
    // row, and a tap at an off-screen position does nothing silently.
    await tester.ensureVisible(find.text('Brushes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Brushes'));
    await tester.pumpAndSettle();
    final button = tester.widget<SegmentedButton<DrumSound>>(
      find.byKey(const ValueKey('drum-sound')),
    );
    expect(button.selected, {DrumSound.brushes});
  });
}
