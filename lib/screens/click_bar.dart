// A tempo and a click, where a lick with changes would have the band.
//
// A line saved without chords still needs something to be in time
// against, both to catch it and to work on it. This is that, and it is
// deliberately not the metronome screen: nobody wants dropout bars and
// subdivisions in the middle of learning a phrase.

import 'package:flutter/material.dart';

/// Tempo and a click, where a lick with changes would have the band.
class ClickBar extends StatelessWidget {
  const ClickBar({
    super.key,
    required this.tempo,
    required this.clicking,
    required this.onNudge,
    required this.onToggle,
  });

  final int tempo;
  final bool clicking;

  /// How far to move the tempo, not where to move it to. Two quick taps
  /// on the same button both read the tempo as it was drawn, so passing
  /// the answer rather than the step loses one of them.
  final ValueChanged<int> onNudge;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
    child: Row(
      children: [
        FilledButton.icon(
          key: const ValueKey('click-play'),
          icon: Icon(clicking ? Icons.stop : Icons.play_arrow),
          label: Text(clicking ? 'Stop' : 'Click'),
          onPressed: onToggle,
        ),
        const Spacer(),
        IconButton(
          key: const ValueKey('click-slower'),
          icon: const Icon(Icons.remove),
          tooltip: 'Slower',
          onPressed: () => onNudge(-5),
        ),
        Text(
          '$tempo BPM',
          key: const ValueKey('click-tempo'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          key: const ValueKey('click-faster'),
          icon: const Icon(Icons.add),
          tooltip: 'Faster',
          onPressed: () => onNudge(5),
        ),
      ],
    ),
  );
}
