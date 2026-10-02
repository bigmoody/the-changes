// Saying what colour each key is.
//
// The companion to Chord Colours, and deliberately not the same screen.
// Those follow the root of every chord, so the colour moves bar to bar;
// this one does not move at all. A tune is the colour of its key from the
// title down, which is what a lot of people with chromesthesia actually
// have: the key is the thing that is coloured, not the single pitches.
//
// The two maps are kept apart because they disagree in real people.
// Somebody's C major is not necessarily their C, and asking once and
// using the answer twice would be inventing half of it.
//
// Twelve keys, with a switch that gives the minor keys their own. An
// unanswered minor follows the major on the same note, so the switch
// costs nothing to try and nothing to undo.

import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import '../settings/chord_colours.dart' show readableOn;
import '../settings/key_colours.dart';
import '../theme.dart';
import 'colour_picker.dart';

class KeyColoursScreen extends StatelessWidget {
  const KeyColoursScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colours = settings.keyColours;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Key Colours'),
        actions: [
          if (colours.isNotEmpty)
            TextButton(
              key: const ValueKey('clear-key-colours'),
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
                'If you see keys as colours, say what yours are and the tune '
                'will take the colour of the key it is in, wherever it is '
                'named. This is a separate question from Chord Colours, '
                'because the two are often different.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            SwitchListTile(
              key: const ValueKey('colour-keys'),
              secondary: const Icon(Icons.palette_outlined),
              title: const Text('Colour the Keys'),
              subtitle: const Text(
                'Turn them off without losing what you have set',
              ),
              value: settings.colourKeys,
              onChanged: settings.setColourKeys,
            ),
            SwitchListTile(
              key: const ValueKey('split-minor-keys'),
              secondary: const Icon(Icons.call_split),
              title: const Text('Major and Minor Apart'),
              subtitle: const Text(
                'Give C minor its own colour, rather than C major\'s',
              ),
              value: settings.splitMinorKeys,
              onChanged: settings.setSplitMinorKeys,
            ),
            const Divider(height: 1),
            for (final entry in _rows(settings.splitMinorKeys))
              _KeyRow(
                entry: entry,
                colours: colours,
                split: settings.splitMinorKeys,
                on: settings.colourKeys,
                onTap: () => _pick(context, entry),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                settings.splitMinorKeys
                    ? 'A minor key with no colour of its own follows the '
                          'major on the same note. The modal tunes count as '
                          'minor, because that is what they sound like: D '
                          'Dorian is a D minor tonic with a raised 6th.'
                    : 'A tune written for your instrument is coloured by the '
                          'key you are reading, not the key the band sounds '
                          'in, so the chart in front of you and its colour '
                          'agree.',
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
        title: const Text('Clear Every Key Colour?'),
        content: const Text(
          'Every key goes back to the usual ink, minor keys included. The '
          'chord colours are not touched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Them'),
          ),
          TextButton(
            key: const ValueKey('really-clear-key-colours'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (sure == true) await settings.clearKeyColours();
  }

  Future<void> _pick(BuildContext context, _Row row) async {
    final scheme = Theme.of(context).colorScheme;
    final colours = settings.keyColours;
    final inherited = row.minor ? colours.byKey[row.pitchClass] : null;
    final chosen = await pickColour(
      context,
      title: row.title,
      start: colours.of((
        pitchClass: row.pitchClass,
        minor: row.minor,
      ), split: settings.splitMinorKeys),
      // On a minor with none of its own, clearing is not asking for no
      // colour, it is asking to go back to the major.
      clearLabel: inherited == null ? 'No Colour' : 'Follow the Major',
      // The tune's title as it will appear over the chart, because that
      // is the biggest place this colour lands.
      preview: (colour) => Container(
        height: 76,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          'Key of ${row.title}',
          style: handLettered(
            TextStyle(fontSize: 26, color: readableOn(colour, scheme.surface)),
          ),
        ),
      ),
    );
    // Null is backing out; noColour is asking for none. Different answers.
    if (chosen == null) return;
    await settings.setKeyColour(
      row.pitchClass,
      chosen == noColour ? null : chosen,
      minor: row.minor,
    );
  }
}

/// One question on this screen: a key, and whether it is the minor one.
typedef _Row = ({String title, int pitchClass, bool minor});

extension on _Row {
  ValueKey<String> get key =>
      ValueKey(minor ? 'minor-key-$pitchClass' : 'key-$pitchClass');
}

/// Every row, up the chromatic scale. With the split on, each key is
/// followed by its minor, so the two that share a note are next to each
/// other and can be compared while they are chosen.
List<_Row> _rows(bool split) => [
  for (var pitch = 0; pitch < 12; pitch++) ...[
    (title: majorKeyNames[pitch], pitchClass: pitch, minor: false),
    if (split)
      (title: '${minorKeyNames[pitch]} minor', pitchClass: pitch, minor: true),
  ],
];

/// One key, with its name drawn as it will appear.
class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.entry,
    required this.colours,
    required this.split,
    required this.on,
    required this.onTap,
  });

  final _Row entry;
  final KeyColours colours;
  final bool split;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final key = (pitchClass: entry.pitchClass, minor: entry.minor);
    final colour = colours.of(key, split: split);
    final own = entry.minor
        ? colours.byMinorKey[entry.pitchClass] != null
        : colours.byKey[entry.pitchClass] != null;
    final shown = colour == null || !on
        ? scheme.onSurface
        : readableOn(colour, scheme.surface);
    return ListTile(
      key: entry.key,
      title: Text(entry.title),
      subtitle: Text(switch ((colour, own)) {
        (null, _) => 'The usual ink',
        (_, true) => 'Yours',
        // Borrowed from the major, which is worth saying rather than
        // letting somebody wonder why a row they never answered has a
        // colour in it.
        _ => 'Follows the major',
      }),
      leading: SizedBox(
        width: 52,
        child: Center(
          child: Text(
            entry.title,
            textAlign: TextAlign.center,
            style: handLettered(TextStyle(fontSize: 18, color: shown)),
          ),
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
