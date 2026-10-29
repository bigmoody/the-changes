// Pause and Stop for anything that plays an example: a line, a lick, a
// scale, a chord, a ride pattern. Thirty-odd screens play one, and only a
// few had a way to stop it short, none a way to hold it.
//
// So it is one bar, laid over every screen from above the navigator,
// that shows while something is sounding and goes when it ends. The
// screens that light the note being played follow the snippet's own
// position, so a pause holds the lit note too.

import 'package:flutter/material.dart';

import '../audio/practice_player.dart';

class SnippetControls extends StatelessWidget {
  const SnippetControls({super.key, required this.player});

  final PracticePlayer player;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: player.snippetState,
    builder: (context, state, _) {
      final scheme = Theme.of(context).colorScheme;
      final paused = state == SnippetState.paused;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: state == SnippetState.idle
            ? const SizedBox.shrink()
            : Material(
                key: const ValueKey('snippet-controls'),
                color: scheme.inverseSurface,
                elevation: 4,
                shape: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Button(
                        key: const ValueKey('snippet-pause'),
                        icon: paused ? Icons.play_arrow : Icons.pause,
                        label: paused ? 'Play' : 'Pause',
                        color: scheme.onInverseSurface,
                        onPressed: paused
                            ? player.resumeSnippet
                            : player.pauseSnippet,
                      ),
                      _Button(
                        key: const ValueKey('snippet-stop'),
                        icon: Icons.stop,
                        label: 'Stop',
                        color: scheme.onInverseSurface,
                        onPressed: player.stopSnippet,
                      ),
                    ],
                  ),
                ),
              ),
      );
    },
  );
}

class _Button extends StatelessWidget {
  const _Button({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  // A labelled button rather than an icon with a tooltip: this sits above
  // the navigator, where there is no overlay for a tooltip to open in,
  // and a word is quicker to hit right with a horn in the other hand.
  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      foregroundColor: color,
      minimumSize: const Size(88, 48),
    ),
    icon: Icon(icon),
    label: Text(label),
    onPressed: onPressed,
  );
}
