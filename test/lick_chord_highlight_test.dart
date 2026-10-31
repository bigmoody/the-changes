// The bar of changes the band is in is lit while the lick plays, so you
// can see which chord you are over.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/practice/licks.dart';
import 'package:play_along/practice/roadmap.dart';
import 'package:play_along/practice/roadmap_progress.dart';
import 'package:play_along/screens/lick_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

import 'support/fake_player.dart';

void main() {
  testWidgets('the bar the band is in is lit, and only while it plays', (
    tester,
  ) async {
    final player = FakePlayer();
    await tester.runAsync(() async {
      player.samples = await SampleBank.load(
        (path) async => File('assets/sounds/$path').readAsBytes(),
      );
    });
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: LickScreen(
          licks: licks,
          keyName: 'F',
          instrument: RoadmapInstrument.horn,
          progress: RoadmapProgress.inMemory(),
          player: player,
          settings: AppSettings.inMemory(),
        ),
      ),
    );
    final scheme = Theme.of(tester.element(find.byType(LickScreen)))
        .colorScheme;
    Color? shade(int bar) =>
        ((tester
                    .widget<Container>(find.byKey(ValueKey('lick-bar-$bar')))
                    .decoration
                as BoxDecoration?)
            ?.color);
    expect(shade(0), isNull);

    await tester.tap(find.byKey(const ValueKey('lick-play')));
    await tester.pump();
    // At 100 a beat is 0.6 s: four beats of count-in, then six beats in,
    // which is the second bar.
    player.snippetAt = const Duration(milliseconds: (4 + 6) * 600);
    await tester.pump(const Duration(milliseconds: 40));
    expect(shade(1), isNotNull);
    expect(
      shade(1)!.toARGB32() & 0xFFFFFF,
      scheme.primary.toARGB32() & 0xFFFFFF,
    );
    expect(shade(0), isNull);

    // Stopped, nothing is lit.
    player.snippetAt = null;
    await tester.pump(const Duration(milliseconds: 40));
    expect(shade(1), isNull);
  });
}
