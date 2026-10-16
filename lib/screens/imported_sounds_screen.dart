// Who in the band is played by a SoundFont of your own.
//
// One screen, and two ways into it, because people arrive with two
// different questions.
//
//   "I want a better snare."   Tap the snare. It asks for a file, finds
//                              the kits in it and takes that drum out.
//   "What is in this file?"    Choose a file. Everything in it is listed,
//                              and each sound says what it can be.
//
// The first is the one that matters. Starting from the file meant
// scrolling past forty instruments to find a kit at the bottom and then
// picking one drum out of ten, which is four steps to answer a question
// about a snare. Starting from the part is three taps.
//
// It was two screens for a while, one per direction. They shared the
// parsing, the General MIDI map and the store, and differed only in which
// end you came in at, which is not a reason to be two screens.
//
// The file is read on the phone and goes nowhere, like the iReal import
// and the MIDI parts. The app ships no fonts of its own: plenty of the
// good free ones carry licences that would have to be honoured one at a
// time, and a font somebody found is theirs and not ours.
//
// Only the chosen sounds are kept (see instrument_file.dart). The .sf2 is
// let go as soon as it has been read.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../audio/drum_patterns.dart' show Drum, importableDrums;
import '../audio/imported_kit.dart';
import '../audio/sample_bank.dart';
import '../audio/soundfont.dart';
import '../audio/what_file.dart';
import '../music/tune.dart' show BassSound, Comping, DrumSound;
import '../practice/soundfont_store.dart';
import '../settings/app_settings.dart';
import 'tunes_page.dart' show SectionHeader;

/// A kit found in a file, ready to take drums out of.
typedef FoundKit = ({String name, Map<Drum, DrumSamples> drums});

class ImportedSoundsScreen extends StatefulWidget {
  const ImportedSoundsScreen({
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
  State<ImportedSoundsScreen> createState() => _ImportedSoundsScreenState();
}

class _ImportedSoundsScreenState extends State<ImportedSoundsScreen> {
  /// The file being browsed, when somebody came in that way.
  SoundFont? _font;
  String? _problem;
  var _busy = false;

  // ── Getting a file ─────────────────────────────────────────────────────

  Future<({String name, Uint8List bytes})?> _pickFile() async {
    // Any file rather than only .sf2: the extension is not reliable on
    // every platform, and saying what a file actually is beats a picker
    // that silently offers nothing to choose.
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (bytes == null) return null;
    return (name: file!.name, bytes: bytes);
  }

  /// A file, read, or null when they backed out or it was not one.
  ///
  /// The wrong kind of file is named rather than refused: somebody who
  /// has brought a MIDI file here has the right file and the wrong door.
  Future<SoundFont?> _readAFile() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final picked = await (widget.pick ?? _pickFile)();
      if (!mounted) return null;
      if (picked == null) {
        setState(() => _busy = false);
        return null;
      }
      final kind = whatIsThisFile(picked.bytes);
      if (kind != FileKind.soundFont) {
        setState(() {
          _busy = false;
          _problem = wrongKind(
            kind,
            wanted: FileKind.soundFont,
            instead: switch (kind) {
              FileKind.midi => 'Add it as a part from the tune you want it on.',
              FileKind.wav =>
                'Recordings of real players go in from the tune they were '
                    'played over.',
              _ => null,
            },
          );
        });
        return null;
      }
      final font = SoundFont.read(picked.bytes, fileName: picked.name);
      if (!mounted) return null;
      setState(() => _busy = false);
      return font;
    } on SoundFontException catch (e) {
      if (!mounted) return null;
      setState(() {
        _busy = false;
        _problem = e.message;
      });
      return null;
    }
  }

  /// Every kit in [font], already mapped onto the band's drums.
  List<FoundKit> _kitsIn(SoundFont font) {
    final kits = <FoundKit>[];
    for (final preset in font.presets) {
      if (!preset.isPercussion) continue;
      final drums = kitFromGeneralMidi(font.drumKitFor(preset));
      if (drums.isEmpty) continue;
      kits.add((name: _nameOf(preset, font), drums: drums));
    }
    return kits;
  }

  /// The font's name as well as the preset's, because kits are named
  /// generically: two fonts both calling theirs "Drum Kit" would be
  /// indistinguishable in the very list that says where each drum is from.
  String _nameOf(SoundFontPreset preset, SoundFont font) =>
      preset.name == font.name ? preset.name : '${preset.name} · ${font.name}';

  // ── Coming in from the part ────────────────────────────────────────────

  /// Changes one drum, starting from the drum.
  Future<void> _chooseDrum(Drum drum) async {
    final font = await _readAFile();
    if (font == null || !mounted) return;
    final kits = _kitsIn(font);
    // Only the kits that actually have this drum: offering one that does
    // not, and then failing, would be the app wasting somebody's tap.
    final withIt = [
      for (final kit in kits)
        if (kit.drums.containsKey(drum)) kit,
    ];
    if (withIt.isEmpty) {
      setState(
        () => _problem = kits.isEmpty
            ? 'There are no drum kits in that file.'
            : 'No kit in that file has a ${drum.label.toLowerCase()}.',
      );
      return;
    }
    final chosen = await _pickOne(
      withIt.length == 1 ? null : 'Which kit\'s ${drum.label.toLowerCase()}',
      [
        for (final (i, kit) in withIt.indexed)
          (key: 'kit-$i', label: kit.name, value: kit),
      ],
    );
    if (chosen == null || !mounted) return;
    await widget.store.keepDrum(drum, chosen.name, chosen.drums[drum]!);
    await widget.settings?.setDrumSound(DrumSound.imported);
  }

  /// Changes the chords or the bass, starting from the part.
  Future<void> _chooseInstrument(SoundFontRole role) async {
    final font = await _readAFile();
    if (font == null || !mounted) return;
    final pitched = [
      for (final preset in font.presets)
        if (!preset.isPercussion) preset,
    ];
    if (pitched.isEmpty) {
      setState(
        () => _problem = 'There are no instruments in that file, only kits.',
      );
      return;
    }
    final chosen = await _pickOne(
      'Which sound plays ${role.part.toLowerCase()}',
      [
        for (final preset in pitched)
          (key: 'sound-${preset.index}', label: preset.name, value: preset),
      ],
    );
    if (chosen == null || !mounted) return;
    await _keepInstrument(chosen, role);
  }

  // ── Coming in from the file ────────────────────────────────────────────

  Future<void> _browse() async {
    final font = await _readAFile();
    if (font == null || !mounted) return;
    setState(() => _font = font);
  }

  /// A preset tapped in the file's own list, which has to ask what it is
  /// for because the file does not know.
  Future<void> _assign(SoundFontPreset preset) async {
    final font = _font;
    if (font == null) return;
    if (preset.isPercussion) {
      final kit = kitFromGeneralMidi(font.drumKitFor(preset));
      if (kit.isEmpty) {
        setState(
          () => _problem =
              '${preset.name} has no drums where the General MIDI map puts '
              'them, so the band would not know what to hit.',
        );
        return;
      }
      final taken = await _pickOne<({Drum? drum})>('Take from ${preset.name}', [
        (key: 'take-whole-kit', label: 'The Whole Kit', value: (drum: null)),
        for (final drum in Drum.values)
          if (kit.containsKey(drum))
            (key: 'take-${drum.name}', label: drum.label, value: (drum: drum)),
      ]);
      if (taken == null || !mounted) return;
      final from = _nameOf(preset, font);
      if (taken.drum case final drum?) {
        await widget.store.keepDrum(drum, from, kit[drum]!);
      } else {
        await widget.store.keepKit(from, kit);
      }
      await widget.settings?.setDrumSound(DrumSound.imported);
      _say(
        '${preset.name} will play '
        '${taken.drum == null ? 'the drums' : 'the ${taken.drum!.label.toLowerCase()}'}',
      );
      return;
    }
    final role = await _pickOne<SoundFontRole>('${preset.name} plays', [
      for (final role in [
        SoundFontRole.chords,
        SoundFontRole.bass,
        SoundFontRole.arpeggio,
      ])
        (key: 'play-as-${role.name}', label: role.part, value: role),
    ]);
    if (role == null || !mounted) return;
    await _keepInstrument(preset, role);
    _say('${preset.name} will play ${role.part.toLowerCase()}');
  }

  Future<void> _keepInstrument(
    SoundFontPreset preset,
    SoundFontRole role,
  ) async {
    final font = _font ?? await _readAFile();
    if (font == null || !mounted) return;
    setState(() => _busy = true);
    try {
      // Reading the samples out is the slow part, and it happens once.
      final SampledInstrument instrument = font.instrumentFor(preset);
      await widget.store.keep(role, instrument);
      // And put it on. Anybody who has just picked a sound out of a file
      // wants to hear it, and leaving it to a second trip through
      // Settings makes the app look broken to everyone who does not make
      // that trip.
      switch (role) {
        case SoundFontRole.chords:
          await widget.settings?.setComping(Comping.imported);
        case SoundFontRole.bass:
          await widget.settings?.setBassSound(BassSound.imported);
        case SoundFontRole.arpeggio:
          await widget.settings?.setArpeggioSound(Comping.imported);
        case SoundFontRole.drums:
          break;
      }
      if (!mounted) return;
      setState(() => _busy = false);
    } on SoundFontException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = e.message;
      });
    }
  }

  void _say(String what) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(what)));

  // ── Asking ─────────────────────────────────────────────────────────────

  /// One of [choices], or the only one when there is no question to ask.
  Future<T?> _pickOne<T>(
    String? title,
    List<({String key, String label, T value})> choices,
  ) async {
    if (choices.length == 1 && title == null) return choices.single.value;
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            for (final choice in choices)
              ListTile(
                key: ValueKey(choice.key),
                title: Text(choice.label),
                onTap: () => Navigator.of(context).pop(choice.value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _forgetEverything() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Play the Whole Band Again?'),
        content: const Text(
          'Every sound you have imported is thrown away, and the band goes '
          'back to its own piano, upright and kit. The SoundFonts you took '
          'them from are untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Them'),
          ),
          TextButton(
            key: const ValueKey('really-forget-everything'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove All'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await widget.store.forgetEverything();
    // And the settings back with them, so nothing is left saying it is
    // playing an imported sound that is no longer there.
    await widget.settings?.setComping(Comping.piano);
    await widget.settings?.setArpeggioSound(Comping.piano);
    await widget.settings?.setBassSound(BassSound.upright);
    await widget.settings?.setDrumSound(DrumSound.kit);
  }

  // ── The screen ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final font = _font;
    return Scaffold(
      appBar: AppBar(title: const Text('Imported Sounds')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Any of the band can be played from a SoundFont (.sf2) of '
                  'your own. Tap the part you want to change, or open a file '
                  'and see what is in it.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
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
              // Every part, tappable to change it: the question people
              // actually arrive with is about a part, not about a file.
              const SectionHeader('The Band Plays'),
              for (final role in [
                SoundFontRole.chords,
                SoundFontRole.bass,
                SoundFontRole.arpeggio,
              ])
                _PartRow(
                  key: ValueKey('playing-${role.name}'),
                  title: role.part,
                  from: widget.store.nameFor(role),
                  ours: role.ours,
                  onTap: _busy ? null : () => _chooseInstrument(role),
                  onClear: widget.store.has(role)
                      ? () => widget.store.forget(role)
                      : null,
                  clearKey: ValueKey('forget-${role.name}'),
                ),
              const SectionHeader('The Drums'),
              for (final drum in importableDrums)
                _PartRow(
                  key: ValueKey('playing-${drum.name}'),
                  title: drum.label,
                  from: widget.store.nameForDrum(drum),
                  ours: "The band's own",
                  dense: true,
                  onTap: _busy ? null : () => _chooseDrum(drum),
                  onClear: widget.store.hasDrum(drum)
                      ? () => widget.store.forgetDrum(drum)
                      : null,
                  clearKey: ValueKey('forget-${drum.name}'),
                ),
              if (widget.store.has(SoundFontRole.drums))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextButton.icon(
                    key: const ValueKey('bands-own-kit'),
                    onPressed: () async {
                      await widget.store.forget(SoundFontRole.drums);
                      await widget.settings?.setDrumSound(DrumSound.kit);
                    },
                    icon: const Icon(Icons.undo),
                    label: const Text('Play the Band\'s Own Kit'),
                  ),
                ),
              const SectionHeader('Or Open a File'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: OutlinedButton.icon(
                  key: const ValueKey('choose-soundfont'),
                  onPressed: _busy ? null : _browse,
                  icon: const Icon(Icons.folder_open),
                  label: Text(
                    font == null ? 'Choose a File' : 'Choose Another',
                  ),
                ),
              ),
              if (font != null && !_busy) ...[
                SectionHeader(font.name),
                if (font.presets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      'There is nothing playable in this file.',
                      key: const ValueKey('nothing-offered'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final preset in font.presets)
                  ListTile(
                    key: ValueKey('preset-${preset.index}'),
                    title: Text(preset.name),
                    subtitle: Text(
                      preset.isPercussion
                          ? 'A drum kit'
                          : 'Bank ${preset.bank}, program ${preset.program}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _assign(preset),
                  ),
              ],
              if (widget.store.anything)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: OutlinedButton.icon(
                    key: const ValueKey('forget-everything'),
                    onPressed: _forgetEverything,
                    icon: const Icon(Icons.undo),
                    label: const Text('Play the Whole Band Again'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One part of the band: what plays it, and a way to change or clear it.
class _PartRow extends StatelessWidget {
  const _PartRow({
    super.key,
    required this.title,
    required this.from,
    required this.ours,
    required this.onTap,
    required this.onClear,
    required this.clearKey,
    this.dense = false,
  });

  final String title;

  /// Where the imported sound came from, or null when it is the band's.
  final String? from;
  final String ours;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final Key clearKey;
  final bool dense;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: dense,
    leading: Icon(from == null ? Icons.music_note_outlined : Icons.graphic_eq),
    title: Text(title),
    subtitle: Text(from ?? ours),
    trailing: onClear == null
        ? const Icon(Icons.chevron_right)
        : TextButton(
            key: clearKey,
            onPressed: onClear,
            child: const Text('Clear'),
          ),
    onTap: onTap,
  );
}
