// The licks somebody has saved.
//
// Not per tune, unlike the imported parts and the recordings. A lick
// belongs to the changes it was played over, not to the tune it happened
// to turn up in: a ii-V lick found in All the Things is the same lick in
// Stella, and filing it under one tune is how you lose it.
//
// The notes go in the JSON, which is small: a lick is a dozen notes, not
// a chorus. The recording of it, where there is one, sits in a folder
// beside it like the takes and the imported sessions do.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../music/lick.dart';
import '../settings/progression_store.dart';
import 'recording_store.dart';

class LickStore extends ChangeNotifier {
  LickStore._(this._storage, this.files, this._licks);

  /// Nothing saved anywhere, for tests.
  LickStore.inMemory([List<Lick>? licks])
    : _storage = MemoryStorage(),
      files = NoRecordingFiles(),
      _licks = [...?licks];

  static Future<LickStore> load({
    TextStorage? storage,
    required RecordingFiles files,
  }) async {
    final store = storage ?? preferencesStorage('licks');
    final licks = <Lick>[];
    try {
      final text = await store.read();
      if (text != null) {
        for (final entry in jsonDecode(text) as List) {
          // One lick that will not read is dropped rather than throwing:
          // it is never worth losing the rest of somebody's book.
          if (entry is Map<String, dynamic>) {
            final lick = Lick.fromJson(entry);
            if (lick != null) licks.add(lick);
          }
        }
      }
    } catch (e) {
      debugPrint('Could not read the saved licks: $e');
    }
    return LickStore._(store, files, licks);
  }

  final TextStorage _storage;
  final RecordingFiles files;
  final List<Lick> _licks;

  /// Everything saved, newest first.
  List<Lick> get all => [..._licks]..sort((a, b) => b.at.compareTo(a.at));

  int get count => _licks.length;

  Lick? byId(String id) => _licks.where((lick) => lick.id == id).firstOrNull;

  String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_made++}';
  var _made = 0;

  Future<void> add(Lick lick) async {
    _licks.add(lick);
    notifyListeners();
    await _write();
  }

  /// Puts [lick] in place of the one with the same id, or adds it.
  Future<void> put(Lick lick) async {
    final at = _licks.indexWhere((one) => one.id == lick.id);
    if (at < 0) return add(lick);
    _licks[at] = lick;
    notifyListeners();
    await _write();
  }

  /// Takes one out, and its recording with it.
  Future<void> remove(String id) async {
    final going = _licks.where((lick) => lick.id == id).toList();
    _licks.removeWhere((lick) => lick.id == id);
    notifyListeners();
    for (final lick in going) {
      if (lick.recording case final file?) {
        try {
          await files.remove(file);
        } catch (e) {
          debugPrint('Could not delete a lick recording: $e');
        }
      }
    }
    await _write();
  }

  Future<String> keep(String id, Uint8List bytes) =>
      files.save('$id.wav', bytes);

  Future<String?> pathOf(String name) => files.pathOf(name);

  List<Map<String, Object?>> toJson() => [
    for (final lick in _licks) lick.toJson(),
  ];

  Future<void> _write() async {
    try {
      await _storage.write(jsonEncode(toJson()));
    } catch (e) {
      debugPrint('Could not save the licks: $e');
    }
  }
}
