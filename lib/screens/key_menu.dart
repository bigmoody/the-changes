// The key an exercise is in, chosen in the app bar: today's key to start
// with, and any of the twelve, because the point of the work is to have
// it in every key and not only in the one the day happened to give.

import 'package:flutter/material.dart';

/// The twelve keys round the cycle of fourths, the order a player works
/// through them in.
const exerciseKeys = [
  'C', 'F', 'B♭', 'E♭', 'A♭', 'D♭', 'G♭', 'B', 'E', 'A', 'D', 'G', //
];

const _sharps = {'C♯': 'D♭', 'D♯': 'E♭', 'F♯': 'G♭', 'G♯': 'A♭', 'A♯': 'B♭'};

/// [key]'s place in [exerciseKeys], reading a sharp as its flat.
int _place(String key) {
  final at = exerciseKeys.indexOf(_sharps[key] ?? key);
  return at < 0 ? 0 : at;
}

/// The key after [key] round the cycle.
String nextExerciseKey(String key) =>
    exerciseKeys[(_place(key) + 1) % exerciseKeys.length];

/// Semitones up from [from] to [to], as the nearest way round: -5 to 6.
int semitonesBetween(String from, String to) {
  // Round the cycle each step is a fourth, five semitones up.
  final up = (_place(to) - _place(from)) * 5 % 12;
  return up > 6 ? up - 12 : up;
}

/// "In F", with the twelve keys behind it, and a button on to the next.
class KeyMenu extends StatelessWidget {
  const KeyMenu({super.key, required this.keyName, required this.onChanged});

  final String keyName;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      PopupMenuButton<String>(
        key: const ValueKey('key-menu'),
        tooltip: 'Key',
        initialValue: _sharps[keyName] ?? keyName,
        onSelected: onChanged,
        itemBuilder: (_) => [
          for (final key in exerciseKeys)
            PopupMenuItem(value: key, child: Text('In $key')),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(child: Text('In $keyName')),
        ),
      ),
      IconButton(
        key: const ValueKey('key-next'),
        tooltip: 'Next key round the cycle',
        icon: const Icon(Icons.skip_next),
        onPressed: () => onChanged(nextExerciseKey(keyName)),
      ),
    ],
  );
}
