// Hearing other apps from the scrolling stage, in builds being worked on.
//
// The broadcast itself happens on a phone and cannot be tested here.
// This is the app's half: the button, and what it shows of the numbers
// the extension writes, answered here as the phone would.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/other_apps.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/screens/stage_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

final _now = DateTime(2026, 10, 18, 20);

/// What the extension writes while YouTube is playing.
Map<String, Object> _playing({double peak = 0.4, double level = 0.1}) => {
  'state': 'started',
  'updated': _now.millisecondsSinceEpoch / 1000,
  'format':
      '44100 Hz, 2 channels, 16-bit signed integer, big endian, '
      'interleaved',
  'sampleRate': 44100,
  'channels': 2,
  'framesPerBuffer': 1024,
  'buffers': 860,
  'silentBuffers': 0,
  'frames': 880640,
  'seconds': 19.97,
  'level': level,
  'peak': peak,
  'longestGap': 0.046,
  'jumps': 0,
};

Future<List<String>> _openStage(
  WidgetTester tester, {
  Map<String, Object>? report,
  bool otherApps = true,
}) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final asked = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    otherAppsChannel,
    (call) async {
      asked.add(call.method);
      return switch (call.method) {
        'read' => report == null ? null : jsonEncode(report),
        'pick' => true,
        _ => null,
      };
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      otherAppsChannel,
      null,
    ),
  );
  final controller = PracticeController(
    tune: standards.firstWhere((tune) => tune.title == 'Cherokee'),
    player: PracticePlayer(),
    settings: AppSettings.inMemory(),
  );
  addTearDown(controller.dispose);
  final sound = OtherAppsSound(now: () => _now);
  addTearDown(sound.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: StageScreen(
        controller: controller,
        follow: true,
        otherApps: otherApps ? sound : null,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return asked;
}

void main() {
  testWidgets('is not offered where there is no extension', (tester) async {
    await _openStage(tester, otherApps: false);
    expect(find.byKey(const ValueKey('stage-hear-others')), findsNothing);
  });

  testWidgets('says what to do before anything has arrived', (tester) async {
    final asked = await _openStage(tester);
    await tester.tap(find.byKey(const ValueKey('stage-hear-others')));
    await tester.pump();
    expect(find.textContaining('choose The Changes'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stage-start-broadcast')));
    await tester.pump();
    expect(asked, contains('pick'));
    await tester.tap(find.byKey(const ValueKey('stage-hear-others')));
    await tester.pump();
    expect(find.byKey(const ValueKey('stage-other-apps')), findsNothing);
  });

  testWidgets('shows the level and the format as it arrives', (tester) async {
    await _openStage(tester, report: _playing());
    await tester.tap(find.byKey(const ValueKey('stage-hear-others')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Hearing the other app.'), findsOneWidget);
    expect(find.textContaining('44100 Hz, 2 channels'), findsOneWidget);
    expect(find.textContaining('44098 frames a second'), findsOneWidget);
    final meter = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('stage-other-apps-level')),
    );
    // A level of 0.1 is 20 dB below full scale: two thirds of the meter.
    expect(meter.value, closeTo(2 / 3, 0.01));
    await tester.tap(find.byKey(const ValueKey('stage-hear-others')));
    await tester.pump();
  });

  testWidgets('says when the sound arriving is silence', (tester) async {
    await _openStage(tester, report: _playing(peak: 0, level: 0));
    await tester.tap(find.byKey(const ValueKey('stage-hear-others')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('it is silent'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stage-hear-others')));
    await tester.pump();
  });
}
