// The stage: the chart and nothing else.
//
// A phone on a stand, read from a metre away, with an instrument in your
// hands. Everything you'd tap while working on a tune (the mixer, the
// arrangement, the loop, the transposition) is settled before you get
// here, so none of it is on screen. What's left is the chart, as big as
// the screen can draw it, and a way to start and stop.
//
// It plays the same band as the screen you came from: the same controller,
// so walking in and out of the stage doesn't interrupt anything.
//
// A tap anywhere on the chart starts or stops it, because reaching for a
// small button with a horn in your mouth is the thing this view is for.
// That's also why a tap here doesn't set a loop the way it does while
// you're practising: nobody wants to change what the band is playing by
// touching the screen to get it going.
//
// There are two of it. Stage View is the whole tune fitted to the screen.
// Scrolling Stage View is a few rows at a time, big, moving on as the band
// moves down the tune, so the line being played is near the top and what
// comes next is under it: a long chart fitted to a phone is too small to
// read from a stand, and nobody can scroll it with a horn in their hands.

import 'package:flutter/material.dart';

import '../practice/practice_controller.dart';
import '../theme.dart';
import 'chord_chart.dart' show ChordChart, CountInBubble;
import 'play_shortcuts.dart';

class StageScreen extends StatelessWidget {
  const StageScreen({super.key, required this.controller, this.follow = false});

  final PracticeController controller;

  /// The scrolling stage: a few big rows that move on with the band,
  /// rather than the whole tune fitted to the screen.
  final bool follow;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    // The spacebar as well as the whole chart. On a stand a metre away a
    // keyboard may be the only thing within reach.
    builder: (context, _) => PlayPauseShortcut(
      onPlayPause: controller.togglePlay,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('stage-chart'),
                  behavior: HitTestBehavior.opaque,
                  onTap: controller.togglePlay,
                  child: Stack(
                    children: [
                      ChordChart(
                        controller: controller,
                        stage: true,
                        follow: follow,
                      ),
                      if (controller.countInBeat != null)
                        CountInBubble(beat: controller.countInBeat!),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              _StageBar(controller: controller),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The one strip of controls: what's playing, whether it's playing, and the
/// way out.
class _StageBar extends StatelessWidget {
  const _StageBar({required this.controller});

  final PracticeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playing = controller.isPlaying && !controller.isPaused;
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton.filled(
              key: const ValueKey('stage-play'),
              iconSize: 32,
              style: filledIconButton(theme.colorScheme),
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              tooltip: playing ? 'Stop' : 'Play',
              onPressed: controller.togglePlay,
            ),
            const SizedBox(width: 12),
            // The chart says where you are; this says what you're on, big
            // enough to catch out of the corner of an eye.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  handSymbol(controller.shownSlot.chord.display),
                  semanticsLabel: controller.shownSlot.chord.display,
                  style: handLettered(
                    TextStyle(
                      fontSize: 34,
                      height: 1,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            Text(
              '${controller.currentTempo} BPM',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            IconButton(
              key: const ValueKey('stage-done'),
              icon: const Icon(Icons.close_fullscreen),
              tooltip: 'Leave the Stage',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
