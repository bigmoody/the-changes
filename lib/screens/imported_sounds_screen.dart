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
// A file brought in stays, on the shelf (see soundfont_store.dart), so
// that changing the snare a second time, or trying the next piano along,
// is a list and a tap rather than the file picker again. Each part's row
// opens that list; the file picker only comes up for a file that is not
// here yet.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../audio/drum_patterns.dart' show Drum, importableDrums;
import '../audio/soundfont.dart' show SoundFontException;
import '../music/tune.dart' show BassSound, Comping, DrumSound;
import '../practice/soundfont_store.dart';
import '../settings/app_settings.dart';
import 'sound_shelf.dart';
import 'tunes_page.dart' show SectionHeader;

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
  /// The font on the shelf whose sounds are listed, if one is.
  String? _openId;
  String? _problem;
  var _busy = false;

  PickFiles? get _pick => switch (widget.pick) {
    null => null,
    final pick => () async => [?await pick()],
  };

  ShelvedFont? get _open {
    for (final font in widget.store.shelf) {
      if (font.id == _openId) return font;
    }
    return null;
  }

  /// Runs [work], which puts the spinner up itself while it is reading
  /// rather than while a list is open, and says what went wrong.
  Future<void> _while(
    Future<({ShelfOutcome outcome, String? problem})> Function() work, {
    Future<void> Function(ShelfOutcome outcome)? then,
  }) async {
    setState(() => _problem = null);
    final done = await work();
    if (then != null) await then(done.outcome);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = done.problem;
    });
  }

  void _working(bool working) {
    if (mounted) setState(() => _busy = working);
  }

  // ── The shelf ──────────────────────────────────────────────────────────

  Future<void> _bringIn() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    final brought = await bringIn(widget.store, pick: _pick);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = brought.problem;
      // What came in is opened, because looking at what is in it is
      // why somebody brings a file in from here.
      if (brought.added.isNotEmpty) _openId = brought.added.last.id;
    });
  }

  Future<void> _remove(ShelvedFont font) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${font.name}?'),
        content: const Text(
          'The copy on this phone is deleted, and its sounds go from the '
          'list. Anything already playing from it keeps playing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep It'),
          ),
          TextButton(
            key: const ValueKey('really-remove-font'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    if (_openId == font.id) setState(() => _openId = null);
    await widget.store.remove(font);
  }

  // ── Coming in from the part ────────────────────────────────────────────

  Future<void> _chooseInstrument(SoundFontRole role) => _while(
    () => chooseInstrument(
      context,
      widget.store,
      role,
      pick: _pick,
      working: _working,
    ),
    then: (outcome) async {
      switch (outcome) {
        case ShelfOutcome.chosen:
          await _putOn(role);
        case ShelfOutcome.ours:
          await widget.store.forget(role);
        case ShelfOutcome.nothing:
          break;
      }
    },
  );

  Future<void> _chooseDrum(Drum drum) => _while(
    () =>
        chooseDrum(context, widget.store, drum, pick: _pick, working: _working),
    then: (outcome) async {
      switch (outcome) {
        case ShelfOutcome.chosen:
          await widget.settings?.setDrumSound(DrumSound.imported);
        case ShelfOutcome.ours:
          await widget.store.forgetDrum(drum);
        case ShelfOutcome.nothing:
          break;
      }
    },
  );

  /// And put it on. Anybody who has just picked a sound wants to hear it,
  /// and leaving it to a second trip through Settings makes the app look
  /// broken to everyone who does not make that trip.
  Future<void> _putOn(SoundFontRole role) async {
    switch (role) {
      case SoundFontRole.chords:
        await widget.settings?.setComping(Comping.imported);
      case SoundFontRole.bass:
        await widget.settings?.setBassSound(BassSound.imported);
      case SoundFontRole.arpeggio:
        await widget.settings?.setArpeggioSound(Comping.imported);
      case SoundFontRole.drums:
        await widget.settings?.setDrumSound(DrumSound.imported);
    }
  }

  // ── Coming in from the file ────────────────────────────────────────────

  /// A sound tapped in a font's own list, which has to ask what it is for
  /// because the font does not know.
  Future<void> _assign(ShelvedFont font, ShelvedSound sound) async {
    if (sound.isKit) {
      if (sound.drums.isEmpty) {
        setState(
          () => _problem =
              '${sound.name} has no drums where the General MIDI map puts '
              'them, so the band would not know what to hit.',
        );
        return;
      }
      final taken = await _pickOne<({Drum? drum})>('Take from ${sound.name}', [
        (key: 'take-whole-kit', label: 'The Whole Kit', value: (drum: null)),
        for (final drum in Drum.values)
          if (sound.drums.contains(drum))
            (key: 'take-${drum.name}', label: drum.label, value: (drum: drum)),
      ]);
      if (taken == null || !mounted) return;
      final ok = await _trying(() async {
        if (taken.drum case final drum?) {
          await widget.store.chooseDrum(drum, font, sound);
        } else {
          await widget.store.chooseKit(font, sound);
        }
        await widget.settings?.setDrumSound(DrumSound.imported);
      });
      if (ok) {
        _say(
          '${sound.name} will play '
          '${taken.drum == null ? 'the drums' : 'the ${taken.drum!.label.toLowerCase()}'}',
        );
      }
      return;
    }
    final role = await _pickOne<SoundFontRole>('${sound.name} plays', [
      for (final role in [
        SoundFontRole.chords,
        SoundFontRole.bass,
        SoundFontRole.arpeggio,
      ])
        (key: 'play-as-${role.name}', label: role.part, value: role),
    ]);
    if (role == null || !mounted) return;
    final ok = await _trying(() async {
      // Reading the samples out is the slow part, and it happens once.
      await widget.store.choose(role, font, sound);
      await _putOn(role);
    });
    if (ok) _say('${sound.name} will play ${role.part.toLowerCase()}');
  }

  /// Does [work] with the spinner up, and says so if the font would not
  /// give the sound up.
  Future<bool> _trying(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await work();
      if (mounted) setState(() => _busy = false);
      return true;
    } on SoundFontException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = e.message;
        });
      }
      return false;
    }
  }

  void _say(String what) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(what)));
  }

  // ── Asking ─────────────────────────────────────────────────────────────

  /// One of [choices].
  Future<T?> _pickOne<T>(
    String title,
    List<({String key, String label, T value})> choices,
  ) => showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
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

  Future<void> _forgetEverything() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Play the Whole Band Again?'),
        content: const Text(
          'Every sound the band is playing from a SoundFont is let go, and '
          'it goes back to its own piano, upright and kit. Your SoundFonts '
          'stay in the list to choose from again.',
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
    final open = _open;
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
                  'your own. Bring a file in once and every sound in it stays '
                  'here to choose from, on this screen and in the mixer.',
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
              const SectionHeader('Your SoundFonts'),
              for (final (i, font) in widget.store.shelf.indexed) ...[
                ListTile(
                  key: ValueKey('font-$i'),
                  leading: Icon(
                    font.id == _openId ? Icons.expand_less : Icons.expand_more,
                  ),
                  title: Text(font.name),
                  subtitle: Text(font.summary),
                  trailing: IconButton(
                    key: ValueKey('remove-font-$i'),
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(font),
                  ),
                  onTap: () => setState(
                    () => _openId = font.id == _openId ? null : font.id,
                  ),
                ),
                if (font.id == open?.id) ...[
                  if (font.sounds.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 16, 8),
                      child: Text(
                        'There is nothing playable in this file.',
                        key: const ValueKey('nothing-offered'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final sound in font.sounds)
                    ListTile(
                      key: ValueKey('preset-${sound.index}'),
                      dense: true,
                      contentPadding: const EdgeInsets.only(
                        left: 56,
                        right: 16,
                      ),
                      title: Text(sound.name),
                      subtitle: Text(
                        sound.isKit
                            ? 'A drum kit'
                            : 'Bank ${sound.bank}, program ${sound.program}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : () => _assign(font, sound),
                    ),
                ],
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: OutlinedButton.icon(
                  key: const ValueKey('choose-soundfont'),
                  onPressed: _busy ? null : _bringIn,
                  icon: const Icon(Icons.add),
                  label: const Text('Add a SoundFont'),
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
