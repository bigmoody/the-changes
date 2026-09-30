// Bringing in a SoundFont, so the chords can be played by somebody else's
// piano.
//
// Pick a file, see what is in it, choose one sound. That is the whole
// screen, and the middle step is the reason it is a screen at all: a
// General MIDI font holds a hundred and twenty-eight instruments, and the
// file name says nothing about which of them somebody wants.
//
// The file is read on the phone and goes nowhere, like the iReal import
// and the MIDI parts. The app ships no fonts of its own: plenty of the
// good free ones carry licences that would have to be honoured one at a
// time, and a font somebody found is theirs and not ours.
//
// Only the chosen sound is kept (see instrument_file.dart). The .sf2 is
// let go as soon as this screen closes.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../audio/sample_bank.dart';
import '../audio/soundfont.dart';
import '../music/tune.dart' show Comping;
import '../practice/soundfont_store.dart';
import '../settings/app_settings.dart';
import 'tunes_page.dart' show SectionHeader;

class ImportSoundFontScreen extends StatefulWidget {
  const ImportSoundFontScreen({
    super.key,
    required this.store,
    this.settings,
    this.pick,
  });

  final SoundFontStore store;

  /// So that choosing a sound also puts it on. Without it the sound is
  /// kept and nothing plays it, which is a strange thing to do to
  /// somebody who has just chosen one.
  final AppSettings? settings;

  /// How a file is chosen. Tests hand in their own, because there is no
  /// picker to tap in a widget test.
  final Future<({String name, Uint8List bytes})?> Function()? pick;

  @override
  State<ImportSoundFontScreen> createState() => _ImportSoundFontScreenState();
}

class _ImportSoundFontScreenState extends State<ImportSoundFontScreen> {
  SoundFont? _font;
  String? _problem;
  var _busy = false;

  Future<({String name, Uint8List bytes})?> _pickFile() async {
    // Any file rather than only .sf2: the extension is not reliable on
    // every platform, and the reader says what is wrong far better than a
    // picker that silently offers nothing to choose.
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (bytes == null) return null;
    return (name: file!.name, bytes: bytes);
  }

  Future<void> _choose() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final picked = await (widget.pick ?? _pickFile)();
      if (!mounted) return;
      if (picked == null) {
        setState(() => _busy = false);
        return;
      }
      final font = SoundFont.read(picked.bytes, fileName: picked.name);
      setState(() {
        _busy = false;
        _font = font;
      });
    } on SoundFontException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = e.message;
      });
    }
  }

  Future<void> _keep(SoundFontPreset preset) async {
    final font = _font;
    if (font == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      // Reading the samples out is the slow part, and it happens once.
      final SampledInstrument instrument = font.instrumentFor(preset);
      await widget.store.keep(instrument);
      // And put it on. Anybody who has just picked a sound out of a file
      // wants to hear it, and leaving it to a second trip through Settings
      // makes the app look broken to everyone who does not make that trip.
      await widget.settings?.setComping(Comping.imported);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${instrument.name} will play the chords')),
      );
      navigator.pop();
    } on SoundFontException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final font = _font;
    return Scaffold(
      appBar: AppBar(title: const Text('Import a Sound')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'A SoundFont (.sf2) holds recorded instruments. Choose a '
                  'file and pick one sound from it, and the band will comp '
                  'with that instead of its own piano.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton.icon(
                  key: const ValueKey('choose-soundfont'),
                  onPressed: _busy ? null : _choose,
                  icon: const Icon(Icons.folder_open),
                  label: Text(
                    font == null ? 'Choose a File' : 'Choose Another',
                  ),
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_problem case final problem?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    problem,
                    key: const ValueKey('soundfont-problem'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ),
              if (font != null && !_busy) ...[
                SectionHeader(font.name),
                for (final preset in font.presets)
                  ListTile(
                    key: ValueKey('preset-${preset.index}'),
                    title: Text(preset.name),
                    subtitle: Text(
                      preset.isPercussion
                          ? 'A drum kit. The Changes plays its own drums.'
                          : 'Bank ${preset.bank}, program ${preset.program}',
                    ),
                    enabled: !preset.isPercussion,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: preset.isPercussion ? null : () => _keep(preset),
                  ),
              ],
              if (widget.store.name case final kept? when font == null) ...[
                const SectionHeader('Playing Now'),
                ListTile(
                  key: const ValueKey('kept-soundfont'),
                  leading: const Icon(Icons.graphic_eq),
                  title: Text(kept),
                  subtitle: const Text(
                    'Chosen under Chords Played By in Settings',
                  ),
                  trailing: TextButton(
                    key: const ValueKey('forget-soundfont'),
                    onPressed: widget.store.forget,
                    child: const Text('Remove'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
