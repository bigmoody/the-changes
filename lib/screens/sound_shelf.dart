// Choosing a sound off the shelf, from wherever somebody is.
//
// The same list from the Imported Sounds screen and from the mixer, so a
// piano tried in the middle of a tune is chosen the way it would be in
// Settings: every font brought in, every sound in each, the one playing
// ticked, and a way to bring in another file at the bottom.
//
// Before there was a shelf, every change started with the file picker.
// Now the picker is only for a file that is not here yet.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../audio/drum_patterns.dart' show Drum;
import '../audio/soundfont.dart' show SoundFontException;
import '../audio/what_file.dart';
import '../practice/soundfont_store.dart';

/// The shelf, for anything below the app that wants to offer it without
/// every screen in between having to hand it down.
class SoundFonts extends InheritedNotifier<SoundFontStore> {
  const SoundFonts({
    super.key,
    required SoundFontStore store,
    required super.child,
  }) : super(notifier: store);

  static SoundFontStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SoundFonts>()?.notifier;
}

/// A file somebody chose.
typedef PickedFile = ({String name, Uint8List bytes});

/// How files are chosen. Tests hand in their own, because there is no
/// picker to tap in a widget test.
typedef PickFiles = Future<List<PickedFile>> Function();

Future<List<PickedFile>> _pickFiles() async {
  // Any file rather than only .sf2: the extension is not reliable on
  // every platform, and saying what a file actually is beats a picker
  // that silently offers nothing to choose. Several at once, because
  // somebody with a folder of fonts should not have to come back for
  // each.
  final picked = await FilePicker.platform.pickFiles(
    withData: true,
    allowMultiple: true,
  );
  return [
    for (final file in picked?.files ?? const <PlatformFile>[])
      if (file.bytes case final bytes?) (name: file.name, bytes: bytes),
  ];
}

/// Brings files in and puts each SoundFont on the shelf.
///
/// The wrong kind of file is named rather than refused: somebody who has
/// brought a MIDI file here has the right file and the wrong door. What
/// was added comes back with whatever went wrong, so one bad file in
/// three does not lose the other two.
Future<({List<ShelvedFont> added, String? problem})> bringIn(
  SoundFontStore store, {
  PickFiles? pick,
}) async {
  final files = await (pick ?? _pickFiles)();
  final added = <ShelvedFont>[];
  String? problem;
  for (final file in files) {
    final kind = whatIsThisFile(file.bytes);
    if (kind != FileKind.soundFont) {
      problem = wrongKind(
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
      continue;
    }
    try {
      added.add(await store.add(file.name, file.bytes));
    } on SoundFontException catch (e) {
      problem = e.message;
    }
  }
  return (added: added, problem: problem);
}

/// What was chosen off the shelf.
sealed class ShelfChoice {
  const ShelfChoice();
}

/// The band's own sound, and nothing imported.
class OursChosen extends ShelfChoice {
  const OursChosen();
}

/// Another file wanted.
class AddChosen extends ShelfChoice {
  const AddChosen();
}

class SoundChosen extends ShelfChoice {
  const SoundChosen(this.font, this.sound);
  final ShelvedFont font;
  final ShelvedSound sound;
}

/// Every sound on the shelf that [offers] lets through, grouped by font,
/// with the one [isPlaying] says is on ticked.
///
/// [ours] is what the band plays without one, offered first where going
/// back to it is a choice here; the mixer has its own buttons for that
/// and leaves it out.
Future<ShelfChoice?> showShelf(
  BuildContext context, {
  required SoundFontStore store,
  required String title,
  required bool Function(ShelvedSound sound) offers,
  required bool Function(ShelvedFont font, ShelvedSound sound) isPlaying,
  String? ours,
  bool oursPlaying = false,
}) {
  final fonts = [
    for (final (i, font) in store.shelf.indexed)
      (
        at: i,
        font: font,
        sounds: [
          for (final sound in font.sounds)
            if (offers(sound)) sound,
        ],
      ),
  ].where((f) => f.sounds.isNotEmpty).toList();
  final count = fonts.fold(0, (n, f) => n + f.sounds.length);
  var filter = '';
  return showModalBottomSheet<ShelfChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              final wanted = filter.trim().toLowerCase();
              bool shown(ShelvedSound s) =>
                  wanted.isEmpty || s.name.toLowerCase().contains(wanted);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                  // A General MIDI font is a hundred and twenty-eight
                  // sounds, and scrolling to the Rhodes is its own chore.
                  if (count > 12)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        key: const ValueKey('shelf-search'),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Find a sound',
                          isDense: true,
                        ),
                        onChanged: (text) => setState(() => filter = text),
                      ),
                    ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (ours != null)
                          ListTile(
                            key: const ValueKey('shelf-ours'),
                            leading: const Icon(Icons.music_note_outlined),
                            title: Text(ours),
                            trailing: oursPlaying
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () =>
                                Navigator.of(context).pop(const OursChosen()),
                          ),
                        for (final f in fonts)
                          if (f.sounds.any(shown)) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                f.font.name,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            for (final sound in f.sounds)
                              if (shown(sound))
                                ListTile(
                                  key: ValueKey('shelf-${f.at}-${sound.index}'),
                                  dense: true,
                                  title: Text(sound.name),
                                  trailing: isPlaying(f.font, sound)
                                      ? const Icon(Icons.check)
                                      : null,
                                  onTap: () =>
                                      Navigator.of(context)
                                          .pop(SoundChosen(f.font, sound)),
                                ),
                          ],
                        if (fonts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Text(
                              'Nothing you have brought in can play this '
                              'yet.',
                              key: const ValueKey('shelf-empty'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ListTile(
                          key: const ValueKey('shelf-add'),
                          leading: const Icon(Icons.add),
                          title: const Text('Add a SoundFont'),
                          onTap: () =>
                              Navigator.of(context).pop(const AddChosen()),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

/// What a choice off the shelf did: a sound put on, the band's own put
/// back, or nothing, and what went wrong if anything did.
enum ShelfOutcome { chosen, ours, nothing }

/// Asks for a sound and puts it where it goes, coming back to the list
/// after a file is brought in so the new sounds can be chosen straight
/// away.
///
/// A file brought in for one part that has exactly one sound for it is
/// not asked about: tapping the snare and choosing a file with one kit in
/// it is done, the way it was before there was a shelf.
///
/// [put] does the putting, and throws a [SoundFontException] if the
/// sound will not come out of its font. [nothingIn] says what to tell
/// somebody whose file had nothing for this part.
Future<({ShelfOutcome outcome, String? problem})> _askAndPut(
  BuildContext context,
  SoundFontStore store, {
  required String title,
  required bool Function(ShelvedSound sound) offers,
  required bool Function(ShelvedFont font, ShelvedSound sound) isPlaying,
  required Future<void> Function(ShelvedFont font, ShelvedSound sound) put,
  required String Function(List<ShelvedFont> added) nothingIn,
  String? ours,
  bool oursPlaying = false,
  PickFiles? pick,
  void Function(bool working)? working,
}) async {
  Future<({ShelfOutcome outcome, String? problem})> putting(
    ShelvedFont font,
    ShelvedSound sound,
  ) async {
    working?.call(true);
    try {
      await put(font, sound);
      return (outcome: ShelfOutcome.chosen, problem: null);
    } on SoundFontException catch (e) {
      return (outcome: ShelfOutcome.nothing, problem: e.message);
    } finally {
      working?.call(false);
    }
  }

  /// Brings files in, and takes the one sound in them if there is one.
  Future<({ShelfOutcome outcome, String? problem})?> bringingIn() async {
    final files = await (pick ?? _pickFiles)();
    working?.call(true);
    final brought = await bringIn(store, pick: () async => files);
    working?.call(false);
    final fresh = [
      for (final font in brought.added)
        for (final sound in font.sounds)
          if (offers(sound)) (font: font, sound: sound),
    ];
    if (fresh.length == 1) {
      return putting(fresh.single.font, fresh.single.sound);
    }
    final problem =
        brought.problem ??
        (brought.added.isNotEmpty && fresh.isEmpty
            ? nothingIn(brought.added)
            : null);
    return problem == null && brought.added.isNotEmpty
        ? null
        : (outcome: ShelfOutcome.nothing, problem: problem);
  }

  // Nothing to offer yet: the file is the first thing, as it always was.
  if (!store.shelf.any((f) => f.sounds.any(offers))) {
    final done = await bringingIn();
    if (done != null) return done;
  }
  String? problem;
  while (true) {
    if (!context.mounted) break;
    final choice = await showShelf(
      context,
      store: store,
      title: title,
      offers: offers,
      isPlaying: isPlaying,
      ours: ours,
      oursPlaying: oursPlaying,
    );
    switch (choice) {
      case null:
        return (outcome: ShelfOutcome.nothing, problem: problem);
      case OursChosen():
        return (outcome: ShelfOutcome.ours, problem: null);
      case AddChosen():
        final done = await bringingIn();
        if (done == null) continue;
        if (done.outcome == ShelfOutcome.chosen) return done;
        problem = done.problem;
        // Nothing new to choose from, and nothing that was there before
        // either: the list would only be the same empty one again.
        if (!store.shelf.any((f) => f.sounds.any(offers))) {
          return done;
        }
      case SoundChosen(:final font, :final sound):
        return putting(font, sound);
    }
  }
  return (outcome: ShelfOutcome.nothing, problem: problem);
}

/// A sound for the chords, the bass or the arpeggios.
Future<({ShelfOutcome outcome, String? problem})> chooseInstrument(
  BuildContext context,
  SoundFontStore store,
  SoundFontRole role, {
  bool offerOurs = true,
  PickFiles? pick,
  void Function(bool working)? working,
}) => _askAndPut(
  context,
  store,
  title: 'Which sound plays ${role.part.toLowerCase()}',
  offers: (sound) => !sound.isKit,
  isPlaying: (font, sound) => store.isPlaying(role, font, sound),
  put: (font, sound) => store.choose(role, font, sound),
  nothingIn: (added) => added.every((f) => f.instruments.isEmpty)
      ? 'There are no instruments in that file, only kits.'
      : 'There is nothing in that file that can play '
            '${role.part.toLowerCase()}.',
  ours: offerOurs ? role.ours : null,
  oursPlaying: !store.has(role),
  pick: pick,
  working: working,
);

/// One drum, out of any kit on the shelf that has it.
Future<({ShelfOutcome outcome, String? problem})> chooseDrum(
  BuildContext context,
  SoundFontStore store,
  Drum drum, {
  PickFiles? pick,
  void Function(bool working)? working,
}) => _askAndPut(
  context,
  store,
  title: 'Which kit\'s ${drum.label.toLowerCase()}',
  offers: (sound) => sound.drums.contains(drum),
  isPlaying: (font, sound) => store.isPlayingDrum(drum, font, sound),
  put: (font, sound) => store.chooseDrum(drum, font, sound),
  nothingIn: (added) => added.every((f) => f.kits.isEmpty)
      ? 'There are no drum kits in that file.'
      : 'No kit in that file has a ${drum.label.toLowerCase()}.',
  ours: "The band's own",
  oursPlaying: !store.hasDrum(drum),
  pick: pick,
  working: working,
);

/// A whole kit, which takes every drum it has.
Future<({ShelfOutcome outcome, String? problem})> chooseKit(
  BuildContext context,
  SoundFontStore store, {
  PickFiles? pick,
  void Function(bool working)? working,
}) => _askAndPut(
  context,
  store,
  title: 'Which kit plays the drums',
  offers: (sound) => sound.drums.isNotEmpty,
  isPlaying: store.isPlayingKit,
  put: store.chooseKit,
  nothingIn: (_) => 'There are no drum kits in that file.',
  pick: pick,
  working: working,
);
