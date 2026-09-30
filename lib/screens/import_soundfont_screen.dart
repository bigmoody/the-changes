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
import '../music/tune.dart' show BassSound, Comping, DrumSound;
import '../audio/imported_kit.dart';
import '../practice/soundfont_store.dart';
import '../settings/app_settings.dart';
import 'tunes_page.dart' show SectionHeader;

class ImportSoundFontScreen extends StatefulWidget {
  const ImportSoundFontScreen({
    super.key,
    required this.store,
    this.role = SoundFontRole.chords,
    this.settings,
    this.pick,
  });

  final SoundFontStore store;

  /// What the sound being chosen is for. The chords and the bass keep
  /// their own, because they are two different files.
  final SoundFontRole role;

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
      final String what;
      if (widget.role == SoundFontRole.drums) {
        final kit = kitFromGeneralMidi(font.drumKitFor(preset));
        if (kit.isEmpty) {
          setState(() {
            _busy = false;
            _problem =
                '${preset.name} has no drums where the General MIDI map '
                'puts them, so the band would not know what to hit.';
          });
          return;
        }
        await widget.store.keepKit(preset.name, kit);
        await widget.settings?.setDrumSound(DrumSound.imported);
        what = 'the drums';
      } else {
        final SampledInstrument instrument = font.instrumentFor(preset);
        await widget.store.keep(widget.role, instrument);
        // And put it on. Anybody who has just picked a sound out of a file
        // wants to hear it, and leaving it to a second trip through
        // Settings makes the app look broken to everyone who does not make
        // that trip.
        switch (widget.role) {
          case SoundFontRole.chords:
            await widget.settings?.setComping(Comping.imported);
          case SoundFontRole.bass:
            await widget.settings?.setBassSound(BassSound.imported);
          case SoundFontRole.drums:
            break;
        }
        what = widget.role == SoundFontRole.bass ? 'the bass' : 'the chords';
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${preset.name} will play $what')),
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

  /// The presets worth showing: kits when a kit is wanted, instruments
  /// otherwise. Listing the rest greyed out was just a longer list to
  /// scroll past.
  List<SoundFontPreset> _offered(SoundFont font) => [
    for (final preset in font.presets)
      if (preset.isPercussion == (widget.role == SoundFontRole.drums)) preset,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final font = _font;
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (widget.role) {
          SoundFontRole.bass => 'Import a Bass',
          SoundFontRole.drums => 'Import a Kit',
          SoundFontRole.chords => 'Import a Sound',
        }),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  switch (widget.role) {
                    SoundFontRole.bass =>
                      'A SoundFont (.sf2) holds recorded instruments. '
                          'Choose a file and pick one sound from it, and '
                          'the bass player will use that instead of the '
                          'upright.',
                    SoundFontRole.drums =>
                      'A SoundFont (.sf2) can hold drum kits as well as '
                          'instruments. Only the kits are listed here. Any '
                          'drum the kit does not have stays the band\'s own.',
                    SoundFontRole.chords =>
                      'A SoundFont (.sf2) holds recorded instruments. '
                          'Choose a file and pick one sound from it, and '
                          'the band will comp with that instead of its '
                          'own piano.',
                  },
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
                if (_offered(font).isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      widget.role == SoundFontRole.drums
                          ? 'There are no drum kits in this file. A kit sits '
                                'in bank 128, and this one has none.'
                          : 'There are no instruments in this file, only '
                                'drum kits.',
                      key: const ValueKey('nothing-offered'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final preset in _offered(font))
                  ListTile(
                    key: ValueKey('preset-${preset.index}'),
                    title: Text(preset.name),
                    subtitle: Text(
                      'Bank ${preset.bank}, program ${preset.program}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _keep(preset),
                  ),
              ],
              if (widget.store.nameFor(widget.role) case final kept?
                  when font == null) ...[
                const SectionHeader('Playing Now'),
                ListTile(
                  key: const ValueKey('kept-soundfont'),
                  leading: const Icon(Icons.graphic_eq),
                  title: Text(kept),
                  subtitle: Text(switch (widget.role) {
                    SoundFontRole.bass =>
                      'Chosen under Bass Played By in Settings',
                    SoundFontRole.drums =>
                      'Chosen under Drums Played By in Settings',
                    SoundFontRole.chords =>
                      'Chosen under Chords Played By in Settings',
                  }),
                  trailing: TextButton(
                    key: const ValueKey('forget-soundfont'),
                    onPressed: () => widget.store.forget(widget.role),
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
