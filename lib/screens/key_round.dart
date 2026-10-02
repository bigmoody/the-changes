// Going round the twelve keys: the parts both screens use.
//
// One lick taken round the keys and one set of changes taken round the
// keys are the same journey with different luggage, so the chips that
// show where you are and the menu that decides the route live here
// rather than twice.

import 'package:flutter/material.dart';

import '../music/key_order.dart';

/// The twelve keys, in the order they are coming, with the ones already
/// played marked.
class KeyChips extends StatelessWidget {
  const KeyChips({
    super.key,
    required this.moves,
    required this.label,
    required this.at,
    required this.done,
    required this.onPick,
  });

  /// How far each key is from [from], in the order they come.
  final List<int> moves;

  /// What to call the key [move] semitones along. Spelled rather than
  /// named by pitch class: a key is B flat or A sharp depending on where
  /// it came from, and "A♯/B♭" on a chip helps nobody.
  final String Function(int move) label;

  /// Which of [moves] is the one now.
  final int at;

  /// The moves already played all the way through.
  final Set<int> done;

  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (i, move) in moves.indexed)
          ChoiceChip(
            key: ValueKey('round-key-$move'),
            label: Text(label(move)),
            selected: i == at,
            avatar: done.contains(move)
                ? Icon(Icons.check, size: 16, color: scheme.tertiary)
                : null,
            onSelected: (_) => onPick(i),
          ),
      ],
    );
  }
}

/// The menu that picks the route round the keys.
class KeyOrderButton extends StatelessWidget {
  const KeyOrderButton({super.key, required this.order, required this.onPick});

  final KeyOrder order;
  final ValueChanged<KeyOrder> onPick;

  @override
  Widget build(BuildContext context) => PopupMenuButton<KeyOrder>(
    key: const ValueKey('key-order'),
    tooltip: 'The order the keys come in',
    initialValue: order,
    onSelected: onPick,
    itemBuilder: (context) => [
      for (final one in KeyOrder.values)
        PopupMenuItem(value: one, child: Text(one.label)),
    ],
  );
}

/// Back and Next, side by side at the foot of a round.
class KeyStep extends StatelessWidget {
  const KeyStep({super.key, required this.onBack, required this.onNext});

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: TextButton.icon(
            key: const ValueKey('previous-key'),
            icon: const Icon(Icons.chevron_left),
            label: const Text('Back'),
            onPressed: onBack,
          ),
        ),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.tonalIcon(
            key: const ValueKey('next-key'),
            icon: const Icon(Icons.chevron_right),
            label: const Text('Next Key'),
            onPressed: onNext,
          ),
        ),
      ),
    ],
  );
}
