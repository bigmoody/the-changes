// The instrument somebody imported, and where it lives.
//
// One at a time, on purpose. A font is chosen in Settings and plays
// everywhere, the way the piano and the guitar do; a shelf of them would
// be a different feature, and nobody has asked for it.
//
// What is kept is the chosen preset written out on its own (see
// instrument_file.dart), not the .sf2 it came from. The JSON holds its
// name and the file's, the way the takes and the licks do, so the thing
// that is megabytes stays out of the preferences.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../audio/instrument_file.dart';
import '../audio/sample_bank.dart';
import '../settings/progression_store.dart';
import 'recording_store.dart' show RecordingFiles;

class SoundFontStore extends ChangeNotifier {
  SoundFontStore._(this._storage, this._files, this._name, this._instrument);

  /// Nothing saved anywhere, for tests.
  SoundFontStore.inMemory({SampledInstrument? instrument, String? name})
    : _storage = MemoryStorage(),
      _files = null,
      _name = name ?? instrument?.name,
      _instrument = instrument;

  static const _fileName = 'instrument.tcsi';

  static Future<SoundFontStore> load({
    TextStorage? storage,
    RecordingFiles? files,
  }) async {
    final store = storage ?? preferencesStorage('soundfont');
    String? name;
    SampledInstrument? instrument;
    try {
      final text = await store.read();
      if (text != null && files != null) {
        final saved = jsonDecode(text) as Map<String, Object?>;
        name = saved['name'] as String?;
        final bytes = await files.read(_fileName);
        if (bytes != null) instrument = readInstrument(bytes);
      }
    } catch (e) {
      // A font that will not read is dropped rather than throwing. The
      // band falls back to the piano, which is a worse sound and not a
      // broken app.
      debugPrint('Could not read the imported instrument: $e');
      name = null;
      instrument = null;
    }
    return SoundFontStore._(store, files, name, instrument);
  }

  final TextStorage _storage;
  final RecordingFiles? _files;
  String? _name;
  SampledInstrument? _instrument;

  /// What it is called, for the row in Settings.
  String? get name => _name;

  /// The instrument itself, or null when nothing has been imported.
  SampledInstrument? get instrument => _instrument;

  bool get hasOne => _instrument != null;

  /// Keeps [instrument], replacing whatever was there.
  Future<void> keep(SampledInstrument instrument) async {
    _instrument = instrument;
    _name = instrument.name;
    await _files?.save(_fileName, writeInstrument(instrument));
    await _storage.write(jsonEncode({'name': instrument.name}));
    notifyListeners();
  }

  /// Throws it away, and the band goes back to its own piano.
  Future<void> forget() async {
    _instrument = null;
    _name = null;
    await _files?.remove(_fileName);
    await _storage.write(jsonEncode(<String, Object?>{}));
    notifyListeners();
  }
}
