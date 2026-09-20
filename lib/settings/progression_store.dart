// The progressions a player has written, saved on the device.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../music/user_progression.dart';

/// Somewhere to keep one string. On a device it's the app's preferences; in
/// tests it's a variable.
abstract interface class TextStorage {
  Future<String?> read();
  Future<void> write(String text);
}

class _PreferencesStorage implements TextStorage {
  _PreferencesStorage(this._preferences, this._key);

  final SharedPreferencesAsync _preferences;
  final String _key;

  @override
  Future<String?> read() => _preferences.getString(_key);

  @override
  Future<void> write(String text) => _preferences.setString(_key, text);
}

/// One string kept in the app's preferences under [key].
TextStorage preferencesStorage(String key) =>
    _PreferencesStorage(SharedPreferencesAsync(), key);

/// Holds everything in memory, for tests.
class MemoryStorage implements TextStorage {
  MemoryStorage([this.text]);

  String? text;

  @override
  Future<String?> read() async => text;

  @override
  Future<void> write(String text) async => this.text = text;
}

class ProgressionStore extends ChangeNotifier {
  ProgressionStore._(this._storage, this._items);

  /// Nothing saved anywhere, for tests.
  ProgressionStore.inMemory([List<UserProgression>? items])
    : _storage = MemoryStorage(),
      _items = [...?items];

  /// Reads the saved progressions. If they can't be read, starts empty
  /// rather than stopping the app.
  static Future<ProgressionStore> load([TextStorage? storage]) async {
    final store = storage ?? preferencesStorage('userProgressions');
    var items = <UserProgression>[];
    try {
      final text = await store.read();
      if (text != null) {
        items = [
          for (final json in jsonDecode(text) as List)
            UserProgression.fromJson(json as Map<String, dynamic>),
        ];
      }
    } catch (e) {
      debugPrint('Could not read saved progressions: $e');
    }
    return ProgressionStore._(store, items);
  }

  final TextStorage _storage;
  final List<UserProgression> _items;

  /// Everything saved, by title.
  List<UserProgression> get all => [..._items]
    ..sort(
      (a, b) =>
          a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()),
    );

  UserProgression? byId(String id) =>
      _items.where((p) => p.id == id).firstOrNull;

  /// A new id that isn't in use — unique even when several are made in the
  /// same instant, as an import does.
  String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_made++}';
  var _made = 0;

  /// Adds [progression], or replaces the saved one with the same id.
  Future<void> save(UserProgression progression) async {
    final saved = UserProgression.fromJson(progression.toJson()); // a copy
    final index = _items.indexWhere((p) => p.id == saved.id);
    if (index == -1) {
      _items.add(saved);
    } else {
      _items[index] = saved;
    }
    notifyListeners();
    await _write();
  }

  /// Adds [progressions] as new ones, each with a fresh id, with a single
  /// save — an imported playlist can hold hundreds.
  Future<void> addAll(Iterable<UserProgression> progressions) async {
    for (final progression in progressions) {
      _items.add(
        UserProgression.fromJson({...progression.toJson(), 'id': newId()}),
      );
    }
    notifyListeners();
    await _write();
  }

  /// Throws away everything saved and puts [progressions] in its place,
  /// keeping their ids — restoring a backup rather than adding to one.
  Future<void> replaceAllWith(Iterable<UserProgression> progressions) async {
    _items
      ..clear()
      ..addAll([
        for (final progression in progressions)
          UserProgression.fromJson(progression.toJson()),
      ]);
    notifyListeners();
    await _write();
  }

  Future<void> delete(String id) => deleteAll({id});

  /// Deletes several at once, with a single save.
  Future<void> deleteAll(Set<String> ids) async {
    _items.removeWhere((p) => ids.contains(p.id));
    notifyListeners();
    await _write();
  }

  Future<void> _write() async {
    try {
      await _storage.write(jsonEncode([for (final p in _items) p.toJson()]));
    } catch (e) {
      debugPrint('Could not save progressions: $e');
    }
  }
}
