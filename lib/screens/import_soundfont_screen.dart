// Choosing which of the band play out of a SoundFont.
//
// One file, and then you say what each part of it is for: this preset
// plays the chords, that one the bass, the kit plays the drums. It used to
// be three separate trips through the file picker, one per part, which
// meant choosing the same file three times to make a band out of it.
//
// A pitched preset can play the chords or the bass; a drum kit can only
// play the drums, because it has no pitch and the band would be asking it
// for chords. So each preset offers only the parts it could actually do.
//
// A kit is asked one more question: all of it, or one drum. A kit is ten
// drums and there is no reason to take all ten from the same place, so a
// snare out of one and cymbals out of another is an ordinary thing to do.
// Taking a whole kit leaves alone any drum the new kit does not have.
//
// Nothing here has to come from one file. Each part keeps its own, so a
// good piano out of one font and a good kit out of another is an ordinary
// thing to do: choose a file, assign what you want from it, choose
// another, assign from that.
//
// The file is read on the phone and goes nowhere, like the iReal import
// and the MIDI parts. The app ships no fonts of its own: plenty of the
// good free ones carry licences that would have to be honoured one at a
// time, and a font somebody found is theirs and not ours.
//
// Only the chosen sounds are kept (see instrument_file.dart). The .sf2 is
// let go as soon as this screen closes.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../audio/drum_patterns.dart' show Drum;
import '../audio/imported_kit.dart';
import '../audio/sample_bank.dart';
import '../audio/soundfont.dart';
import '../music/tune.dart' show BassSound, Comping, DrumSound;
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

  /// Which parts [preset] could play. A kit has no pitch, so it can only
  /// be the drums; anything else can comp or walk but cannot be a kit.
  List<SoundFontRole> _rolesFor(SoundFontPreset preset) => preset.isPercussion
      ? const [SoundFontRole.drums]
      : const [SoundFontRole.chords, SoundFontRole.bass];

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

  /// Asks which part [preset] should play, when there is a choice.
  Future<SoundFontRole?> _whichPart(SoundFontPreset preset) async {
    final roles = _rolesFor(preset);
    if (roles.length == 1) return roles.single;
    return _ask<SoundFontRole>('${preset.name} plays', [
      for (final role in roles)
        (key: 'play-as-${role.name}', label: role.part, value: role),
    ]);
  }

  /// Asks which of a kit to take: all of it, or one drum.
  ///
  /// One drum at a time is the point. A kit is ten drums and nobody has to
  /// take all ten from the same place: a snare out of one and cymbals out
  /// of another is how people build a kit.
  /// Null means they backed out; a record holding a null drum means the
  /// whole kit, which is not the same thing and must not be confused with
  /// it.
  Future<({Drum? drum})?> _whichDrum(SoundFontPreset preset, Set<Drum> has) =>
      _ask<({Drum? drum})>('Take from ${preset.name}', [
        (key: 'take-whole-kit', label: 'The Whole Kit', value: (drum: null)),
        for (final drum in Drum.values)
          if (has.contains(drum))
            (key: 'take-${drum.name}', label: drum.label, value: (drum: drum)),
      ]);

  /// A sheet of choices, which is the same shape both times.
  Future<T?> _ask<T>(
    String title,
    List<({String key, String label, T value})> choices,
  ) => showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    // A kit offers the whole thing and then a drum a line, which is more
    // than a sheet shows at its default height.
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        key: const ValueKey('choices'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
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

  Future<void> _keep(SoundFontPreset preset) async {
    final font = _font;
    if (font == null) return;
    final role = await _whichPart(preset);
    if (role == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _problem = null;
    });
    var took = role.part.toLowerCase();
    try {
      // Reading the samples out is the slow part, and it happens once.
      if (role == SoundFontRole.drums) {
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
        if (!mounted) return;
        setState(() => _busy = false);
        final taken = await _whichDrum(preset, kit.keys.toSet());
        // Backing out of the sheet is not a choice to act on.
        if (taken == null || !mounted) return;
        setState(() => _busy = true);
        // The font's name as well as the preset's, because kits are
        // named generically: two fonts both calling theirs "Drum Kit"
        // would be indistinguishable in the very list that exists to say
        // which drum came from where.
        final from = preset.name == font.name
            ? preset.name
            : '${preset.name} · ${font.name}';
        if (taken.drum case final drum?) {
          await widget.store.keepDrum(drum, from, kit[drum]!);
          took = 'the ${drum.label.toLowerCase()}';
        } else {
          await widget.store.keepKit(from, kit);
        }
        await widget.settings?.setDrumSound(DrumSound.imported);
      } else {
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
          case SoundFontRole.drums:
            break;
        }
      }
      if (!mounted) return;
      setState(() => _busy = false);
      // No pop: the whole point is that one file can give the band more
      // than one of its players, so the list stays where it was.
      messenger.showSnackBar(
        SnackBar(content: Text('${preset.name} will play $took')),
      );
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
                  'A SoundFont (.sf2) holds recorded instruments, and often '
                  'a drum kit as well. Choose a file and say what each sound '
                  'in it is for. They need not all come from the same file.',
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
              // What the band is playing now, and where each of them came
              // from. Above the file's own list, because somebody who
              // opens this screen is as likely to be checking as changing.
              if (widget.store.anything) ...[
                const SectionHeader('The Band Plays'),
                for (final role in [SoundFontRole.chords, SoundFontRole.bass])
                  ListTile(
                    key: ValueKey('playing-${role.name}'),
                    leading: Icon(
                      widget.store.has(role)
                          ? Icons.graphic_eq
                          : Icons.music_note_outlined,
                    ),
                    title: Text(role.part),
                    subtitle: Text(widget.store.nameFor(role) ?? role.ours),
                    trailing: widget.store.has(role)
                        ? TextButton(
                            key: ValueKey('forget-${role.name}'),
                            onPressed: () => widget.store.forget(role),
                            child: const Text('Remove'),
                          )
                        : null,
                  ),
                // The drums one at a time, because that is how they are
                // chosen now. A single line saying "the drums" would hide
                // the one thing this section is for: which drum is coming
                // from where.
                const SectionHeader('The Drums'),
                for (final drum in Drum.values)
                  ListTile(
                    key: ValueKey('playing-${drum.name}'),
                    dense: true,
                    leading: Icon(
                      widget.store.hasDrum(drum)
                          ? Icons.graphic_eq
                          : Icons.music_note_outlined,
                    ),
                    title: Text(drum.label),
                    subtitle: Text(
                      widget.store.nameForDrum(drum) ?? "The band's own",
                    ),
                    trailing: widget.store.hasDrum(drum)
                        ? TextButton(
                            key: ValueKey('forget-${drum.name}'),
                            onPressed: () => widget.store.forgetDrum(drum),
                            child: const Text('Remove'),
                          )
                        : null,
                  ),
              ],
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
                    onTap: () => _keep(preset),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
