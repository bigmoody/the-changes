// The instruments somebody imported, and where they live.
//
// One for the chords, one for the bass, and the drums one at a time. A
// piano and a bass are two different files, so a single slot would mean
// importing a bass threw away the piano chosen last week, which nobody
// would expect.
//
// The drums go further: a kit is ten drums and there is no reason to take
// all ten from the same place. A snare out of one kit and cymbals out of
// another is how people build a kit, so each drum keeps its own samples
// and remembers which kit it came from.
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
  chords('Chords', 'The Chords', 'The band\'s piano', 'instrument.tcsi'),
  bass('Bass', 'The Bass', 'The band\'s upright', 'bass.tcsi'),
  drums('Drums', 'The Drums', 'The band\'s own kit', 'drums.tcsi');

  const SoundFontRole(this.label, this.part, this.ours, this.fileName);

  final String label;

  /// What to call the part on screen, as a thing the band has.
  final String part;

  /// What plays it when nothing has been imported for it.
  final String ours;

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
    this._drumNames,
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
       _drumNames = {
         for (final drum in drums?.keys ?? const <Drum>[]) drum: drumsName,
       },
       _names = {
         SoundFontRole.chords: ?chords?.name,
         SoundFontRole.bass: ?bass?.name,
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
    final drumNames = <Drum, String>{};
    try {
      final text = await store.read();
      if (text != null && files != null) {
        final saved = jsonDecode(text) as Map<String, Object?>;
        for (final role in SoundFontRole.values) {
          // 'name' without a role is what the chords were saved under
          // before the bass existed.
          final name =
              saved[role.name] as String? ??
              (role == SoundFontRole.chords
                  ? saved['name'] as String?
                  : null) ??
              // The drums are named per drum now, so the old single name
              // may be gone while the file is still there.
              (role == SoundFontRole.drums && saved['drumsBy'] != null
                  ? 'Imported'
                  : null);
          if (name == null) continue;
          final bytes = await files.read(role.fileName);
          if (bytes == null) continue;
          if (role == SoundFontRole.drums) {
            drums = readKit(bytes);
            // Which kit each drum came from. A file saved before the
            // drums could be chosen one at a time has one name for the
            // lot, which is what it was.
            final by = saved['drumsBy'] as Map<String, Object?>?;
            for (final drum in drums.keys) {
              drumNames[drum] = by?[drum.name] as String? ?? name;
            }
          } else {
            names[role] = name;
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
      drumNames.clear();
    }
    return SoundFontStore._(store, files, names, instruments, drums, drumNames);
  }

  final TextStorage _storage;
  final RecordingFiles? _files;
  final Map<SoundFontRole, String> _names;
  final Map<SoundFontRole, SampledInstrument> _instruments;

  /// The drums are their own shape: ten of them, each choosable on its
  /// own, so they do not fit beside the others.
  final Map<Drum, DrumSamples> _drums;

  /// Which kit each drum came out of, so a row can say where it is from.
  final Map<Drum, String> _drumNames;

  /// What the sound for [role] is called, for the row in Settings.
  String? nameFor(SoundFontRole role) => _names[role];

  SampledInstrument? instrumentFor(SoundFontRole role) => _instruments[role];

  bool has(SoundFontRole role) => role == SoundFontRole.drums
      ? _drums.isNotEmpty
      : _instruments.containsKey(role);

  SampledInstrument? get chords => _instruments[SoundFontRole.chords];
  SampledInstrument? get bass => _instruments[SoundFontRole.bass];

  /// The imported drums, drum by drum. Empty when there are none.
  Map<Drum, DrumSamples> get drums => _drums;

  /// Which kit [drum] came out of, or null when it is the band's own.
  String? nameForDrum(Drum drum) => _drumNames[drum];

  bool hasDrum(Drum drum) => _drums.containsKey(drum);

  /// The drums in one line, for a row that has no room for ten.
  ///
  /// The kit's name when they all came from one, because that is the
  /// usual case and naming it is more use than counting. Otherwise how
  /// many, since listing four kits in a subtitle helps nobody.
  String? get drumsFrom {
    if (_drumNames.isEmpty) return null;
    final kits = _drumNames.values.toSet();
    if (kits.length == 1) return kits.single;
    return '${_drums.length} drums from ${kits.length} kits';
  }

  /// Whether anything at all has been imported.
  bool get anything => SoundFontRole.values.any(has);

  /// Keeps [instrument] as the sound for [role], replacing whatever was
  /// there.
  Future<void> keep(SoundFontRole role, SampledInstrument instrument) async {
    _instruments[role] = instrument;
    _names[role] = instrument.name;
    await _files?.save(role.fileName, writeInstrument(instrument));
    await _write();
    notifyListeners();
  }

  /// Keeps every drum in [kit], replacing whatever was on those drums and
  /// leaving the rest where they were.
  ///
  /// Taking a whole kit no longer clears the others. Somebody who has
  /// found a snare they like and then imports a kit for the cymbals
  /// should keep the snare unless the new kit has one of its own.
  Future<void> keepKit(String name, Map<Drum, DrumSamples> kit) async {
    for (final entry in kit.entries) {
      _drums[entry.key] = entry.value;
      _drumNames[entry.key] = name;
    }
    await _saveDrums();
  }

  /// Keeps one drum out of [name]'s kit, and touches no other.
  Future<void> keepDrum(Drum drum, String name, DrumSamples samples) async {
    _drums[drum] = samples;
    _drumNames[drum] = name;
    await _saveDrums();
  }

  /// Sends one drum back to the band's own.
  Future<void> forgetDrum(Drum drum) async {
    _drums.remove(drum);
    _drumNames.remove(drum);
    await _saveDrums();
  }

  /// Throws one away, and that part goes back to the band's own sound.
  Future<void> forget(SoundFontRole role) async {
    if (role == SoundFontRole.drums) {
      _drums.clear();
      _drumNames.clear();
      await _saveDrums();
      return;
    }
    _instruments.remove(role);
    _names.remove(role);
    await _files?.remove(role.fileName);
    await _write();
    notifyListeners();
  }

  /// Sends the whole band back to its own instruments.
  ///
  /// One call rather than seven trips through the list, and one write
  /// rather than seven: somebody who has been trying sounds out and wants
  /// to hear the band again should not have to undo it a drum at a time.
  Future<void> forgetEverything() async {
    _instruments.clear();
    _names.clear();
    _drums.clear();
    _drumNames.clear();
    for (final role in SoundFontRole.values) {
      await _files?.remove(role.fileName);
    }
    await _write();
    notifyListeners();
  }

  Future<void> _saveDrums() async {
    if (_drums.isEmpty) {
      await _files?.remove(SoundFontRole.drums.fileName);
    } else {
      await _files?.save(SoundFontRole.drums.fileName, writeKit(_drums));
    }
    await _write();
    notifyListeners();
  }

  Future<void> _write() => _storage.write(
    jsonEncode({
      for (final e in _names.entries) e.key.name: e.value,
      // Per drum, because each one can come from a different kit now.
      if (_drumNames.isNotEmpty)
        'drumsBy': {for (final e in _drumNames.entries) e.key.name: e.value},
    }),
  );
}
