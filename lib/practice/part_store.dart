// The imported parts, kept per tune.
//
// A part is worth keeping. Choosing a file, picking a track out of it and
// nudging it into place is several minutes' work, and before this it was
// thrown away the moment the tune closed, which meant nobody would ever do
// it twice.
//
// Kept apart from the library rather than in it. The library's one JSON
// blob is rewritten every time anything at all changes, a star, a run, a
// setlist, and a busy part is tens of thousands of numbers; carrying that
// through every write would make the cheapest thing in the app the most
// expensive. It also stays out of the backup file, which is meant to be
// small enough to paste into an email: a backup restores your tunes and
// setlists, not the MIDI files you happened to have lying about.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../library/library_store.dart';
import '../music/imported_part.dart';
import '../settings/progression_store.dart';

class PartStore extends ChangeNotifier {
  PartStore._(this._storage, this._parts);

  /// Nothing saved anywhere, for tests.
  PartStore.inMemory([Map<TuneRef, ImportedPart>? parts])
    : _storage = MemoryStorage(),
      _parts = {...?parts};

  static Future<PartStore> load({TextStorage? storage}) async {
    final store = storage ?? preferencesStorage('parts');
    final parts = <TuneRef, ImportedPart>{};
    try {
      final text = await store.read();
      if (text != null) {
        for (final entry
            in (jsonDecode(text) as Map<String, dynamic>).entries) {
          final part = ImportedPart.fromJson(
            entry.value as Map<String, Object?>,
          );
          // A part that will not read is dropped rather than throwing: it
          // is never worth losing the rest of them, let alone the tune.
          if (part != null) parts[TuneRef(entry.key)] = part;
        }
      }
    } catch (e) {
      debugPrint('Could not read the saved parts: $e');
    }
    return PartStore._(store, parts);
  }

  final TextStorage _storage;
  final Map<TuneRef, ImportedPart> _parts;

  /// The part kept for [ref], or null when there isn't one, which is the
  /// usual case.
  ImportedPart? forTune(TuneRef? ref) => ref == null ? null : _parts[ref];

  int get count => _parts.length;

  /// Keeps [part] for [ref], or forgets it when [part] is null.
  Future<void> set(TuneRef ref, ImportedPart? part) async {
    if (part == null) {
      if (_parts.remove(ref) == null) return;
    } else {
      _parts[ref] = part;
    }
    notifyListeners();
    await _write();
  }

  Map<String, dynamic> toJson() => {
    for (final entry in _parts.entries) entry.key.value: entry.value.toJson(),
  };

  Future<void> _write() async {
    try {
      await _storage.write(jsonEncode(toJson()));
    } catch (e) {
      debugPrint('Could not save the imported parts: $e');
    }
  }
}
