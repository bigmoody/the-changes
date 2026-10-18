// Hearing other apps from the scrolling stage, in builds being worked on.
//
// The broadcast itself happens on a phone and cannot be tested here.
// This is the app's half: the button, and what it shows of the numbers
// the extension writes, answered here as the phone would.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/other_apps.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/audio/room_listener.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/practice/tap_follower.dart';
import 'package:play_along/screens/stage_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

final _now = DateTime(2026, 10, 18, 20);

/// The test's clock, moved on by hand.
var _elapsed = Duration.zero;

/// The phone's clock is this far ahead of the app's.
const _phoneAhead = 500.0;

/// Where the extension says the kept twenty seconds ended, by the
/// phone's clock: 30 s after the app's clock started.
final _keptPlaced = {
  'seconds': 20.0,
  'sampleRate': 44100.0,
  'endByTimestamp': _phoneAhead + 30,
  'endByArrival': _phoneAhead + 30.05,
};

/// The log the app left beside the kept sound, last time it did.
String? _leftTaps;

bool _keepTaps(String log) {
  _leftTaps = log;
  return true;
}

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
  TapFollower? taps,
  RoomListener? ear,
}) async {
  _elapsed = Duration.zero;
  _leftTaps = null;
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
        'now' => _phoneAhead + _elapsed.inMicroseconds / 1e6,
        'kept' => Uint8List(4),
        'keptPlaced' => jsonEncode(_keptPlaced),
        'keepTaps' => _keepTaps(call.arguments as String),
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
  final sound = OtherAppsSound(now: () => _now, clock: () => _elapsed);
  addTearDown(sound.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: StageScreen(
        controller: controller,
        follow: true,
        otherApps: otherApps ? sound : null,
        taps: taps,
        listener: ear,
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

  testWidgets('keeps the taps made along with it, where they fell', (
    tester,
  ) async {
    final taps = TapFollower(
      tune: standards.firstWhere((tune) => tune.title == 'Cherokee'),
      clock: () => _elapsed,
    );
    addTearDown(taps.dispose);
    await _openStage(tester, taps: taps);
    await tester.tap(find.byKey(const ValueKey('stage-hear-others')));
    await tester.pump();
    // Before the kept twenty seconds, then in them: 10 s to 30 s.
    _elapsed = const Duration(seconds: 5);
    taps.tapBeat();
    _elapsed = const Duration(milliseconds: 12500);
    taps.tapBeat();
    _elapsed = const Duration(seconds: 14);
    taps.placeAtBar(2);
    await tester.tap(find.byKey(const ValueKey('stage-save-broadcast')));
    await tester.pump();
    final log = _leftTaps!;
    expect(log, startsWith('# Cherokee'));
    expect(log, contains('bars'));
    expect(log, contains('end placed by timestamp'));
    expect(log, contains('arrival minus timestamp 0.050 s'));
    expect(log, contains('2.500  TAP THE BEAT'));
    expect(log, contains('4.000  TAPPED BAR 3'));
    expect('TAP THE BEAT'.allMatches(log).length, 1);
    await tester.tap(find.byKey(const ValueKey('stage-follow-taps')));
    await tester.tap(find.byKey(const ValueKey('stage-hear-others')));
    await tester.pump();
  });

  testWidgets('the taps still work with the broadcast open', (tester) async {
    final taps = TapFollower(
      tune: standards.firstWhere((tune) => tune.title == 'Cherokee'),
      clock: () => _elapsed,
    );
    addTearDown(taps.dispose);
    await _openStage(tester, taps: taps, report: _playing());
    await tester.tap(find.byKey(const ValueKey('stage-hear-others')));
    await tester.pump(const Duration(milliseconds: 250));
    // Hearing another app follows it by taps too.
    expect(find.byKey(const ValueKey('stage-tapping')), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      _elapsed += const Duration(milliseconds: 300);
      await tester.tap(find.byKey(const ValueKey('stage-tap-beat')));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(taps.tempo, closeTo(200, 1));
    await tester.tap(find.text('Top of the Chorus'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(taps.counting, isTrue);
    await tester.tap(find.byKey(const ValueKey('stage-follow-taps')));
    await tester.tap(find.byKey(const ValueKey('stage-hear-others')));
    await tester.pump();
  });

  testWidgets('keeps the ear\'s taps too', (tester) async {
    final room = StreamController<Float32List>();
    addTearDown(() {
      unawaited(room.close());
    });
    final ear = RoomListener(
      tune: standards.firstWhere((tune) => tune.title == 'Cherokee'),
      source: () async => room.stream,
    );
    await _openStage(tester, ear: ear);
    await tester.tap(find.byKey(const ValueKey('stage-hear-others')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stage-listen')));
    await tester.pump();
    _elapsed = const Duration(seconds: 13);
    await tester.tap(find.byKey(const ValueKey('stage-tap-tempo')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stage-save-broadcast')));
    await tester.pump();
    expect(_leftTaps, contains('3.000  TAP THE BEAT'));
    await tester.tap(find.byKey(const ValueKey('stage-listen')));
    await tester.tap(find.byKey(const ValueKey('stage-hear-others')));
    await tester.pump();
  });

  testWidgets('follows the barlines Beat This! hears', (tester) async {
    final taps = TapFollower(
      tune: standards.firstWhere((tune) => tune.title == 'Cherokee'),
      clock: () => _elapsed,
    );
    addTearDown(taps.dispose);
    final asked = await _openStage(tester, taps: taps, report: _playing());
    await tester.tap(find.byKey(const ValueKey('stage-hear-others')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(asked, contains('follow'));
    expect(find.textContaining('listening for the bars'), findsOneWidget);
    // Five barlines 1.16 s apart, the last just now, by the phone's clock.
    _elapsed = const Duration(seconds: 15);
    final now = _phoneAhead + 15;
    // The same look twice: a barline is handed on once two agree on it.
    for (var look = 0; look < 2; look++) {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        otherAppsChannel.name,
        otherAppsChannel.codec.encodeMethodCall(
          MethodCall('heard', {
            'downbeats': [for (var i = 4; i >= 0; i--) now - 1.16 * i],
            'beats': <double>[],
            // The bar between the last two barlines, and what sounded in it.
            'bars': [
              {'start': now - 1.16, 'pitches': List<double>.filled(48, 0.5)},
            ],
            'end': now,
            'took': 0.05,
          }),
        ),
        (_) {},
      );
    }
    await tester.pump();
    expect(taps.counting, isTrue);
    expect(taps.tempo, closeTo(240 / 1.16, 0.5));
    expect(
      find.textContaining('heard 5 barlines, 50 ms a look'),
      findsOneWidget,
    );
    // Kept with the taps, for playing the count through again: the kept
    // stretch starts at 10 s.
    await tester.tap(find.byKey(const ValueKey('stage-save-broadcast')));
    await tester.pump();
    expect(_leftTaps, contains('5.000  HEARD BARLINE 5.000'));
    expect(_leftTaps, contains('5.000  HEARD BARLINE 0.360'));
    expect(_leftTaps, contains('5.000  HEARD BAR 3.840 0.5000'));
    await tester.tap(find.byKey(const ValueKey('stage-hear-others')));
    await tester.pump();
    expect(asked, contains('stopFollowing'));
    await tester.tap(find.byKey(const ValueKey('stage-follow-taps')));
    await tester.pump();
  });
}
