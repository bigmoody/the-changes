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
// What plays is one each: a sound is chosen and plays everywhere, the way
// the built-in piano and upright do. What it is chosen from is a shelf.
//
// It used to be the file every time. Trying three pianos out of one font
// meant finding the file three times and scrolling to the sound three
// times, which is how this was asked for: "extremely tedious". So the
// .sf2 is kept once it has been brought in, with a list of what is in it,
// and every sound in every font on the shelf is a tap away from here and
// from the mixer.
//
// What plays is still the chosen preset written out on its own (see
// instrument_file.dart), so launch reads a few small files and never a
// hundred-megabyte font. The font is only opened when somebody picks
// something new out of it. The JSON holds names and lists, the way the
// takes and the licks do, so the things that are megabytes stay out of
// the preferences.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../audio/imported_kit.dart';
import '../audio/instrument_file.dart';
import '../audio/drum_patterns.dart' show Drum;
import '../audio/sample_bank.dart';
import '../audio/soundfont.dart';
import '../settings/progression_store.dart';
import 'recording_store.dart' show NoRecordingFiles, RecordingFiles;

/// What an imported sound is for.
enum SoundFontRole {
  chords('Chords', 'The Chords', 'The band\'s piano', 'instrument.tcsi'),
  bass('Bass', 'The Bass', 'The band\'s upright', 'bass.tcsi'),

  /// The arpeggios, which are a part of their own: they are what you
  /// play along to rather than what the band comps with, and hearing
  /// them on something other than the chords is most of the use of
  /// having them at all.
  arpeggio(
    'Arpeggios',
    'The Arpeggios',
    'Whatever plays the chords',
    'arpeggio.tcsi',
  ),
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

/// One sound in a font on the shelf: what it is called, and what it can
/// play.
class ShelvedSound {
  const ShelvedSound({
    required this.index,
    required this.name,
    required this.bank,
    required this.program,
    this.drums = const [],
  });

  /// Where it sits in the font's own table, which is how it is asked for.
  final int index;
  final String name;
  final int bank;
  final int program;

  /// The band's drums this kit has, worked out once when the font came in
  /// so that a drum row can list only the kits worth offering without
  /// opening every font to find out. Empty for anything with pitch.
  final List<Drum> drums;

  /// A drum kit rather than an instrument.
  bool get isKit => bank == 128;

  Map<String, Object?> toJson() => {
    'index': index,
    'name': name,
    'bank': bank,
    'program': program,
    if (drums.isNotEmpty) 'drums': [for (final drum in drums) drum.name],
  };

  static ShelvedSound fromJson(Map<String, Object?> json) => ShelvedSound(
    index: json['index'] as int,
    name: json['name'] as String,
    bank: json['bank'] as int,
    program: json['program'] as int,
    drums: [
      for (final name in (json['drums'] as List<Object?>?) ?? const [])
        ?Drum.values.asNameMap()[name],
    ],
  );
}

/// A SoundFont somebody brought in, kept so its sounds can be chosen again
/// without finding the file again.
class ShelvedFont {
  const ShelvedFont({
    required this.id,
    required this.name,
    required this.file,
    required this.size,
    required this.sounds,
  });

  final String id;

  /// What the font calls itself.
  final String name;

  /// What the file was called, which is how it is recognised if it is
  /// brought in a second time.
  final String file;

  /// How big it is, in bytes. It is a copy on the phone, and somebody
  /// running out of room should be able to see which one to let go.
  final int size;

  final List<ShelvedSound> sounds;

  /// Where the copy is kept.
  String get fileName => 'font-$id.sf2';

  /// The sounds with pitch, for the chords, the bass and the arpeggios.
  Iterable<ShelvedSound> get instruments => sounds.where((s) => !s.isKit);

  /// The kits the band can play: the ones with a drum where the General
  /// MIDI map puts it.
  Iterable<ShelvedSound> get kits =>
      sounds.where((s) => s.isKit && s.drums.isNotEmpty);

  /// A sound's name with the font's after it, because kits and pianos are
  /// named generically: two fonts both calling theirs "Drum Kit" would be
  /// indistinguishable in the very row that says where a drum is from.
  String nameOf(ShelvedSound sound) =>
      sound.name == name ? sound.name : '${sound.name} · $name';

  /// "12 instruments, 1 kit · 31 MB"
  String get summary {
    final pitched = instruments.length;
    final kitCount = kits.length;
    final parts = [
      if (pitched > 0)
        '$pitched ${pitched == 1 ? 'instrument' : 'instruments'}',
      if (kitCount > 0) '$kitCount ${kitCount == 1 ? 'kit' : 'kits'}',
      if (pitched == 0 && kitCount == 0) 'Nothing the band can play',
    ];
    final megabytes = size / (1024 * 1024);
    final big = megabytes >= 10
        ? '${megabytes.round()} MB'
        : megabytes >= 0.1
        ? '${megabytes.toStringAsFixed(1)} MB'
        : '${(size / 1024).ceil()} KB';
    return '${parts.join(', ')} · $big';
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'file': file,
    'size': size,
    'sounds': [for (final sound in sounds) sound.toJson()],
  };

  static ShelvedFont fromJson(Map<String, Object?> json) => ShelvedFont(
    id: json['id'] as String,
    name: json['name'] as String,
    file: json['file'] as String,
    size: json['size'] as int,
    sounds: [
      for (final sound in json['sounds'] as List<Object?>)
        ShelvedSound.fromJson(sound as Map<String, Object?>),
    ],
  );
}

class SoundFontStore extends ChangeNotifier {
  SoundFontStore._(
    this._storage,
    this._files,
    this._names,
    this._instruments,
    this._drums,
    this._drumNames,
    this._shelf,
    this._chosen,
  ) : _fontFiles = _files;

  /// Nothing saved anywhere, for tests.
  SoundFontStore.inMemory({
    SampledInstrument? chords,
    SampledInstrument? bass,
    SampledInstrument? arpeggio,
    Map<Drum, DrumSamples>? drums,
    String drumsName = 'Kit',
  }) : _storage = MemoryStorage(),
       _files = null,
       // The shelf needs somewhere to keep its fonts even in a test, or
       // nothing could be chosen off it twice.
       _fontFiles = NoRecordingFiles(),
       _shelf = [],
       _chosen = {},
       _drums = {...?drums},
       _drumNames = {
         for (final drum in drums?.keys ?? const <Drum>[]) drum: drumsName,
       },
       _names = {
         SoundFontRole.chords: ?chords?.name,
         SoundFontRole.bass: ?bass?.name,
         SoundFontRole.arpeggio: ?arpeggio?.name,
       },
       _instruments = {
         SoundFontRole.chords: ?chords,
         SoundFontRole.bass: ?bass,
         SoundFontRole.arpeggio: ?arpeggio,
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
    final shelf = <ShelvedFont>[];
    final chosen = <String, String>{};
    String? text;
    try {
      text = await store.read();
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
    // The shelf on its own, so a list that will not read loses the list
    // and not the sounds that are playing.
    try {
      if (text != null && files != null) {
        final saved = jsonDecode(text) as Map<String, Object?>;
        for (final font in (saved['shelf'] as List<Object?>?) ?? const []) {
          shelf.add(ShelvedFont.fromJson(font as Map<String, Object?>));
        }
        final picked = saved['chosen'] as Map<String, Object?>?;
        for (final e
            in picked?.entries ?? const <MapEntry<String, Object?>>[]) {
          if (e.value case final String from) chosen[e.key] = from;
        }
      }
    } catch (e) {
      debugPrint('Could not read the shelf of SoundFonts: $e');
      shelf.clear();
      chosen.clear();
    }
    return SoundFontStore._(
      store,
      files,
      names,
      instruments,
      drums,
      drumNames,
      shelf,
      chosen,
    );
  }

  final TextStorage _storage;
  final RecordingFiles? _files;

  /// Where the fonts on the shelf are kept.
  final RecordingFiles? _fontFiles;

  final List<ShelvedFont> _shelf;

  /// Which sound off the shelf each part is playing, as "font/index", so
  /// the list it is chosen from can say which one is on. Keyed by the
  /// role's name, or "drum:" and the drum's.
  final Map<String, String> _chosen;

  /// The font last opened, held so that trying one sound after another
  /// out of it does not read a hundred megabytes off the disk each time.
  /// Only the one: holding them all would hold them all in memory.
  (String, SoundFont)? _opened;
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

  /// The font for the arpeggios, where somebody has imported one of
  /// their own for them. Null means they play whatever the chords do.
  SampledInstrument? get arpeggio => _instruments[SoundFontRole.arpeggio];

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
  Future<void> keep(
    SoundFontRole role,
    SampledInstrument instrument, {
    String? from,
  }) async {
    _instruments[role] = instrument;
    _names[role] = instrument.name;
    _mark(role.name, from);
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
  Future<void> keepKit(
    String name,
    Map<Drum, DrumSamples> kit, {
    String? from,
  }) async {
    for (final entry in kit.entries) {
      _drums[entry.key] = entry.value;
      _drumNames[entry.key] = name;
      _mark('drum:${entry.key.name}', from);
    }
    await _saveDrums();
  }

  /// Keeps one drum out of [name]'s kit, and touches no other.
  Future<void> keepDrum(
    Drum drum,
    String name,
    DrumSamples samples, {
    String? from,
  }) async {
    _drums[drum] = samples;
    _drumNames[drum] = name;
    _mark('drum:${drum.name}', from);
    await _saveDrums();
  }

  /// Sends one drum back to the band's own.
  Future<void> forgetDrum(Drum drum) async {
    _drums.remove(drum);
    _drumNames.remove(drum);
    _chosen.remove('drum:${drum.name}');
    await _saveDrums();
  }

  /// Throws one away, and that part goes back to the band's own sound.
  Future<void> forget(SoundFontRole role) async {
    if (role == SoundFontRole.drums) {
      _drums.clear();
      _drumNames.clear();
      _chosen.removeWhere((key, _) => key.startsWith('drum:'));
      await _saveDrums();
      return;
    }
    _instruments.remove(role);
    _names.remove(role);
    _chosen.remove(role.name);
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
    _chosen.clear();
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
      if (_shelf.isNotEmpty)
        'shelf': [for (final font in _shelf) font.toJson()],
      if (_chosen.isNotEmpty) 'chosen': _chosen,
    }),
  );

  void _mark(String key, String? from) {
    if (from == null) {
      _chosen.remove(key);
    } else {
      _chosen[key] = from;
    }
  }

  static String _from(ShelvedFont font, ShelvedSound sound) =>
      '${font.id}/${sound.index}';

  // ── The shelf ──────────────────────────────────────────────────────────

  /// Every font brought in, in the order they came.
  List<ShelvedFont> get shelf => List.unmodifiable(_shelf);

  /// Whether there is anything on the shelf with pitch, so the mixer can
  /// offer it.
  bool get hasInstrumentsToChoose =>
      _shelf.any((f) => f.instruments.isNotEmpty);

  /// Whether there is a kit on the shelf.
  bool get hasKitsToChoose => _shelf.any((f) => f.kits.isNotEmpty);

  /// Whether [sound] out of [font] is what [role] is playing.
  bool isPlaying(SoundFontRole role, ShelvedFont font, ShelvedSound sound) =>
      _chosen[role.name] == _from(font, sound);

  /// Whether [drum] is the one out of [font]'s [sound].
  bool isPlayingDrum(Drum drum, ShelvedFont font, ShelvedSound sound) =>
      _chosen['drum:${drum.name}'] == _from(font, sound);

  /// Whether every drum [sound] has is the one out of it, which is what a
  /// whole kit being on means.
  bool isPlayingKit(ShelvedFont font, ShelvedSound sound) =>
      sound.drums.isNotEmpty &&
      sound.drums.every((drum) => isPlayingDrum(drum, font, sound));

  /// Puts a file on the shelf, and says what is in it.
  ///
  /// The same file brought in twice is the one already there: a second
  /// copy of a hundred megabytes helps nobody. Throws a
  /// [SoundFontException] for a file that will not read, before anything
  /// is kept.
  Future<ShelvedFont> add(String fileName, Uint8List bytes) async {
    for (final font in _shelf) {
      if (font.file == fileName && font.size == bytes.length) return font;
    }
    final font = SoundFont.read(bytes, fileName: fileName);
    final sounds = [
      for (final preset in font.presets)
        ShelvedSound(
          index: preset.index,
          name: preset.name,
          bank: preset.bank,
          program: preset.program,
          drums: preset.isPercussion ? _drumsIn(font, preset) : const [],
        ),
    ];
    final shelved = ShelvedFont(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: font.name,
      file: fileName,
      size: bytes.length,
      sounds: sounds,
    );
    await _fontFiles?.save(shelved.fileName, bytes);
    _shelf.add(shelved);
    _opened = (shelved.id, font);
    await _write();
    notifyListeners();
    return shelved;
  }

  static List<Drum> _drumsIn(SoundFont font, SoundFontPreset preset) {
    try {
      return kitFromGeneralMidi(font.drumKitFor(preset)).keys.toList();
    } on SoundFontException {
      return const [];
    }
  }

  /// Takes a font off the shelf and off the phone.
  ///
  /// Whatever is already playing out of it keeps playing: that was
  /// written out on its own when it was chosen. It just cannot be chosen
  /// again without bringing the file back.
  Future<void> remove(ShelvedFont font) async {
    _shelf.removeWhere((f) => f.id == font.id);
    _chosen.removeWhere((_, from) => from.startsWith('${font.id}/'));
    if (_opened?.$1 == font.id) _opened = null;
    await _fontFiles?.remove(font.fileName);
    await _write();
    notifyListeners();
  }

  /// The whole font, read, for looking in or taking a sound out of.
  Future<SoundFont> open(ShelvedFont font) async {
    if (_opened case (final id, final read) when id == font.id) return read;
    final bytes = await _fontFiles?.read(font.fileName);
    if (bytes == null) {
      throw SoundFontException(
        'The copy of ${font.name} has gone from the phone. Add the file '
        'again to choose from it.',
      );
    }
    final read = SoundFont.read(bytes, fileName: font.file);
    _opened = (font.id, read);
    return read;
  }

  Future<SoundFontPreset> _presetIn(
    ShelvedFont font,
    ShelvedSound sound,
  ) async {
    final read = await open(font);
    for (final preset in read.presets) {
      if (preset.index == sound.index) return preset;
    }
    throw SoundFontException('${sound.name} is no longer in ${font.name}.');
  }

  /// Puts [sound] out of [font] on [role].
  Future<void> choose(
    SoundFontRole role,
    ShelvedFont font,
    ShelvedSound sound,
  ) async {
    final read = await open(font);
    final instrument = read.instrumentFor(await _presetIn(font, sound));
    await keep(role, instrument, from: _from(font, sound));
  }

  Future<Map<Drum, DrumSamples>> _kit(
    ShelvedFont font,
    ShelvedSound sound,
  ) async {
    final read = await open(font);
    return kitFromGeneralMidi(read.drumKitFor(await _presetIn(font, sound)));
  }

  /// Puts [drum] out of the kit [sound] in [font] on the band's kit, and
  /// touches no other drum.
  Future<void> chooseDrum(
    Drum drum,
    ShelvedFont font,
    ShelvedSound sound,
  ) async {
    final kit = await _kit(font, sound);
    final samples = kit[drum];
    if (samples == null) {
      throw SoundFontException(
        '${sound.name} has no ${drum.label.toLowerCase()}.',
      );
    }
    await keepDrum(drum, font.nameOf(sound), samples, from: _from(font, sound));
  }

  /// Puts every drum the kit [sound] has on the band's kit.
  Future<void> chooseKit(ShelvedFont font, ShelvedSound sound) async {
    final kit = await _kit(font, sound);
    if (kit.isEmpty) {
      throw SoundFontException(
        '${sound.name} has no drums where the General MIDI map puts them, '
        'so the band would not know what to hit.',
      );
    }
    await keepKit(font.nameOf(sound), kit, from: _from(font, sound));
  }
}
