// One place a mode is heard, shared by Scales & Modes and the Practice tab.

import 'package:flutter/material.dart';

import '../music/mode_examples.dart';

/// One place the mode is heard. A tune in the library opens with the
/// band; a song from outside it is only named.
class ModeExampleRow extends StatelessWidget {
  const ModeExampleRow({
    super.key,
    required this.example,
    required this.onTune,
  });

  final ModeExample example;
  final ValueChanged<String> onTune;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tune = example.tune;
    final text = Text.rich(
      TextSpan(
        children: [
          if (tune != null)
            TextSpan(
              text: switch (keyOfTune(tune)) {
                final key? => '$tune (in $key): ',
                null => '$tune: ',
              },
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          TextSpan(text: example.text),
        ],
      ),
      style: theme.textTheme.bodyMedium,
    );
    if (tune == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Icon(
                Icons.music_note_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Expanded(child: text),
          ],
        ),
      );
    }
    return InkWell(
      key: ValueKey('mode-example-$tune'),
      onTap: () => onTune(tune),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Icon(
                Icons.play_circle_outline,
                size: 18,
                color: theme.colorScheme.primary,
                semanticLabel: 'Play $tune',
              ),
            ),
            Expanded(child: text),
          ],
        ),
      ),
    );
  }
}
