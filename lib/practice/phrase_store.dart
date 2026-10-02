// The phrases somebody has recorded.
//
// Not per tune. A phrase belongs to the shape it was played over, not to
// the tune it happened to turn up in: a ii-V caught in All the Things is
// the same phrase in Stella, and filing it under one tune is how you lose
// it.
//
// The JSON holds the names and the facts, which are a few bytes. The audio
// sits in its own folder beside it, the way the takes and the imported
// sessions do, so the preferences stay small enough to be rewritten every
// time anything at all changes.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../music/phrase.dart';
import '../settings/progression_store.dart';
import 'recording_store.dart' show RecordingFiles;

class PhraseStore extends ChangeNotifier {
  PhraseStore._(this._storage, this.files, this._phrases);

  /// Nothing saved anywhere, for tests.
  PhraseStore.inMemory([List<Phrase>? phrases])
    : _storage = MemoryStorage(),
      files = null,
      _phrases = [...?phrases];

  static Future<PhraseStore> load({
    TextStorage? storage,
    RecordingFiles? files,
  }) async {
    final store = storage ?? preferencesStorage('phrases');
    final phrases = <Phrase>[];
    try {
      final text = await store.read();
      if (text != null) {
        for (final entry in (jsonDecode(text) as List)) {
          // A phrase that will not read is dropped rather than throwing:
          // it is never worth losing the rest of somebody's book.
          final phrase = Phrase.fromJson(entry as Map<String, Object?>);
          if (phrase != null) phrases.add(phrase);
        }
      }
    } catch (e) {
      debugPrint('Could not read the saved phrases: $e');
    }
    return PhraseStore._(store, files, phrases);
  }

  final TextStorage _storage;

  /// Where the audio lives. Null in tests that do not care about it.
  final RecordingFiles? files;

  final List<Phrase> _phrases;

  List<Phrase> get all => List.unmodifiable(_phrases);
  bool get isEmpty => _phrases.isEmpty;

  /// Reads the audio back, or null when the file has gone.
  Future<Uint8List?> audioOf(Phrase phrase) async =>
      files?.read(phrase.fileName);

  /// Where to record to, which the recorder needs before there is a
  /// phrase to speak of.
  Future<String?> pathFor(String fileName) async => files?.pathFor(fileName);

  Future<void> add(Phrase phrase, {Uint8List? audio}) async {
    if (audio != null) await files?.save(phrase.fileName, audio);
    _phrases.insert(0, phrase);
    await _write();
    notifyListeners();
  }

  Future<void> rename(Phrase phrase, String name) async {
    final at = _phrases.indexWhere((p) => p.id == phrase.id);
    if (at < 0) return;
    _phrases[at] = Phrase(
      id: phrase.id,
      name: name,
      fileName: phrase.fileName,
      key: phrase.key,
      seconds: phrase.seconds,
    );
    await _write();
    notifyListeners();
  }

  Future<void> remove(Phrase phrase) async {
    _phrases.removeWhere((p) => p.id == phrase.id);
    // The audio goes with it. A phrase is seconds of sound rather than
    // megabytes of session, but leaving orphans about is still litter.
    await files?.remove(phrase.fileName);
    await _write();
    notifyListeners();
  }

  Future<void> _write() async {
    try {
      await _storage.write(
        jsonEncode([for (final phrase in _phrases) phrase.toJson()]),
      );
    } catch (e) {
      debugPrint('Could not save the phrases: $e');
    }
  }
}
