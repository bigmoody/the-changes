// Saying what colour each root is.
//
// For people with chromesthesia, who already see pitches in colour and for
// whom a chart in the wrong colours is worse than a chart in none. There
// is no palette to choose from, because there is no palette to choose
// from: the colours belong to the person and ours would be somebody
// else's guess at them.
//
// So a hue, a depth and a brightness, with the chord shown as it will
// actually appear on the paper while the sliders move. Three numbers is
// not as nice as pointing at the colour you mean, but it does reach every
// colour, which a grid of swatches does not, and that is the whole point.
//
// Twelve roots, not twenty-one: C♯ and D♭ are one pitch and share an
// entry. Somebody who sees those two differently has a real complaint and
// it would be a second map rather than a different idea.

import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import '../settings/chord_colours.dart';
import '../theme.dart';
import 'colour_picker.dart';

class ChordColoursScreen extends StatelessWidget {
  const ChordColoursScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colours = settings.chordColours;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chord Colours'),
        actions: [
          if (colours.isNotEmpty)
            TextButton(
              key: const ValueKey('clear-colours'),
              onPressed: () => _clear(context),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'If you see pitches as colours, say what yours are and the '
                'chart will use them. A chord takes the colour of its root, '
                'so a D7 and a Dm9 are both D.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            SwitchListTile(
              key: const ValueKey('colour-chords'),
              secondary: const Icon(Icons.palette_outlined),
              title: const Text('Colour the Chords'),
              subtitle: const Text(
                'Turn them off without losing what you have set',
              ),
              value: settings.colourChords,
              onChanged: settings.setColourChords,
            ),
            const Divider(height: 1),
            for (var pitch = 0; pitch < 12; pitch++)
              _RootRow(
                pitch: pitch,
                colour: colours.of(pitch),
                on: settings.colourChords,
                onTap: () => _pick(context, pitch),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'A colour is lifted or dropped only as far as it has to be '
                'to be read on the paper, which leaves the hue alone. That '
                'is why a very dark one looks lighter in the dark theme.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clear(BuildContext context) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Every Colour?'),
        content: const Text(
          'All twelve go back to the chart\'s own ink. Nothing else '
          'changes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Them'),
          ),
          TextButton(
            key: const ValueKey('really-clear-colours'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (sure == true) await settings.clearChordColours();
  }

  Future<void> _pick(BuildContext context, int pitch) async {
    final scheme = Theme.of(context).colorScheme;
    final chosen = await pickColour(
      context,
      title: pitchClassNames[pitch],
      start: settings.chordColours.of(pitch),
      clearLabel: 'No Colour',
      // On the paper, at the size a chart draws it, because the only
      // questions are whether it is your colour and whether you can read
      // it.
      preview: (colour) => Container(
        height: 76,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          handSymbol('${roots[pitch]}Δ7'),
          style: handLettered(
            TextStyle(fontSize: 34, color: readableOn(colour, scheme.surface)),
          ),
        ),
      ),
    );
    // Null is backing out; noColour is asking for none. Different answers.
    if (chosen == null) return;
    await settings.setChordColour(pitch, chosen == noColour ? null : chosen);
  }
}

/// One root, with the chord drawn as it will appear.
class _RootRow extends StatelessWidget {
  const _RootRow({
    required this.pitch,
    required this.colour,
    required this.on,
    required this.onTap,
  });

  final int pitch;
  final Color? colour;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = colour == null || !on
        ? scheme.onSurface
        : readableOn(colour!, scheme.surface);
    return ListTile(
      key: ValueKey('root-$pitch'),
      title: Text(pitchClassNames[pitch]),
      subtitle: Text(colour == null ? 'The chart\'s own ink' : 'Yours'),
      leading: SizedBox(
        width: 44,
        child: Center(
          child: Text(
            // The root as a chord, in its colour, which is the only
            // preview worth having.
            handSymbol('${roots[pitch]}7'),
            style: handLettered(TextStyle(fontSize: 22, color: shown)),
          ),
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// How to write each root in the preview: the common spelling, flats
/// where a chart would use them.
const roots = ['C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B'];
