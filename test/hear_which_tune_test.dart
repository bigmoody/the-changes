// Changing to the tune a band sounds like, from the stage, and listening
// on: the tune's page and its stage replaced by the other tune's.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/other_apps.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/music/user_progression.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';
import 'package:play_along/theme.dart';

void main() {
  testWidgets('changes to the tune the band sounds like, still listening', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final follows = <Map>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      otherAppsChannel,
      (call) async {
        if (call.method == 'follow') follows.add(call.arguments as Map);
        return call.method == 'now' ? 500.0 : null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        otherAppsChannel,
        null,
      ),
    );
    // One of the player's own, which the band may be playing too.
    final mine = UserProgression.fromTune(
      standards.firstWhere((tune) => tune.title == 'Four'),
      id: 'mine-1',
    );
    final progressions = ProgressionStore.inMemory([mine]);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: PracticeScreen(
          tune: standards.firstWhere((tune) => tune.title == 'Cherokee'),
          player: PracticePlayer(),
          settings: AppSettings.inMemory(),
          progressions: progressions,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hear-the-band')));
    await tester.pumpAndSettle();
    expect(follows, hasLength(1));
    final ids = [
      for (final chart in follows.single['library'] as List)
        (chart as Map)['id'] as String,
    ];
    expect(ids, containsAll(['s:Cherokee', 's:Four', 'p:mine-1']));
    // Through the microphone.
    await tester.tap(find.text('Microphone'));
    await tester.pumpAndSettle();
    expect(follows.last['source'], 'microphone');
    for (var look = 0; look < 2; look++) {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        otherAppsChannel.name,
        otherAppsChannel.codec.encodeMethodCall(
          const MethodCall('heard', {
            'tunes': [
              {'id': 'p:mine-1', 'score': 4.0, 'semitones': 0},
              {'id': 's:Cherokee', 'score': 3.0, 'semitones': 0},
            ],
          }),
        ),
        (_) {},
      );
    }
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stage-sounds-like-p:mine-1')));
    await tester.pumpAndSettle();
    // The player's own Four, on a stage listening through the microphone.
    expect(find.byKey(const ValueKey('stage-other-apps')), findsOneWidget);
    expect(follows.last['source'], 'microphone');
    expect(follows.last['chart'], OtherAppsSound.chartOf(mine.toTune()));
    // Leaving the stage, its page is Four's.
    await tester.tap(find.byKey(const ValueKey('stage-done')));
    await tester.pumpAndSettle();
    expect(find.text(mine.displayTitle), findsWidgets);
    expect(find.text('Cherokee'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  Future<void> openMenu(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: PracticeScreen(
          tune: standards.firstWhere((tune) => tune.title == 'Cherokee'),
          player: PracticePlayer(),
          settings: AppSettings.inMemory(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tune-menu')));
    await tester.pumpAndSettle();
  }

  testWidgets('the menu leaves the scrolling stage to the ear', (tester) async {
    await openMenu(tester);
    expect(find.byKey(const ValueKey('hear-the-band')), findsOneWidget);
    expect(find.text('Stage View'), findsOneWidget);
    expect(find.text('Scrolling Stage View'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('and keeps it where there is no ear', (tester) async {
    await openMenu(tester);
    expect(find.byKey(const ValueKey('hear-the-band')), findsNothing);
    expect(find.text('Scrolling Stage View'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
