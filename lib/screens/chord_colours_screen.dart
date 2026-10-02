// Saying what colour each root is.
//
// For people with chromesthesia, who already see pitches in colour and for
// whom a chart in the wrong colours is worse than a chart in none. There
// is no palette to choose from, because there is no palette to choose
// from: the colours belong to the person and ours would be somebody
// else's guess at them.
//
// So a colour picker, with the chord shown as it will actually appear on
// the paper while the colour moves. Pointing at the colour you mean is
// the whole idea.
//
// Twelve roots to begin with, because twelve is what most people have and
// seventeen questions is a lot to ask to find out. But plenty of people do
// see C♯ and D♭ apart, since what they see is attached to the written
// letter as much as to the sound, so there is a switch that splits them.
// An unanswered spelling follows the pitch under it, which means the
// switch costs nothing to try and nothing to undo.

import 'package:flutter/material.dart';

import '../music/chord.dart';
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
                'app will use them: on the chart, on the tuner, on the '
                'stave and wherever a note is named. A chord takes the '
                'colour of its root, so a D7 and a Dm9 are both D.',
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
            SwitchListTile(
              key: const ValueKey('split-enharmonics'),
              secondary: const Icon(Icons.call_split),
              title: const Text('Sharps and Flats Apart'),
              subtitle: const Text(
                'Give C♯ and D♭ their own colours, if you see them apart',
              ),
              value: settings.splitEnharmonics,
              onChanged: settings.setSplitEnharmonics,
            ),
            const Divider(height: 1),
            for (final entry in _rows(settings.splitEnharmonics))
              _RootRow(
                entry: entry,
                colours: colours,
                split: settings.splitEnharmonics,
                on: settings.colourChords,
                onTap: () => _pick(context, entry),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                settings.splitEnharmonics
                    ? 'A spelling with no colour of its own follows the '
                          'pitch under it, so nothing goes black while you '
                          'fill these in. A colour is lifted or dropped only '
                          'as far as it has to be to be read on the paper, '
                          'which leaves the hue alone.'
                    : 'A colour is lifted or dropped only as far as it has '
                          'to be to be read on the paper, which leaves the '
                          'hue alone. That is why a very dark one looks '
                          'lighter in the dark theme.',
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
          'Every one goes back to the chart\'s own ink, spellings '
          'included. Nothing else changes.',
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

  Future<void> _pick(BuildContext context, _Row row) async {
    final scheme = Theme.of(context).colorScheme;
    final colours = settings.chordColours;
    final inherited = row.note == null
        ? null
        : colours.of(pitchClassOf(row.note!));
    final chosen = await pickColour(
      context,
      title: row.title,
      start: row.colourIn(colours, split: settings.splitEnharmonics),
      // On a spelling that has none of its own, clearing is not asking for
      // no colour, it is asking to go back to the pitch underneath. Saying
      // "No Colour" there would be a lie about what the button does.
      clearLabel: inherited == null ? 'No Colour' : 'Follow the Pitch',
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
          handSymbol('${row.root}Δ7'),
          style: handLettered(
            TextStyle(fontSize: 34, color: readableOn(colour, scheme.surface)),
          ),
        ),
      ),
    );
    // Null is backing out; noColour is asking for none. Different answers.
    if (chosen == null) return;
    final wanted = chosen == noColour ? null : chosen;
    if (row.note case final note?) {
      await settings.setChordColourForNote(note, wanted);
    } else {
      await settings.setChordColour(row.pitch!, wanted);
    }
  }
}

/// One question on this screen: a pitch, or one written spelling of it.
///
/// A natural is always a pitch, because it has only the one spelling and
/// splitting it would be asking the same question twice.
typedef _Row = ({String title, String root, int? pitch, Spelling? note});

extension on _Row {
  /// What this row will actually draw with, following the pitch when the
  /// spelling has nothing of its own.
  Color? colourIn(ChordColours colours, {required bool split}) => note == null
      ? colours.of(pitch!)
      : colours.ofSpelling(note!, split: split);

  /// Whether the colour shown is this row's own answer or borrowed from
  /// the pitch under it.
  bool ownIn(ChordColours colours) => note == null
      ? colours.of(pitch!) != null
      : colours.bySpelling[note!] != null;

  /// What a test taps, and what a test looks for.
  ValueKey<String> get key =>
      ValueKey(note == null ? 'root-$pitch' : 'spelling-$root');
}

/// Every row, in the order somebody reading a keyboard would meet them.
List<_Row> _rows(bool split) {
  if (!split) {
    return [
      for (var pitch = 0; pitch < 12; pitch++)
        (
          title: pitchClassNames[pitch],
          root: roots[pitch],
          pitch: pitch,
          note: null,
        ),
    ];
  }
  final rows = <_Row>[];
  for (var pitch = 0; pitch < 12; pitch++) {
    final spellings = [
      for (final note in accidentalSpellings)
        if (pitchClassOf(note) == pitch) note,
    ];
    if (spellings.isEmpty) {
      // A white key: one name, one question, exactly as before.
      rows.add((
        title: pitchClassNames[pitch],
        root: roots[pitch],
        pitch: pitch,
        note: null,
      ));
      continue;
    }
    for (final note in spellings) {
      final name = noteNameOf(note);
      rows.add((title: name, root: name, pitch: null, note: note));
    }
  }
  return rows;
}

/// One root, with the chord drawn as it will appear.
class _RootRow extends StatelessWidget {
  const _RootRow({
    required this.entry,
    required this.colours,
    required this.split,
    required this.on,
    required this.onTap,
  });

  final _Row entry;
  final ChordColours colours;
  final bool split;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = entry.colourIn(colours, split: split);
    final shown = colour == null || !on
        ? scheme.onSurface
        : readableOn(colour, scheme.surface);
    return ListTile(
      key: entry.key,
      title: Text(entry.title),
      subtitle: Text(switch ((colour, entry.ownIn(colours))) {
        (null, _) => 'The chart\'s own ink',
        (_, true) => 'Yours',
        // Borrowed from the pitch, which is worth saying rather than
        // letting somebody wonder why a row they never answered has a
        // colour in it.
        _ => 'Follows the pitch',
      }),
      leading: SizedBox(
        width: 44,
        child: Center(
          child: Text(
            // The root as a chord, in its colour, which is the only
            // preview worth having.
            handSymbol('${entry.root}7'),
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
