// The instruments somebody imported, and where they live.
//
// Two of them: one to play the chords, one to play the bass. A piano and
// a bass are two different files, so one slot would mean importing a bass
// threw away the piano chosen last week, which nobody would expect.
//
// One each rather than a shelf, on purpose. A sound is chosen in Settings
// and plays everywhere, the way the built-in piano and upright do; a
// library of them to switch between is a different feature and nobody has
// asked for it.
//
// What is kept is the chosen preset written out on its own (see
// instrument_file.dart), not the .sf2 it came from. The JSON holds their
// names, the way the takes and the licks do, so the thing that is
// megabytes stays out of the preferences.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../audio/instrument_file.dart';
import '../audio/drum_patterns.dart' show Drum;
import '../audio/sample_bank.dart';
import '../settings/progression_store.dart';
import 'recording_store.dart' show RecordingFiles;

/// What an imported sound is for.
enum SoundFontRole {
  chords('Chords', 'instrument.tcsi'),
  bass('Bass', 'bass.tcsi'),
  drums('Drums', 'drums.tcsi');

  const SoundFontRole(this.label, this.fileName);

  final String label;

  /// Its own file. 'instrument.tcsi' is what the chords were called before
  /// there was a bass, and renaming it would throw away anybody's import
  /// for nothing.
  final String fileName;
}

class SoundFontStore extends ChangeNotifier {
  SoundFontStore._(
    this._storage,
    this._files,
    this._names,
    this._instruments,
    this._drums,
  );

  /// Nothing saved anywhere, for tests.
  SoundFontStore.inMemory({
    SampledInstrument? chords,
    SampledInstrument? bass,
    Map<Drum, DrumSamples>? drums,
    String drumsName = 'Kit',
  }) : _storage = MemoryStorage(),
       _files = null,
       _drums = {...?drums},
       _names = {
         SoundFontRole.chords: ?chords?.name,
         SoundFontRole.bass: ?bass?.name,
         // A kit with no name would leave the row in Settings saying there
         // is not one while there is.
         if (drums != null && drums.isNotEmpty) SoundFontRole.drums: drumsName,
       },
       _instruments = {
         SoundFontRole.chords: ?chords,
         SoundFontRole.bass: ?bass,
       };

  static Future<SoundFontStore> load({
    TextStorage? storage,
    RecordingFiles? files,
  }) async {
    final store = storage ?? preferencesStorage('soundfont');
    final names = <SoundFontRole, String>{};
    final instruments = <SoundFontRole, SampledInstrument>{};
    var drums = <Drum, DrumSamples>{};
    try {
      final text = await store.read();
      if (text != null && files != null) {
        final saved = jsonDecode(text) as Map<String, Object?>;
        for (final role in SoundFontRole.values) {
          // 'name' without a role is what the chords were saved under
          // before the bass existed.
          final name =
              saved[role.name] as String? ??
              (role == SoundFontRole.chords ? saved['name'] as String? : null);
          if (name == null) continue;
          final bytes = await files.read(role.fileName);
          if (bytes == null) continue;
          names[role] = name;
          if (role == SoundFontRole.drums) {
            drums = readKit(bytes);
          } else {
            instruments[role] = readInstrument(bytes);
          }
        }
      }
    } catch (e) {
      // A font that will not read is dropped rather than throwing. The
      // band falls back to its own instruments, which is a different
      // sound and not a broken app.
      debugPrint('Could not read the imported instruments: $e');
      names.clear();
      instruments.clear();
      drums = {};
    }
    return SoundFontStore._(store, files, names, instruments, drums);
  }

  final TextStorage _storage;
  final RecordingFiles? _files;
  final Map<SoundFontRole, String> _names;
  final Map<SoundFontRole, SampledInstrument> _instruments;

  /// The drums are their own shape: ten drums rather than one instrument,
  /// so they do not fit beside the others.
  final Map<Drum, DrumSamples> _drums;

  /// What the sound for [role] is called, for the row in Settings.
  String? nameFor(SoundFontRole role) => _names[role];

  SampledInstrument? instrumentFor(SoundFontRole role) => _instruments[role];

  bool has(SoundFontRole role) => role == SoundFontRole.drums
      ? _drums.isNotEmpty
      : _instruments.containsKey(role);

  SampledInstrument? get chords => _instruments[SoundFontRole.chords];
  SampledInstrument? get bass => _instruments[SoundFontRole.bass];

  /// The imported kit, drum by drum. Empty when there is not one.
  Map<Drum, DrumSamples> get drums => _drums;

  /// Keeps [instrument] as the sound for [role], replacing whatever was
  /// there.
  Future<void> keep(SoundFontRole role, SampledInstrument instrument) async {
    _instruments[role] = instrument;
    _names[role] = instrument.name;
    await _files?.save(role.fileName, writeInstrument(instrument));
    await _write();
    notifyListeners();
  }

  /// Keeps [kit] as the drums, replacing whatever was there.
  Future<void> keepKit(String name, Map<Drum, DrumSamples> kit) async {
    _drums
      ..clear()
      ..addAll(kit);
    _names[SoundFontRole.drums] = name;
    await _files?.save(SoundFontRole.drums.fileName, writeKit(kit));
    await _write();
    notifyListeners();
  }

  /// Throws one away, and that part goes back to the band's own sound.
  Future<void> forget(SoundFontRole role) async {
    if (role == SoundFontRole.drums) _drums.clear();
    _instruments.remove(role);
    _names.remove(role);
    await _files?.remove(role.fileName);
    await _write();
    notifyListeners();
  }

  Future<void> _write() => _storage.write(
    jsonEncode({for (final e in _names.entries) e.key.name: e.value}),
  );
}
