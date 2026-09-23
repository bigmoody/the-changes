// Taking a lick round the twelve keys.
//
// The two things that must hold: the line and the chords over it move
// together, and what you play fills the line in as you play it. The
// second is the whole reason to listen rather than mark at the end.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/lick.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tuning.dart';
import 'package:play_along/music/user_progression.dart';
import 'package:play_along/screens/lick_drill_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

import 'fake_listener.dart';

class _FakePlayer extends PracticePlayer {
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

/// D E F G over a ii-V in C, which is the plainest thing anybody plays.
final theLick = Lick(
  id: 'l1',
  name: 'Plain as it comes',
  over: UserProgression(
    id: 'p1',
    title: 'ii V',
    key: 'C',
    tempo: 140,
    bars: const ['Dm7', 'G7'],
    style: BandStyle.of(Feel.swing),
  ),
  notes: [
    for (final (i, pitch) in const [62, 64, 65, 67].indexed)
      (pitch: pitch, beat: i * 1.0, beats: 0.5, velocity: 0.85),
  ],
  at: DateTime(2026, 9, 23),
);

void main() {
  late FakeListener mic;
  late AppSettings settings;

  Future<void> open(WidgetTester tester, {Lick? lick}) async {
    tester.view
      ..physicalSize = const Size(393, 1000) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    mic = FakeListener();
    settings = AppSettings.inMemory();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
        home: LickDrillScreen(
          lick: lick ?? theLick,
          player: _FakePlayer(),
          settings: settings,
          listener: mic,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String textOf(Key key) =>
      (find.byKey(key).evaluate().single.widget as Text).data!;

  /// Plays [pitches], letting go between each so a repeat counts twice.
  Future<void> play(WidgetTester tester, List<int> pitches) async {
    for (final pitch in pitches) {
      mic.hear(midiToHz(pitch));
      mic.hear(null);
      await tester.pump();
    }
  }

  Future<void> startListening(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('follow-me')));
    await tester.pumpAndSettle();
  }

  group('where it starts', () {
    testWidgets('in the key the lick was played in', (tester) async {
      await open(tester);
      expect(textOf(const ValueKey('drill-key')), contains('C'));
      expect(textOf(const ValueKey('drill-progress')), contains('1 of 12'));
    });

    testWidgets('with all twelve keys offered', (tester) async {
      await open(tester);
      for (var move = 0; move < 12; move++) {
        expect(
          find.byKey(ValueKey('round-key-$move')),
          findsOneWidget,
          reason: 'move $move',
        );
      }
    });

    testWidgets('and the line on a stave', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('drill-line')), findsOneWidget);
    });
  });

  group('going round the keys', () {
    testWidgets('next key moves a fourth, as the cycle does', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('drill-key')), contains('F'));
      expect(textOf(const ValueKey('drill-progress')), contains('2 of 12'));
    });

    testWidgets('back goes back, and wraps round rather than sticking', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('previous-key')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('drill-progress')), contains('12 of 12'));
    });

    testWidgets('a key can be jumped to', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('round-key-3')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('drill-key')), contains('E'));
    });
  });

  group('the line follows what you play', () {
    testWidgets('it fills in note by note', (tester) async {
      await open(tester);
      await startListening(tester);
      expect(textOf(const ValueKey('drill-got')), '0 of 4');

      await play(tester, const [62, 64]);
      expect(textOf(const ValueKey('drill-got')), '2 of 4');

      await play(tester, const [65, 67]);
      expect(textOf(const ValueKey('drill-got')), 'All of it');
    });

    testWidgets('a wrong note does not move it on', (tester) async {
      await open(tester);
      await startListening(tester);
      await play(tester, const [62, 70, 70]);
      expect(textOf(const ValueKey('drill-got')), '1 of 4');
    });

    testWidgets('the microphone is asked to leave the band playing', (
      tester,
    ) async {
      await open(tester);
      await startListening(tester);
      expect(mic.alongside, isTrue);
    });

    testWidgets('without the microphone it says so and still plays', (
      tester,
    ) async {
      await open(tester);
      mic = FakeListener(allowed: false);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
          home: LickDrillScreen(
            lick: theLick,
            player: _FakePlayer(),
            settings: settings,
            listener: mic,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await startListening(tester);
      expect(textOf(const ValueKey('drill-problem')), contains('microphone'));
      expect(find.byKey(const ValueKey('drill-line')), findsOneWidget);
    });
  });

  group('the key you are in is the key you have to play', () {
    testWidgets('moving key moves what it is listening for', (tester) async {
      await open(tester);
      await startListening(tester);
      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.pumpAndSettle();

      // The lick in C started on D. In F it starts on G, so the D that
      // was right a moment ago is not any more.
      await play(tester, const [62]);
      expect(textOf(const ValueKey('drill-got')), '0 of 4');
      await play(tester, const [67]);
      expect(textOf(const ValueKey('drill-got')), '1 of 4');
    });

    testWidgets('a key played through is marked off', (tester) async {
      await open(tester);
      await startListening(tester);
      await play(tester, const [62, 64, 65, 67]);
      expect(textOf(const ValueKey('drill-progress')), contains('1 played'));
    });

    testWidgets('and going back to it starts it again', (tester) async {
      await open(tester);
      await startListening(tester);
      await play(tester, const [62, 64]);
      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('drill-got')), '0 of 4');
    });
  });

  group('a lick with no changes under it', () {
    final justALine = Lick(
      id: 'l2',
      name: 'A shape',
      notes: [
        for (final (i, pitch) in const [63, 65, 66, 68].indexed)
          (pitch: pitch, beat: i * 1.0, beats: 0.5, velocity: 0.85),
      ],
      at: DateTime(2026, 9, 23),
      tempo: 160,
    );

    testWidgets('gets a click where the band would be', (tester) async {
      await open(tester, lick: justALine);
      expect(find.byKey(const ValueKey('click-play')), findsOneWidget);
      expect(find.text('Play'), findsNothing);
      expect(
        textOf(const ValueKey('click-tempo')),
        '160 BPM',
        reason: 'the tempo it was caught at',
      );
    });

    testWidgets('is known by the note it starts on, not by a key', (
      tester,
    ) async {
      await open(tester, lick: justALine);
      expect(textOf(const ValueKey('drill-key')), 'Key of E♭');
      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('drill-key')), 'Key of A♭');
    });

    testWidgets('and still goes round all twelve, and still listens', (
      tester,
    ) async {
      await open(tester, lick: justALine);
      for (var move = 0; move < 12; move++) {
        expect(find.byKey(ValueKey('round-key-$move')), findsOneWidget);
      }
      await startListening(tester);
      await play(tester, const [63, 65]);
      expect(textOf(const ValueKey('drill-got')), '2 of 4');
    });

    testWidgets('the stave has no chord symbols over it', (tester) async {
      await open(tester, lick: justALine);
      expect(find.byKey(const ValueKey('drill-line')), findsOneWidget);
      expect(find.text('Dm7'), findsNothing);
    });

    testWidgets('the tempo steps, and two quick taps both count', (
      tester,
    ) async {
      await open(tester, lick: justALine);
      await tester.tap(find.byKey(const ValueKey('click-faster')));
      await tester.tap(find.byKey(const ValueKey('click-faster')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('click-tempo')), '170 BPM');
    });
  });

  group('what a transposing player sees', () {
    testWidgets('the line and the chords are both in their key', (
      tester,
    ) async {
      await open(tester);
      // A B flat instrument reads everything a tone up from concert.
      settings.setInstrument(ChartInstrument.bFlat);
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('drill-key')), contains('D'));
    });

    testWidgets('but the microphone still hears concert pitch', (tester) async {
      await open(tester);
      settings.setInstrument(ChartInstrument.bFlat);
      await tester.pumpAndSettle();
      await startListening(tester);
      // A B flat player reading E plays a concert D, which is what the
      // lick is written as and what the microphone hears.
      await play(tester, const [62]);
      expect(textOf(const ValueKey('drill-got')), '1 of 4');
    });
  });
}
