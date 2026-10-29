// Playing fast: what the people who can are actually doing, and how to
// get from a tempo you can play to one you cannot yet.
//
// Speed is the thing everybody hears first and understands least. It is
// mostly not fast fingers: it is feeling the time in bigger pieces,
// thinking in shapes rather than notes, aiming at a few notes and letting
// the rest go by, and being relaxed enough that nothing gets in the way.
// None of that is a secret, and all of it can be practised, which is what
// the second half of the page is for.

import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/arrangement.dart';
import '../music/swing.dart';
import '../music/tune_library.dart';
import '../practice/licks.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'practice_screen.dart';
import 'swing_screen.dart';

/// One thing fast players do, or one step of getting there.
typedef _Point = ({String title, String text});

const _whatTheyDo = <_Point>[
  (
    title: 'They Feel It in Two',
    text:
        'At 280 nobody counts four. The beat they feel is the half note: '
        'the hi-hat on 2 and 4 becomes a slow, wide pulse, and the foot goes '
        'half as fast as the tempo. A fast tune feels calmer from inside '
        'than it sounds from outside, because the pulse being followed is '
        'slow.',
  ),
  (
    title: 'They Think in Shapes, Not Notes',
    text:
        'Nobody chooses eight notes a second one at a time. A fast line is a '
        'handful of shapes already in the fingers (a 1 2 3 5, an enclosure, '
        'an arpeggio from the 3rd, a run down the bebop scale), joined '
        'together. The decision is which shape comes next, and that is a few '
        'decisions a bar, not eight.',
  ),
  (
    title: 'They Aim at Targets',
    text:
        'The notes that land on the beat, above all the beat where the chord '
        'changes, are the ones that are chosen: the 3rd or the 7th of the new '
        'chord. Everything between is the shape that gets there. Hit the '
        'targets and the line sounds right however much happens in between.',
  ),
  (
    title: 'They Simplify the Harmony',
    text:
        'At speed a ii–V is often played as the V alone, a bar of changes as '
        'one sound, and a turnaround as the key it turns around. Fewer '
        'chords means fewer decisions per second, and nobody listening can '
        'tell, because the band is still playing every chord underneath.',
  ),
  (
    title: 'Their Eighths Get Straighter',
    text:
        'The short eighth note stays about a tenth of a second long at any '
        'tempo, so as the beat gets shorter the swing flattens on its own. '
        'At a fast tempo the eighths are nearly even. Trying to swing hard at '
        '300 is one of the things that makes a fast line fall apart.',
  ),
  (
    title: 'They Play Less Than It Sounds Like',
    text:
        'A fast solo is not wall-to-wall eighths. Listen again: rests, long '
        'notes, two-bar phrases with air between them, a run, then '
        'nothing. The run is what you remember, but the space is what makes '
        'it possible to play.',
  ),
  (
    title: 'They Know the Tune Cold',
    text:
        'At 300 there is no time to work out where the changes are. Fast '
        'players are hearing a bar or two ahead, because the form and the '
        'changes are so well known that they do not have to be thought '
        'about. Speed on a tune you do not know is not possible; speed on '
        'one you know inside out often comes by itself.',
  ),
  (
    title: 'They Are Relaxed',
    text:
        'Speed comes from small, loose movements. On a horn that means less '
        'tonguing at speed (tongue the first note of a shape, slur the rest) '
        'and fingers close to the keys. On guitar, small pick strokes and '
        'fingers that stay near the frets. On piano, a loose wrist and the '
        'same fingering every time. On bass, a line that is simpler than at '
        'a medium tempo, so the time can be big. Tension is the speed limit.',
  ),
];

const _howToGetThere = <_Point>[
  (
    title: '1. Find Your Clean Tempo',
    text:
        'The fastest tempo you can play it perfectly three times in a row, '
        'relaxed, is where the work starts. Not the tempo you wish it was: '
        'practising mistakes at the tempo you want only teaches the '
        'mistakes.',
  ),
  (
    title: '2. Climb in Small Steps',
    text:
        'Four to eight beats a minute at a time, and only once the last '
        'tempo is clean. Start each day a little under yesterday\'s best: '
        'the hands are cold, and yesterday\'s top was yesterday\'s.',
  ),
  (
    title: '3. Three Up, One Down',
    text:
        'Go up a step three times, then back one and play it easily. The '
        'body learns a speed when it is not straining at it, so the step '
        'back is where the last three steps get kept.',
  ),
  (
    title: '4. Practise in Bursts',
    text:
        'At the tempo you are aiming for, play four notes and stop. Then '
        'eight. Then a bar. Then join two bars. Short, fast and right teaches '
        'more than long and slow and wrong by the end.',
  ),
  (
    title: '5. Change the Rhythm',
    text:
        'Play the line long-short, then short-long, then in groups of three. '
        'Every change puts the weight on a different pair of notes, so the '
        'fingers come to own each one rather than slurring through the hard '
        'ones.',
  ),
  (
    title: '6. Get the Time at Speed First',
    text:
        'With the band at the target tempo, play only quarter notes, then '
        'only the chord tones on beats 1 and 3. Get the time, the form and '
        'the targets solid at speed before there are any eighths in it.',
  ),
  (
    title: '7. Simplify, Then Fill In',
    text:
        'Chord tones on every beat first, then the shapes between them. At '
        'speed the targets are the line, and the rest is how you get from '
        'one to the next.',
  ),
  (
    title: '8. Listen Fast',
    text:
        'Sing along with fast records until you can follow every note: '
        'Charlie Parker\'s Ko-Ko, Clifford Brown\'s Cherokee, John Coltrane\'s '
        'Giant Steps. You cannot play at a speed you cannot yet hear at.',
  ),
  (
    title: '9. Stop at Tension',
    text:
        'If your shoulders, jaw or hands tighten, go back ten beats a minute. '
        'Tension is the speed limit, and pushing through it is how injuries '
        'start. Fast and relaxed is learned slowly and relaxed.',
  ),
];

class PlayingFastScreen extends StatefulWidget {
  const PlayingFastScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<PlayingFastScreen> createState() => _PlayingFastScreenState();
}

class _PlayingFastScreenState extends State<PlayingFastScreen> {
  /// The tempo the example line is playing at, while it plays.
  int? _hearing;
  Timer? _done;

  @override
  void dispose() {
    _done?.cancel();
    unawaited(widget.player.stopSnippet());
    super.dispose();
  }

  /// The same line over the same changes at [tempo], once, with the band.
  Future<void> _hear(int tempo) async {
    final bank = widget.player.samples;
    if (bank == null) return;
    if (_hearing == tempo) {
      setState(() => _hearing = null);
      await widget.player.stopSnippet();
      return;
    }
    setState(() => _hearing = tempo);
    _done?.cancel();
    final lick = licks.firstWhere((l) => l.name == 'Bebop Scale Down the V');
    final band = lickBand(
      lick,
      'F',
      tempo: tempo,
      times: 2,
      floor: 58,
      lickOn: (_) => true,
      ride: (bars) => ridePattern(tempo: tempo, at: swingAt(tempo), bars: bars),
    );
    await widget.player.playSnippet(
      renderSnippet(bank, band.notes, drums: band.drums, pianoRelease: 0.08),
    );
    // The button goes back to Play once the line has been played, or
    // stopped from the Pause and Stop bar: held, it stays as it is.
    _done = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (widget.player.snippetState.value != SnippetState.idle) return;
      timer.cancel();
      if (mounted && _hearing == tempo) setState(() => _hearing = null);
    });
  }

  void _ladder() {
    final cherokee = standards.firstWhere((t) => t.title == 'Cherokee');
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeScreen(
          tune: cherokee,
          player: widget.player,
          settings: widget.settings,
          // A clean tempo to start from, and four faster every chorus for
          // as long as it goes: the ladder, with the band climbing it.
          startAt: 140,
          arrangement: const Arrangement(ramp: TempoRamp(step: 4, climb: 100)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(text, style: handLettered(theme.textTheme.headlineSmall)),
    );
    Widget point(_Point p) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(p.text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
    Widget action({
      required Key key,
      required IconData icon,
      required String label,
      required String about,
      required VoidCallback onPressed,
    }) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.tonalIcon(
            key: key,
            icon: Icon(icon),
            label: Text(label),
            onPressed: onPressed,
          ),
          const SizedBox(height: 4),
          Text(
            about,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Playing Fast')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Speed is mostly not fast fingers. It is feeling the time in '
                'bigger pieces, thinking in shapes, aiming at a few notes, '
                'knowing the tune cold, and staying loose. All of it can be '
                'practised.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            heading('Hear It'),
            action(
              key: const ValueKey('fast-hear-slow'),
              icon: _hearing == 120 ? Icons.stop : Icons.play_arrow,
              label: 'The Line at 120',
              about:
                  'Down the bebop scale over a ii–V–I in F, twice, with the '
                  'band. Count four, and hear the swing in the eighths.',
              onPressed: () => _hear(120),
            ),
            action(
              key: const ValueKey('fast-hear-fast'),
              icon: _hearing == 260 ? Icons.stop : Icons.play_arrow,
              label: 'The Same Line at 260',
              about:
                  'Now feel the half note instead of the beat, and hear how '
                  'much straighter the eighths are. The notes are the same.',
              onPressed: () => _hear(260),
            ),
            heading('What Fast Players Are Doing'),
            for (final p in _whatTheyDo) point(p),
            heading('How to Get From Slow to Fast'),
            for (final p in _howToGetThere) point(p),
            heading('Try It'),
            action(
              key: const ValueKey('fast-ladder'),
              icon: Icons.trending_up,
              label: 'The Tempo Ladder on Cherokee',
              about:
                  'Cherokee from 140, the band four beats a minute faster '
                  'every chorus. Stop when it stops being clean, note the '
                  'tempo, and start a little under it tomorrow.',
              onPressed: _ladder,
            ),
            action(
              key: const ValueKey('fast-swing'),
              icon: Icons.graphic_eq,
              label: 'Swing at Speed',
              about:
                  'The Swing page: pick the fast tempos and hear the eighths '
                  'straighten out.',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SwingScreen(
                    player: widget.player,
                    settings: widget.settings,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
