// The imported recordings, kept per tune.
//
// A take is expensive to set up and enormous to hold. Choosing three
// files, saying what tempo and key they were played at and checking the
// downbeat is several minutes of work, and the audio itself is tens of
// megabytes rather than the few thousand numbers an imported MIDI part
// comes to. Both facts push the same way: keep it, and keep it apart.
//
// Apart from the library for the reason the parts are, only more so. The
// library's one JSON blob is rewritten every time anything changes at
// all, a star, a run, a setlist. It is also what the backup file holds,
// and a backup is meant to be small enough to paste into an email: it
// restores your tunes and setlists, not somebody's rhythm section.
//
// The audio never goes in the JSON. What is written down is the file's
// name and the handful of facts no audio file carries: the tempo the
// click was set to, the key it was played in, how many choruses there
// are. The files sit beside it, because where the app may keep its files
// moves between one launch and the next on iOS and a path written down
// today is wrong tomorrow.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../library/find_tune.dart';
import '../library/library_store.dart';
import '../music/recorded_take.dart';
import '../music/same_changes.dart';
import '../music/tune.dart';
import '../settings/progression_store.dart';

/// A take imported against one tune and offered to another, with how far
/// it has to move to get here and where it came from.
///
/// The tune it came from is carried so it can be said out loud. Putting
/// somebody else's changes under a chart without saying so would be the
/// worst thing this could do: it does not sound like the app made a
/// mistake, it sounds like you did.
typedef BorrowedTake = ({RecordedTake take, String from, int semitones});

/// Somewhere to keep the audio itself.
abstract interface class RecordingFiles {
  /// Keeps [bytes] under [name], and says what it ended up called.
  Future<String> save(String name, Uint8List bytes);

  /// The full path of a kept file, or null if it has gone.
  Future<String?> pathOf(String name);

  /// Where a file of this name would go, whether or not it is there yet.
  ///
  /// Separate from [pathOf], which answers about a file that exists: a
  /// recorder needs somewhere to write to before there is anything to
  /// ask about.
  Future<String> pathFor(String name);

  /// What is in a kept file, or null if it has gone.
  Future<Uint8List?> read(String name);

  Future<void> remove(String name);
}

/// Keeps nothing anywhere, for tests.
class NoRecordingFiles implements RecordingFiles {
  final saved = <String, Uint8List>{};
  final removed = <String>[];

  @override
  Future<String> save(String name, Uint8List bytes) async {
    saved[name] = bytes;
    return name;
  }

  @override
  Future<String?> pathOf(String name) async =>
      saved.containsKey(name) ? '/recordings/$name' : null;

  @override
  Future<String> pathFor(String name) async => '/recordings/$name';

  @override
  Future<Uint8List?> read(String name) async => saved[name];

  @override
  Future<void> remove(String name) async {
    saved.remove(name);
    removed.add(name);
  }
}

class RecordingStore extends ChangeNotifier {
  RecordingStore._(this._storage, this.files, this._sets);

  /// Nothing saved anywhere, for tests.
  RecordingStore.inMemory([Map<TuneRef, TakeSet>? sets])
    : _storage = MemoryStorage(),
      files = NoRecordingFiles(),
      _sets = {...?sets};

  static Future<RecordingStore> load({
    TextStorage? storage,
    required RecordingFiles files,
  }) async {
    final store = storage ?? preferencesStorage('recordings');
    final sets = <TuneRef, TakeSet>{};
    try {
      final text = await store.read();
      if (text != null) {
        for (final entry
            in (jsonDecode(text) as Map<String, dynamic>).entries) {
          // A take that will not read is dropped rather than throwing: it
          // is never worth losing the rest of them, let alone the tune.
          final set = TakeSet.fromJson(entry.value);
          if (!set.isEmpty) sets[TuneRef(entry.key)] = set;
        }
      }
    } catch (e) {
      debugPrint('Could not read the saved recordings: $e');
    }
    return RecordingStore._(store, files, sets);
  }

  final TextStorage _storage;
  final RecordingFiles files;
  final Map<TuneRef, TakeSet> _sets;

  /// The takes imported for [ref], which is usually none.
  TakeSet forTune(TuneRef? ref) =>
      ref == null ? TakeSet.empty : _sets[ref] ?? TakeSet.empty;

  /// The takes imported against some other tune whose changes are these
  /// changes, moved.
  ///
  /// This is what makes a recording a band rather than a backing track.
  /// Three files of people playing a blues in F are not a blues in F, they
  /// are a blues: they will sit under any blues in the book at any key and
  /// tempo the audio will stand, and keeping them locked to the one chart
  /// they were imported against wasted most of what they are.
  ///
  /// [tune] is the chart as the band plays it, at concert pitch, not the
  /// transposed one on screen.
  List<BorrowedTake> fitting(
    Tune tune,
    TuneRef? ref, {
    ProgressionStore? progressions,
  }) {
    final out = <BorrowedTake>[];
    for (final entry in _sets.entries) {
      if (entry.key == ref) continue;
      final from = findTune(entry.key, progressions: progressions);
      if (from == null) continue;
      final match = movesOnto(from.tune, tune);
      if (match == null) continue;
      for (final take in entry.value.takes) {
        out.add((
          take: take,
          from: from.tune.title,
          semitones: match.semitones,
        ));
      }
    }
    // Steadiest first: a borrowed take is already a second choice, so the
    // one that will sound best is the one worth offering first.
    out.sort((a, b) => a.take.name.compareTo(b.take.name));
    return out;
  }

  int get count => _sets.values.fold(0, (all, set) => all + set.length);

  String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_made++}';
  var _made = 0;

  /// Keeps [bytes] as the [stem] file of the take being built under [id],
  /// and says what to write down as its name.
  ///
  /// The name carries the stem so a folder of them can be read by eye
  /// when something has gone wrong, which is the only time anybody looks.
  Future<String> keep(String id, TakeStem stem, Uint8List bytes) =>
      files.save('$id-${stem.name}.wav', bytes);

  Future<String?> pathOf(String name) => files.pathOf(name);

  Future<Uint8List?> read(String name) => files.read(name);

  Future<void> add(TuneRef ref, RecordedTake take) =>
      _put(ref, forTune(ref).plus(take));

  Future<void> replace(TuneRef ref, String name, RecordedTake take) =>
      _put(ref, forTune(ref).replacing(name, take));

  /// Takes one out, and takes its audio with it.
  ///
  /// The files go too. A take nobody can reach is tens of megabytes of
  /// nothing, and on a phone that is worth more than the small chance
  /// somebody wanted it back.
  Future<void> forget(TuneRef ref, String name) async {
    final going = forTune(ref).takes
        .where((take) => take.name == name)
        .toList();
    await _put(ref, forTune(ref).without(name));
    for (final take in going) {
      for (final file in take.files.values) {
        try {
          await files.remove(file);
        } catch (e) {
          debugPrint('Could not delete a recording: $e');
        }
      }
    }
  }

  Future<void> _put(TuneRef ref, TakeSet set) async {
    if (set.isEmpty) {
      _sets.remove(ref);
    } else {
      _sets[ref] = set;
    }
    notifyListeners();
    await _write();
  }

  Map<String, dynamic> toJson() => {
    for (final entry in _sets.entries) entry.key.value: entry.value.toJson(),
  };

  Future<void> _write() async {
    try {
      await _storage.write(jsonEncode(toJson()));
    } catch (e) {
      debugPrint('Could not save the recordings: $e');
    }
  }
}
