// Putting real players in as the band.
//
// A recording made to the template is three files and three facts, and
// the three facts are the whole difficulty: no audio file says what tempo
// it was played at, what key it is in, or where bar 1 is. The template
// asks for them in writing for that reason, and asks for file names that
// carry them, so most of this screen is filled in before anyone types.
//
// What is not guessed is checked. Given the tempo, the length of the file
// says how many choruses are on it, and if that does not come out as a
// whole number then the tempo is wrong: a take labelled 120 that was
// really played at 124 puts the chart half a bar out by the last chorus,
// and nothing on screen would ever say why. So the app works out what the
// tempo must have been and offers it.
//
// The files are read on the phone and go nowhere. That is the pilot's
// first rule and it is worth saying on the screen it applies to.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/wav_file.dart';
import '../music/recorded_take.dart';
import '../music/tuning.dart';
import '../practice/practice_controller.dart';
import 'practice_sheets.dart';

/// The sheet for importing a take and looking at the ones already in.
Future<void> showImportRecording(
  BuildContext context,
  PracticeController controller,
) => practiceSheet(
  context,
  (context) => _ImportRecording(controller: controller),
);

/// A stem that has been chosen but not yet put in.
class _Chosen {
  const _Chosen({
    required this.fileName,
    required this.bytes,
    required this.audio,
  });
  final String fileName;
  final Uint8List bytes;
  final WavAudio audio;
}

class _ImportRecording extends StatefulWidget {
  const _ImportRecording({required this.controller});

  final PracticeController controller;

  @override
  State<_ImportRecording> createState() => _ImportRecordingState();
}

class _ImportRecordingState extends State<_ImportRecording> {
  final _chosen = <TakeStem, _Chosen>{};
  final _tempo = TextEditingController();
  var _key = 0;
  var _reading = false;
  String? _problem;
  var _named = false;
  final _name = TextEditingController();

  PracticeController get _controller => widget.controller;
  int get _beatsPerBar => _controller.tune.beatsPerBar;

  @override
  void initState() {
    super.initState();
    _key = _controller.tune.keyPitchClass;
  }

  @override
  void dispose() {
    _tempo.dispose();
    _name.dispose();
    super.dispose();
  }

  double get _bpm => double.tryParse(_tempo.text.trim()) ?? 0;

  /// The longest stem, which is what the take's length is measured by.
  double get _seconds => _chosen.values.fold(
    0.0,
    (most, chosen) => chosen.audio.seconds > most ? chosen.audio.seconds : most,
  );

  /// How many times round the form the recording goes, and whether the
  /// tempo it was given agrees with how long the file is.
  ///
  /// Worked out rather than asked for, and worked out in
  /// recorded_take.dart rather than here so that something can test it.
  ({int choruses, double exactly, double driftBeats, double impliedBpm})
  get _length => readTakeLength(
    seconds: _seconds,
    bpm: _bpm,
    bars: _controller.tune.barCount,
    beatsPerBar: _beatsPerBar,
  );

  bool get _ready => _chosen.isNotEmpty && _bpm > 0;

  Future<void> _choose() async {
    setState(() {
      _reading = true;
      _problem = null;
    });
    try {
      // Several at once, because the template delivers three files per
      // take and their names say which is which.
      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: true,
      );
      if (!mounted) return;
      if (picked == null || picked.files.isEmpty) {
        setState(() => _reading = false);
        return;
      }
      final problems = <String>[];
      for (final file in picked.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        final read = readTakeName(file.name);
        try {
          final audio = readWav(bytes);
          if (audio.channels > 2) {
            problems.add(
              '${file.name} has ${audio.channels} channels. The '
              'app plays mono and stereo.',
            );
            continue;
          }
          // Fill the first empty slot when the name does not say which.
          final stem =
              read.stem ??
              TakeStem.values
                  .where((value) => !_chosen.containsKey(value))
                  .firstOrNull;
          if (stem == null) {
            problems.add(
              '${file.name} has nowhere to go: all three stems '
              'are already chosen.',
            );
            continue;
          }
          _chosen[stem] = _Chosen(
            fileName: file.name,
            bytes: bytes,
            audio: audio,
          );
          if (read.bpm != null && _tempo.text.isEmpty) {
            _tempo.text = _plain(read.bpm!);
          }
          if (read.key != null) _key = read.key!;
          if (!_named) {
            _name.text = file.name.split('.').first;
            _named = true;
          }
        } on WavFormatException catch (e) {
          problems.add('${file.name}: ${e.message}');
        }
      }
      setState(() {
        _reading = false;
        _problem = problems.isEmpty ? null : problems.join('\n\n');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reading = false;
        _problem = 'Those files could not be read.';
      });
    }
  }

  Future<void> _add() async {
    final store = _controller.recordingStore;
    final ref = _controller.ref;
    if (store == null || ref == null || !_ready) return;
    setState(() => _reading = true);
    try {
      final id = store.newId();
      final files = <TakeStem, String>{};
      for (final entry in _chosen.entries) {
        files[entry.key] = await store.keep(id, entry.key, entry.value.bytes);
      }
      await store.add(
        ref,
        RecordedTake(
          name: _name.text.trim().isEmpty ? 'Take $id' : _name.text.trim(),
          files: files,
          bpm: _bpm,
          key: _key,
          bars: _controller.tune.barCount,
          choruses: _length.choruses,
          beatsPerBar: _beatsPerBar,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reading = false;
        _problem = 'That take could not be saved: $e';
      });
    }
  }

  static String _plain(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  /// The screen reads the controller and the store, so it has to listen to
  /// them: without this, importing a take leaves the list saying what it
  /// said before.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final takes = _controller.recordedTakes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Import a Recording', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          'Real players instead of the generated band, from a session '
          'recorded to the template. The files are read on this phone and '
          'go nowhere: nothing is uploaded, shared or published.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (!takes.isEmpty) ...[
          const SizedBox(height: 14),
          Text('In This Tune', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final take in takes.takes)
            _TakeRow(
              take: take,
              inUse: take.name == _controller.recordingInUse?.name,
              tempo: _controller.tempo,
              soundingKey: _controller.soundingKey,
              onRemove: () => _controller.recordingStore?.forget(
                _controller.ref!,
                take.name,
              ),
            ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            key: const ValueKey('choose-recording'),
            icon: _reading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open),
            label: Text(
              _chosen.isEmpty ? 'Choose the Stems' : 'Choose More Files',
            ),
            onPressed: _reading ? null : _choose,
          ),
        ),
        if (_problem case final problem?) ...[
          const SizedBox(height: 12),
          Text(
            problem,
            key: const ValueKey('recording-problem'),
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
          ),
        ],
        if (_chosen.isNotEmpty) ...[
          const SizedBox(height: 16),
          _StemList(
            chosen: _chosen,
            onRemove: (stem) => setState(() => _chosen.remove(stem)),
          ),
          const SizedBox(height: 14),
          _Facts(
            name: _name,
            tempo: _tempo,
            keyClass: _key,
            onKey: (value) => setState(() => _key = value),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
          _LengthCheck(
            bars: _controller.tune.barCount,
            length: _length,
            statedBpm: _bpm,
            onUseImplied: () => setState(
              () => _tempo.text = _length.impliedBpm.toStringAsFixed(2),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('add-recording'),
              onPressed: _ready && !_reading ? _add : null,
              child: const Text('Add This Take'),
            ),
          ),
        ],
      ],
    );
  }
}

/// The stems chosen so far, and which file went where.
class _StemList extends StatelessWidget {
  const _StemList({required this.chosen, required this.onRemove});

  final Map<TakeStem, _Chosen> chosen;
  final ValueChanged<TakeStem> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final stem in TakeStem.values)
          if (chosen[stem] case final file?)
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: ValueKey('stem-${stem.name}'),
                dense: true,
                title: Text(stem.label),
                subtitle: Text(
                  '${file.fileName}\n'
                  '${file.audio.seconds.toStringAsFixed(1)} s, '
                  '${file.audio.channels == 1 ? 'mono' : 'stereo'}, '
                  '${(file.audio.sampleRate / 1000).toStringAsFixed(1)} kHz',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  key: ValueKey('drop-${stem.name}'),
                  icon: const Icon(Icons.close),
                  tooltip: 'Take it out',
                  onPressed: () => onRemove(stem),
                ),
              ),
            ),
        if (chosen.length < TakeStem.values.length)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Missing: ${[for (final stem in TakeStem.values)
                if (!chosen.containsKey(stem)) stem.label.toLowerCase()].join(', ')}. A take can go in without all three, and plays '
              'with whatever is there.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// The facts no audio file carries.
class _Facts extends StatelessWidget {
  const _Facts({
    required this.name,
    required this.tempo,
    required this.keyClass,
    required this.onKey,
    required this.onChanged,
  });

  final TextEditingController name;
  final TextEditingController tempo;
  final int keyClass;
  final ValueChanged<int> onKey;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextField(
        key: const ValueKey('recording-name'),
        controller: name,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Name',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => onChanged(),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('recording-tempo'),
              controller: tempo,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Tempo',
                helperText: 'The click, not an estimate',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<int>(
              key: const ValueKey('recording-key'),
              initialValue: keyClass,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Key',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                for (var pitch = 0; pitch < 12; pitch++)
                  DropdownMenuItem(
                    value: pitch,
                    child: Text(pitchClassName(pitch)),
                  ),
              ],
              onChanged: (value) => onKey(value ?? keyClass),
            ),
          ),
        ],
      ),
    ],
  );
}

/// What the length of the file says about the tempo it was played at.
class _LengthCheck extends StatelessWidget {
  const _LengthCheck({
    required this.bars,
    required this.length,
    required this.statedBpm,
    required this.onUseImplied,
  });

  final int bars;
  final ({int choruses, double exactly, double driftBeats, double impliedBpm})
  length;
  final double statedBpm;
  final VoidCallback onUseImplied;

  /// Half a beat out by the end of the take is where it starts to show.
  bool get _off => length.driftBeats > 0.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (statedBpm <= 0) {
      return Text(
        'Put the tempo in and the app will work out how many choruses are '
        'on the recording, and say whether the file agrees.',
        key: const ValueKey('length-waiting'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${length.choruses} '
          '${length.choruses == 1 ? 'chorus' : 'choruses'} of $bars bars',
          key: const ValueKey('length-verdict'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 2),
        Text(
          _off
              ? 'At ${statedBpm.toStringAsFixed(statedBpm % 1 == 0 ? 0 : 2)} '
                    'that is ${length.driftBeats.toStringAsFixed(1)} beats '
                    'out by the end, so the tempo is probably not quite '
                    'right. The file works out at '
                    '${length.impliedBpm.toStringAsFixed(2)}.'
              : 'The file is exactly as long as that, so the tempo agrees.',
          key: const ValueKey('length-detail'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: _off ? scheme.error : scheme.onSurfaceVariant,
          ),
        ),
        if (_off)
          TextButton(
            key: const ValueKey('use-implied-tempo'),
            onPressed: onUseImplied,
            child: Text('Use ${length.impliedBpm.toStringAsFixed(2)}'),
          ),
      ],
    );
  }
}

/// One take that is already in, and what playing it here would cost.
class _TakeRow extends StatelessWidget {
  const _TakeRow({
    required this.take,
    required this.inUse,
    required this.tempo,
    required this.soundingKey,
    required this.onRemove,
  });

  final RecordedTake take;
  final bool inUse;
  final int tempo;
  final int soundingKey;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shift = take.shiftTo(tempo: tempo, soundingKey: soundingKey);
    final move = take.moveTo(soundingKey);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: ValueKey('take-${take.name}'),
        dense: true,
        leading: Icon(
          inUse ? Icons.graphic_eq : Icons.radio_button_unchecked,
          color: inUse ? scheme.tertiary : scheme.onSurfaceVariant,
        ),
        title: Text(take.name),
        subtitle: Text(
          '${pitchClassName(take.key)} at '
          '${take.bpm.toStringAsFixed(take.bpm % 1 == 0 ? 0 : 2)}, '
          '${take.choruses} choruses, '
          '${take.files.length} ${take.files.length == 1 ? 'stem' : 'stems'}'
          '\nHere: ${move == 0 ? 'same key' : '${move.abs()} '
                    'semitone${move.abs() == 1 ? '' : 's'} '
                    '${move > 0 ? 'up' : 'down'}'}, '
          '${shift.stretchPercent.abs() < 0.5 ? 'same tempo' : '${shift.stretchPercent.abs().round()}% '
                    '${shift.stretchPercent > 0 ? 'faster' : 'slower'}'}. '
          '${shift.strain.label}, ${shift.cents.round()} cents.',
        ),
        isThreeLine: true,
        trailing: IconButton(
          key: ValueKey('forget-${take.name}'),
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Take it out',
          onPressed: onRemove,
        ),
      ),
    );
  }
}
