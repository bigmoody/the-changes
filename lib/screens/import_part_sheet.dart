// Putting a MIDI file in as an extra part.
//
// The file is read on the phone and nothing leaves it. What comes back is
// a list of the parts in it, because a file exported from a DAW usually
// holds the whole arrangement and only one track of it is wanted here.
//
// The choice is deliberately two things and not more: which part, and
// which instrument plays it. Everything else the app already knows. The
// notes are in beats, so the tempo is the tempo you are playing at, and
// the key is the key you have transposed to.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../music/imported_part.dart';
import '../music/midi_file.dart';
import '../practice/practice_controller.dart';
import 'practice_sheets.dart';

/// The sheet for choosing a file and a part out of it.
Future<void> showImportPart(
  BuildContext context,
  PracticeController controller,
) => practiceSheet(context, (context) => _ImportPart(controller: controller));

class _ImportPart extends StatefulWidget {
  const _ImportPart({required this.controller});

  final PracticeController controller;

  @override
  State<_ImportPart> createState() => _ImportPartState();
}

class _ImportPartState extends State<_ImportPart> {
  MidiFile? _file;
  String? _fileName;
  String? _problem;
  var _reading = false;

  PracticeController get _controller => widget.controller;
  int get _beatsPerBar => _controller.tune.beatsPerBar;

  /// The tune's whole form, not whatever is looped at the moment. A part
  /// is laid along the tune, so "longer than the form" has to mean longer
  /// than the tune: measured against a two-bar loop, every part ever
  /// imported would be too long.
  double get _formBeats =>
      (_controller.tune.barCount * _beatsPerBar).toDouble();

  Future<void> _choose() async {
    setState(() {
      _reading = true;
      _problem = null;
    });
    try {
      // Any file rather than only .mid: the extension is not reliable on
      // every platform, and the reader says what is wrong far better than
      // a picker that silently offers nothing to choose.
      final picked = await FilePicker.platform.pickFiles(withData: true);
      final file = picked?.files.singleOrNull;
      final bytes = file?.bytes;
      if (!mounted) return;
      if (bytes == null) {
        setState(() => _reading = false);
        return;
      }
      final read = readMidiFile(bytes);
      setState(() {
        _reading = false;
        _file = read;
        _fileName = file?.name;
        _problem = read.pitched.isEmpty
            ? 'There is nothing in this file the app can play. It may hold '
                  'only drums, or only tempo and time signature.'
            : null;
      });
    } on MidiFormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _reading = false;
        _file = null;
        _problem = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reading = false;
        _file = null;
        _problem = 'That file could not be read.';
      });
    }
  }

  void _take(MidiPart part) {
    _controller.setImportedPart(
      ImportedPart.of(
        part,
        beatsPerBar: _beatsPerBar,
        voice: suggestedVoice(part),
      ),
    );
    Navigator.of(context).pop();
  }

  /// The part being shown lives on the controller, so the sheet has to
  /// listen to it: without this, nudging the start changes what the band
  /// plays and leaves the panel saying what it said before.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final already = _controller.importedPart;
    final file = _file;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Import a Part', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          'A MIDI file plays as an extra part beside the band, on the piano, '
          'the guitar or the bass. It follows the tempo and the key you are '
          'playing in, because it is notes rather than a recording. The file '
          'is read on this phone and goes nowhere.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (already != null) ...[
          const SizedBox(height: 14),
          _PartPanel(
            part: already,
            bars: _controller.tune.barCount,
            beatsPerBar: _beatsPerBar,
            onChanged: _controller.setImportedPart,
            onRemove: () {
              _controller.setImportedPart(null);
              Navigator.of(context).pop();
            },
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            key: const ValueKey('choose-midi'),
            icon: _reading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open),
            label: Text(
              already == null ? 'Choose a MIDI File' : 'Choose Another File',
            ),
            onPressed: _reading ? null : _choose,
          ),
        ),
        if (_problem case final problem?) ...[
          const SizedBox(height: 12),
          Text(
            problem,
            key: const ValueKey('import-problem'),
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
          ),
        ],
        if (file != null && file.pitched.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            _fileName == null ? 'In this file' : 'In $_fileName',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            'Pick the one to play. The app guesses the instrument from where '
            'the part sits; you can change it in the mixer.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          for (final part in file.pitched)
            _PartRow(
              part: part,
              beatsPerBar: _beatsPerBar,
              formBeats: _formBeats,
              onTake: () => _take(part),
            ),
          if (file.parts.any((part) => part.isDrums)) ...[
            const SizedBox(height: 10),
            Text(
              'The drum track in this file is not offered: General MIDI '
              'numbers each drum differently from the app, so it would come '
              'out as the wrong kit.',
              key: const ValueKey('drums-note'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// One part of the file, with enough about it to choose by.
class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.part,
    required this.beatsPerBar,
    required this.formBeats,
    required this.onTake,
  });

  final MidiPart part;
  final int beatsPerBar;
  final double formBeats;
  final VoidCallback onTake;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final built = ImportedPart.of(part, beatsPerBar: beatsPerBar);
    final bars = built.bars(beatsPerBar);
    final overruns = built.overrunsForm(formBeats);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: ValueKey('part-${part.track}-${part.channel}'),
        title: Text(built.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$bars ${bars == 1 ? 'bar' : 'bars'}, ${part.notes.length} '
              'notes, probably the ${suggestedVoice(part).label.toLowerCase()}',
            ),
            if (overruns)
              Text(
                'Longer than the form, so it is cut off at the end of every '
                'chorus.',
                key: ValueKey('overruns-${part.track}-${part.channel}'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
        isThreeLine: overruns,
        trailing: const Icon(Icons.add),
        onTap: onTake,
      ),
    );
  }
}

/// The part that is in, with the two things that decide where it lands.
///
/// Nothing in a MIDI file says where the music starts or how long it is
/// before it comes round, so both are guesses until somebody looks. The
/// strip underneath is that look: it draws the part against the bars of
/// the tune, which is the only way to tell a count-in from a pick-up from
/// a file that was simply written somewhere else.
class _PartPanel extends StatelessWidget {
  const _PartPanel({
    required this.part,
    required this.bars,
    required this.beatsPerBar,
    required this.onChanged,
    required this.onRemove,
  });

  final ImportedPart part;
  final int bars;
  final int beatsPerBar;
  final ValueChanged<ImportedPart> onChanged;
  final VoidCallback onRemove;

  /// "As written", "1 bar earlier", "2 beats later".
  String get _whereItStarts {
    final beats = part.offsetBeats;
    if (beats == 0) return 'As written';
    final away = beats.abs();
    final word = beats < 0 ? 'earlier' : 'later';
    if (away % beatsPerBar == 0) {
      final inBars = (away / beatsPerBar).round();
      return '$inBars ${inBars == 1 ? 'bar' : 'bars'} $word';
    }
    return '${_plain(away)} ${away == 1 ? 'beat' : 'beats'} $word';
  }

  static String _plain(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final repeatBars = part.bars(beatsPerBar);
    Widget row(String label, String value, List<Widget> buttons) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(label, style: theme.textTheme.titleSmall),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          ...buttons,
        ],
      ),
    );
    Widget nudge(String tooltip, IconData icon, Key key, VoidCallback? go) =>
        IconButton.outlined(
          key: key,
          icon: Icon(icon, size: 18),
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          onPressed: go,
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(part.name, style: theme.textTheme.titleMedium),
                ),
                TextButton(
                  key: const ValueKey('remove-part'),
                  onPressed: onRemove,
                  child: const Text('Remove'),
                ),
              ],
            ),
            Text(
              '${part.notes.length} notes',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<PartVoice>(
              key: const ValueKey('imported-voice'),
              showSelectedIcon: false,
              segments: [
                for (final voice in PartVoice.values)
                  ButtonSegment(value: voice, label: Text(voice.label)),
              ],
              selected: {part.voice},
              onSelectionChanged: (value) =>
                  onChanged(part.withVoice(value.first)),
            ),
            row('Starts', _whereItStarts, [
              nudge(
                'A beat earlier',
                Icons.chevron_left,
                const ValueKey('start-earlier'),
                () => onChanged(part.movedTo(part.offsetBeats - 1)),
              ),
              const SizedBox(width: 4),
              nudge(
                'A beat later',
                Icons.chevron_right,
                const ValueKey('start-later'),
                () => onChanged(part.movedTo(part.offsetBeats + 1)),
              ),
            ]),
            row('Repeats', '$repeatBars ${repeatBars == 1 ? 'bar' : 'bars'}', [
              nudge(
                'A bar shorter',
                Icons.remove,
                const ValueKey('repeat-shorter'),
                repeatBars <= 1
                    ? null
                    : () => onChanged(
                        part.repeatingEvery(
                          part.lengthBeats - beatsPerBar,
                          beatsPerBar: beatsPerBar,
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              nudge(
                'A bar longer',
                Icons.add,
                const ValueKey('repeat-longer'),
                () => onChanged(
                  part.repeatingEvery(
                    part.lengthBeats + beatsPerBar,
                    beatsPerBar: beatsPerBar,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Text(
              'Against the chart',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.tertiary,
              ),
            ),
            const SizedBox(height: 4),
            _OverTheForm(part: part, bars: bars, beatsPerBar: beatsPerBar),
            const SizedBox(height: 4),
            Text(
              'A block is a bar the part plays in. The marked bars are where '
              'it starts again.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The part drawn against the bars of the tune: one cell a bar, taller
/// where more of the part falls in it, marked where it comes round.
class _OverTheForm extends StatelessWidget {
  const _OverTheForm({
    required this.part,
    required this.bars,
    required this.beatsPerBar,
  });

  final ImportedPart part;
  final int bars;
  final int beatsPerBar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final counts = part.notesByBar(bars: bars, beatsPerBar: beatsPerBar);
    final repeats = part.repeatsAt(bars: bars, beatsPerBar: beatsPerBar);
    final busiest = counts.fold(0, (most, n) => n > most ? n : most);
    return SizedBox(
      height: 34,
      child: Row(
        key: const ValueKey('over-the-form'),
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (bar, count) in counts.indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: busiest == 0
                          ? 2
                          : 2 + 26 * (count / busiest).clamp(0, 1),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: count == 0
                              ? scheme.onSurface.withValues(alpha: 0.12)
                              : scheme.onSurface.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(1),
                        ),
                        child: const SizedBox(width: double.infinity),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: repeats.contains(bar)
                              ? scheme.tertiary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(1),
                        ),
                        child: const SizedBox(width: double.infinity),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
