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
  double get _formBeats => _controller.loop.lengthBeats.toDouble();

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

  @override
  Widget build(BuildContext context) {
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
          Card(
            child: ListTile(
              key: const ValueKey('current-part'),
              title: Text(already.name),
              subtitle: Text(
                '${already.bars(_beatsPerBar)} bars, '
                '${already.notes.length} notes, on the '
                '${already.voice.label.toLowerCase()}',
              ),
              trailing: TextButton(
                key: const ValueKey('remove-part'),
                onPressed: () {
                  _controller.setImportedPart(null);
                  Navigator.of(context).pop();
                },
                child: const Text('Remove'),
              ),
            ),
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
