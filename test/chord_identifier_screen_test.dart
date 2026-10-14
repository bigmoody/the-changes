// The Chord Identifier screen: play a chord, read what it is.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/screens/chord_identifier_screen.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

import 'fake_chord_listener.dart';
import 'support/fake_player.dart';

/// A band that stops without any real audio.
class _FakePlayer extends FakePlayer {
  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<void> restoreAudioSession() async => restored = true;

  @override
  void setVolume(Instrument instrument, double volume) {}
}

Future<FakeChordListener> _open(
  WidgetTester tester, {
  bool allowed = true,
  _FakePlayer? player,
}) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final mic = FakeChordListener(allowed: allowed);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
      home: ChordIdentifierScreen(
        player: player ?? _FakePlayer(),
        settings: AppSettings.inMemory(),
        listener: mic,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return mic;
}

void main() {
  testWidgets('it asks you to play something, then names it', (tester) async {
    final mic = await _open(tester);
    expect(find.text('Play a chord.'), findsOneWidget);
    expect(mic.listening, isTrue);

    // An open C: C3 E3 G3 C4 E4.
    mic.hear([48, 52, 55, 60, 64]);
    await tester.pumpAndSettle();
    expect(find.text('C'), findsWidgets);
    expect(find.text('Major'), findsOneWidget);
    expect(find.textContaining('Heard'), findsOneWidget);
    // The fingering closest to what was played, written out.
    expect(find.text('x 3 2 0 1 0'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('it holds the last chord while the strings die away', (
    tester,
  ) async {
    final mic = await _open(tester);
    mic.hear([50, 57, 60, 65]); // Dm7
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chord-name')), findsOneWidget);

    // Silence: what was named stays put rather than blinking out.
    mic.hear(const [], level: 0);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chord-name')), findsOneWidget);
    expect(find.text('Play a chord.'), findsNothing);
  });

  testWidgets('two notes are not a chord', (tester) async {
    final mic = await _open(tester);
    mic.hear([48, 55]);
    await tester.pumpAndSettle();
    expect(find.text('Play a chord.'), findsOneWidget);
  });

  testWidgets('the other readings are offered, and can be chosen', (
    tester,
  ) async {
    final mic = await _open(tester);
    mic.hear([48, 52, 55, 57]); // C E G A: C6, or Am7 over a C
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('guess-0')), findsOneWidget);
    final second = find.byKey(const ValueKey('guess-1'));
    expect(second, findsOneWidget);

    final before = tester
        .widget<Text>(find.byKey(const ValueKey('chord-name')))
        .data;
    await tester.tap(second);
    await tester.pumpAndSettle();
    final after = tester
        .widget<Text>(find.byKey(const ValueKey('chord-name')))
        .data;
    expect(after, isNot(before), reason: 'it shows the one you picked');
  });

  testWidgets('a blocked microphone says so', (tester) async {
    await _open(tester, allowed: false);
    expect(find.textContaining('microphone is blocked'), findsWidgets);
  });

  testWidgets('it stops the band, and gives the audio back on the way out', (
    tester,
  ) async {
    final player = _FakePlayer();
    final mic = await _open(tester, player: player);
    expect(player.stopped, isTrue, reason: 'it cannot listen over the band');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(mic.stopped, isTrue);
  });

  testWidgets('it is on the Learn page', (tester) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
        home: LearnPage(
          player: _FakePlayer(),
          settings: AppSettings.inMemory(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('learn-identify'));
    await tester.scrollUntilVisible(
      card,
      100,
      // The page's own list, not the search box's text field,
      // which is a scrollable too.
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Chord Identifier'), findsOneWidget);
  });
}
