// Building a kit, drum by drum.
//
// Its own screen, started from the drum rather than from the file. The
// other way round was the first thing built and it was the wrong way
// round: to change the snare you chose a file, scrolled past forty
// instruments to find the kit at the bottom, opened it, and then picked
// the snare out of a list of ten. Four steps and a lot of scrolling to
// answer "I want a better snare".
//
// So: ten rows, one a drum, each saying what is playing it. Tap the one
// you want to change and choose a file; the kits inside are found for
// you, and the only question left is which kit, and only when the file
// holds more than one.
//
// Taking a whole kit at once is still here, at the top, because somebody
// who just wants a different kit should not have to do it ten times.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../audio/drum_patterns.dart' show Drum;
import '../audio/imported_kit.dart';
import '../audio/sample_bank.dart';
import '../audio/soundfont.dart';
import '../music/tune.dart' show DrumSound;
import '../practice/soundfont_store.dart';
import '../settings/app_settings.dart';
import 'tunes_page.dart' show SectionHeader;

/// A kit found in a file, ready to take drums out of.
typedef FoundKit = ({String name, Map<Drum, DrumSamples> drums});

class DrumKitScreen extends StatefulWidget {
  const DrumKitScreen({
    super.key,
    required this.store,
    this.settings,
    this.pick,
  });

  final SoundFontStore store;

  /// So that taking a drum also turns the imported kit on.
  final AppSettings? settings;

  /// How a file is chosen. Tests hand in their own, because there is no
  /// picker to tap in a widget test.
  final Future<({String name, Uint8List bytes})?> Function()? pick;

  @override
  State<DrumKitScreen> createState() => _DrumKitScreenState();
}

class _DrumKitScreenState extends State<DrumKitScreen> {
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

  /// Every kit in a file the player chooses, already read.
  ///
  /// Null when they backed out of the picker, which is not a problem to
  /// report; empty when the file holds no kits, which is.
  Future<List<FoundKit>?> _kitsFromAFile() async {
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
      final font = SoundFont.read(picked.bytes, fileName: picked.name);
      final kits = <FoundKit>[];
      for (final preset in font.presets) {
        if (!preset.isPercussion) continue;
        final drums = kitFromGeneralMidi(font.drumKitFor(preset));
        if (drums.isEmpty) continue;
        // The font's name as well as the preset's: kits are called things
        // like "Standard" and two fonts would otherwise be told apart by
        // nothing at all.
        kits.add((
          name: preset.name == font.name
              ? preset.name
              : '${preset.name} · ${font.name}',
          drums: drums,
        ));
      }
      if (!mounted) return null;
      setState(() => _busy = false);
      return kits;
    } on SoundFontException catch (e) {
      if (!mounted) return null;
      setState(() {
        _busy = false;
        _problem = e.message;
      });
      return null;
    }
  }

  /// Which of [kits], when there is more than one to pick from.
  Future<FoundKit?> _whichKit(List<FoundKit> kits, {String? forDrum}) async {
    if (kits.length == 1) return kits.single;
    return showModalBottomSheet<FoundKit>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                forDrum == null
                    ? 'Which kit'
                    : 'Which kit\'s ${forDrum.toLowerCase()}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final (i, kit) in kits.indexed)
              ListTile(
                key: ValueKey('kit-$i'),
                title: Text(kit.name),
                subtitle: Text(
                  '${kit.drums.length} of ${Drum.values.length} drums',
                ),
                onTap: () => Navigator.of(context).pop(kit),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Changes one drum, starting from the drum.
  Future<void> _choose(Drum drum) async {
    final kits = await _kitsFromAFile();
    if (kits == null || !mounted) return;
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
    final chosen = await _whichKit(withIt, forDrum: drum.label);
    if (chosen == null || !mounted) return;
    await widget.store.keepDrum(drum, chosen.name, chosen.drums[drum]!);
    await widget.settings?.setDrumSound(DrumSound.imported);
  }

  /// Takes a whole kit, which fills in what it has and leaves the rest.
  Future<void> _chooseWholeKit() async {
    final kits = await _kitsFromAFile();
    if (kits == null || !mounted) return;
    if (kits.isEmpty) {
      setState(() => _problem = 'There are no drum kits in that file.');
      return;
    }
    final chosen = await _whichKit(kits);
    if (chosen == null || !mounted) return;
    await widget.store.keepKit(chosen.name, chosen.drums);
    await widget.settings?.setDrumSound(DrumSound.imported);
  }

  Future<void> _bandsOwn() async {
    await widget.store.forget(SoundFontRole.drums);
    await widget.settings?.setDrumSound(DrumSound.kit);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Drum Kit')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Every drum can come from a different place. Tap one to '
                  'take it out of a SoundFont, and anything you leave alone '
                  'stays the band\'s own.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton.icon(
                  key: const ValueKey('whole-kit'),
                  onPressed: _busy ? null : _chooseWholeKit,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Take a Whole Kit'),
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
                    key: const ValueKey('drum-problem'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ),
              const SectionHeader('Each Drum'),
              for (final drum in Drum.values)
                ListTile(
                  key: ValueKey('drum-${drum.name}'),
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
                          key: ValueKey('clear-${drum.name}'),
                          onPressed: () => widget.store.forgetDrum(drum),
                          child: const Text('Clear'),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _busy ? null : () => _choose(drum),
                ),
              if (widget.store.has(SoundFontRole.drums))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: OutlinedButton.icon(
                    key: const ValueKey('bands-own-kit'),
                    onPressed: _bandsOwn,
                    icon: const Icon(Icons.undo),
                    label: const Text('Play the Band\'s Own Kit'),
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
