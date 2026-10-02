import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'chord_colours.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../music/chord.dart';
import '../audio/arpeggios.dart';
import '../music/chord_drill.dart';
import '../practice/hiding_the_chart.dart';
import '../music/tune.dart';
import '../audio/backing_synth.dart';

/// Which instrument the charts are written for.
///
/// Many horns are "transposing instruments": when a trumpet player reads a C,
/// a B♭ comes out. So a trumpeter playing with a band in B♭ needs a chart in C.
/// This only changes the chord symbols on screen; the band always plays at
/// concert pitch so everyone sounds in the same key.
enum ChartInstrument {
  concert(
    symbol: 'C',
    name: 'Concert pitch',
    examples: 'Piano, guitar, bass, flute, trombone, vocals',
    semitones: 0,
  ),
  bFlat(
    symbol: 'B♭',
    name: 'B♭ instruments',
    examples: 'Trumpet, tenor & soprano sax, clarinet',
    semitones: 2,
  ),
  eFlat(
    symbol: 'E♭',
    name: 'E♭ instruments',
    examples: 'Alto & baritone sax',
    semitones: 9,
  ),
  f(symbol: 'F', name: 'F instruments', examples: 'French horn', semitones: 7);

  const ChartInstrument({
    required this.symbol,
    required this.name,
    required this.examples,
    required this.semitones,
  });

  final String symbol;
  final String name;
  final String examples;

  /// How far the written chart is above concert pitch.
  final int semitones;

  /// The same move as a letter-aware transposition, so notes are spelled
  /// the way the player reads them: a whole step (1 letter), a major 6th
  /// (5 letters) or a perfect 5th (4 letters).
  Transposition get transposition => Transposition(
    letterSteps: switch (this) {
      concert => 0,
      bFlat => 1,
      eFlat => 5,
      f => 4,
    },
    semitones: semitones,
  );
}

/// Whether to show where the chord sits under your hands while you play.
enum ChordDiagram {
  none('Off'),
  keyboard('Keyboard'),
  guitar('Guitar'),
  barre('Guitar – barre chords'),
  bass('Bass');

  const ChordDiagram(this.label);

  final String label;
}

/// A small line written under each chord on the chart, to learn by.
///
/// One choice rather than several switches, because they all want the same
/// bit of room under the chord and two at once would be a muddle.
enum ChordAid {
  off('Off'),

  /// What the chord is in the key: ii7, V7, IΔ7.
  roman('Roman Numerals'),

  /// The same, the way Nashville writes it: 2-7, 5, 1Δ7.
  nashville('Nashville Numbers'),

  /// The 3rd and the 7th: the notes that make the chord sound like
  /// itself, and the ones that move least between changes.
  guideTones('Guide Tones');

  const ChordAid(this.label);

  final String label;

  /// A word or two for the chip on the chart, where there is no room for
  /// the full name.
  String get short => switch (this) {
    off => '',
    roman => 'I–vi–ii–V',
    nashville => '1-6-2-5',
    guideTones => '3rd & 7th',
  };

  /// What the small red line under each chord actually is.
  ///
  /// Without this it is a row of letters nobody asked for: you turn the
  /// setting on once, forget, and are left reading "C F" under a Dm7 with
  /// nothing on screen to say what that is.
  String get legend => switch (this) {
    off => '',
    roman =>
      'The small red line under each chord says what it is in the key, '
          'in roman numerals.',
    nashville =>
      'The small red line under each chord says what it is in the key, '
          'as numbers.',
    guideTones =>
      'The small red notes under each chord are its guide tones: the 3rd '
          'and the 7th, the two that move least between changes.',
  };
}

/// App-wide preferences, saved on the device so they survive restarts.
class AppSettings extends ChangeNotifier {
  AppSettings._(
    this._storage,
    this._instrument,
    this._mixWithOthers,
    this._diagram,
    this._aimFor,
    this._comping,
    this._bassSound,
    this._drumSound,
    this._chordColours,
    this._colourChords,
    this._splitEnharmonics,
    this._paper,
    this._arpeggioSound,
    this._arpeggioStart,
    this._metronomeTempo,
    this._metronomeBeats,
    this._metronomeSubdivision,
    this._metronomeClickOn,
    this._metronomeDropout,
    this._fadeChart,
    this._takesWithBand,
    this._chordAid,
  );

  /// Settings that aren't saved anywhere, for tests.
  AppSettings.inMemory([
    this._instrument = ChartInstrument.concert,
    this._diagram = ChordDiagram.none,
    this._aimFor,
    this._comping = Comping.piano,
    this._bassSound = BassSound.upright,
    this._drumSound = DrumSound.kit,
    this._chordColours = const ChordColours(),
    this._colourChords = true,
    this._paper,
    this._arpeggioSound = Comping.piano,
    this._arpeggioStart = ArpeggioStart.root,
    this._splitEnharmonics = false,
  ]) : _storage = null,
       _chordAid = ChordAid.off,
       _mixWithOthers = true,
       _metronomeTempo = 120,
       _metronomeBeats = 4,
       _metronomeSubdivision = Subdivision.quarters,
       _metronomeClickOn = ClickOn.everyBeat,
       _metronomeDropout = Dropout.none,
       _fadeChart = FadeChart.never,
       _takesWithBand = true;

  static const _instrumentKey = 'chartInstrument';
  static const _mixKey = 'mixWithOthers';
  static const _takesBandKey = 'takesWithBand';
  static const _diagramKey = 'chordDiagram';
  static const _aimKey = 'aimFor';
  static const _compingKey = 'comping';
  static const _bassSoundKey = 'bassSound';
  static const _drumSoundKey = 'drumSound';
  static const _chordColoursKey = 'chordColours';
  static const _colourChordsKey = 'colourChords';
  static const _splitEnharmonicsKey = 'splitEnharmonics';
  static const _paperKey = 'paper';
  static const _arpeggioSoundKey = 'arpeggioSound';
  static const _arpeggioStartKey = 'arpeggioStart';
  static const _metronomeTempoKey = 'metronomeTempo';
  static const _metronomeBeatsKey = 'metronomeBeats';
  static const _metronomeClickKey = 'metronomeClick';
  static const _metronomeClickOnKey = 'metronomeClickOn';
  static const _metronomeDropoutKey = 'metronomeDropout';
  static const _chordAidKey = 'chordAid';
  static const _fadeChartKey = 'fadeChart';

  /// Reads saved settings. Falls back to defaults if storage is unavailable.
  static Future<AppSettings> load() async {
    final storage = SharedPreferencesAsync();
    var instrument = ChartInstrument.concert;
    var mixWithOthers = true;
    var takesWithBand = true;
    var diagram = ChordDiagram.none;
    DrillTarget? aimFor;
    var comping = Comping.piano;
    var bassSound = BassSound.upright;
    var drumSound = DrumSound.kit;
    var chordColours = const ChordColours();
    var colourChords = true;
    var splitEnharmonics = false;
    Color? paper;
    var arpeggioSound = Comping.piano;
    var arpeggioStart = ArpeggioStart.root;
    var metronomeTempo = 120;
    var metronomeBeats = 4;
    var metronomeSubdivision = Subdivision.quarters;
    var metronomeClickOn = ClickOn.everyBeat;
    var metronomeDropout = Dropout.none;
    var chordAid = ChordAid.off;
    var fadeChart = FadeChart.never;
    try {
      final savedAid = await storage.getString(_chordAidKey);
      chordAid = ChordAid.values.firstWhere(
        (value) => value.name == savedAid,
        orElse: () => ChordAid.off,
      );
      metronomeTempo = await storage.getInt(_metronomeTempoKey) ?? 120;
      metronomeBeats = await storage.getInt(_metronomeBeatsKey) ?? 4;
      final savedClick = await storage.getString(_metronomeClickKey);
      metronomeSubdivision = Subdivision.values.firstWhere(
        (value) => value.name == savedClick,
        orElse: () => Subdivision.quarters,
      );
      final savedClickOn = await storage.getString(_metronomeClickOnKey);
      metronomeClickOn = ClickOn.values.firstWhere(
        (value) => value.name == savedClickOn,
        orElse: () => ClickOn.everyBeat,
      );
      final savedDropout = await storage.getString(_metronomeDropoutKey);
      metronomeDropout = Dropout.values.firstWhere(
        (value) => value.name == savedDropout,
        orElse: () => Dropout.none,
      );
      final savedFade = await storage.getString(_fadeChartKey);
      fadeChart = FadeChart.values.firstWhere(
        (value) => value.name == savedFade,
        orElse: () => FadeChart.never,
      );
      final savedStart = await storage.getString(_arpeggioStartKey);
      arpeggioStart = ArpeggioStart.values.firstWhere(
        (value) => value.name == savedStart,
        orElse: () => ArpeggioStart.root,
      );
      final savedArpeggio = await storage.getString(_arpeggioSoundKey);
      arpeggioSound = Comping.values.firstWhere(
        (value) => value.name == savedArpeggio,
        orElse: () => Comping.piano,
      );
      final savedComping = await storage.getString(_compingKey);
      comping = Comping.values.firstWhere(
        (value) => value.name == savedComping,
        orElse: () => Comping.piano,
      );
      final savedBass = await storage.getString(_bassSoundKey);
      bassSound = BassSound.values.firstWhere(
        (value) => value.name == savedBass,
        orElse: () => BassSound.upright,
      );
      final savedColours = await storage.getString(_chordColoursKey);
      if (savedColours != null) {
        chordColours = ChordColours.fromJson(
          jsonDecode(savedColours) as Map<String, Object?>,
        );
      }
      colourChords = await storage.getBool(_colourChordsKey) ?? true;
      splitEnharmonics = await storage.getBool(_splitEnharmonicsKey) ?? false;
      final savedPaper = await storage.getInt(_paperKey);
      if (savedPaper != null) paper = Color(savedPaper);
      final savedDrums = await storage.getString(_drumSoundKey);
      drumSound = DrumSound.values.firstWhere(
        (value) => value.name == savedDrums,
        orElse: () => DrumSound.kit,
      );
      mixWithOthers = await storage.getBool(_mixKey) ?? true;
      takesWithBand = await storage.getBool(_takesBandKey) ?? true;
      final saved = await storage.getString(_instrumentKey);
      instrument = ChartInstrument.values.firstWhere(
        (value) => value.name == saved,
        orElse: () => ChartInstrument.concert,
      );
      final savedDiagram = await storage.getString(_diagramKey);
      diagram = ChordDiagram.values.firstWhere(
        (value) => value.name == savedDiagram,
        orElse: () => ChordDiagram.none,
      );
      final savedAim = await storage.getString(_aimKey);
      aimFor = DrillTarget.values
          .where((value) => value.name == savedAim)
          .firstOrNull;
    } catch (e) {
      debugPrint('Could not read settings: $e');
    }
    return AppSettings._(
      storage,
      instrument,
      mixWithOthers,
      diagram,
      aimFor,
      comping,
      bassSound,
      drumSound,
      chordColours,
      colourChords,
      splitEnharmonics,
      paper,
      arpeggioSound,
      arpeggioStart,
      metronomeTempo,
      metronomeBeats,
      metronomeSubdivision,
      metronomeClickOn,
      metronomeDropout,
      fadeChart,
      takesWithBand,
      chordAid,
    );
  }

  final SharedPreferencesAsync? _storage;

  ChartInstrument get instrument => _instrument;
  ChartInstrument _instrument;

  /// Whether other apps (Spotify, forScore …) keep playing alongside ours.
  bool get mixWithOthers => _mixWithOthers;
  bool _mixWithOthers;

  /// Whether playing a take back puts the band around it, or plays only
  /// what the microphone heard.
  bool get takesWithBand => _takesWithBand;
  bool _takesWithBand;

  Future<void> setTakesWithBand(bool value) async {
    if (value == _takesWithBand) return;
    _takesWithBand = value;
    notifyListeners();
    try {
      await _storage?.setBool(_takesBandKey, value);
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  Future<void> setMixWithOthers(bool value) async {
    if (value == _mixWithOthers) return;
    _mixWithOthers = value;
    notifyListeners();
    try {
      await _storage?.setBool(_mixKey, value);
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  /// Which fingering diagram sits beside the chord being played.
  ChordDiagram get diagram => _diagram;
  ChordDiagram _diagram;

  Future<void> setDiagram(ChordDiagram value) async {
    if (value == _diagram) return;
    _diagram = value;
    notifyListeners();
    try {
      await _storage?.setString(_diagramKey, value.name);
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  /// Which chord tone to show as the one to aim for while playing along, or
  /// null for none.
  DrillTarget? get aimFor => _aimFor;
  DrillTarget? _aimFor;

  Future<void> setAimFor(DrillTarget? value) async {
    if (value == _aimFor) return;
    _aimFor = value;
    notifyListeners();
    try {
      if (value == null) {
        await _storage?.remove(_aimKey);
      } else {
        await _storage?.setString(_aimKey, value.name);
      }
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  /// Who plays the chords in the band: piano or guitar.
  Comping get comping => _comping;
  Comping _comping;

  Future<void> setComping(Comping value) async {
    if (value == _comping) return;
    _comping = value;
    notifyListeners();
    try {
      await _storage?.setString(_compingKey, value.name);
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  /// Who plays the bass: the band's upright, or a SoundFont somebody
  /// imported for it.
  BassSound get bassSound => _bassSound;
  BassSound _bassSound;

  Future<void> setBassSound(BassSound value) async {
    if (value == _bassSound) return;
    _bassSound = value;
    notifyListeners();
    try {
      await _storage?.setString(_bassSoundKey, value.name);
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  /// Who plays the drums: the band's kit, or an imported one.
  DrumSound get drumSound => _drumSound;
  DrumSound _drumSound;

  Future<void> setDrumSound(DrumSound value) async {
    if (value == _drumSound) return;
    _drumSound = value;
    notifyListeners();
    try {
      await _storage?.setString(_drumSoundKey, value.name);
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  /// What colour each root looks like, for somebody who sees them in
  /// colour. Empty unless they have said.
  ChordColours get chordColours => _chordColours;
  ChordColours _chordColours;

  /// Whether to use them. Separate from whether there are any, so the
  /// chart can be turned plain for a moment without losing a mapping that
  /// took a while to put in.
  bool get colourChords => _colourChords;
  bool _colourChords;

  /// Whether C♯ and D♭ are two questions or one.
  ///
  /// Off by default, because twelve is what most people have and asking
  /// seventeen questions to find out is a poor trade. On, the five black
  /// keys split in two and each written note can have its own.
  bool get splitEnharmonics => _splitEnharmonics;
  bool _splitEnharmonics;

  /// The colour for [pitchClass] as it should be drawn, or null when
  /// there is not one or they are turned off.
  ///
  /// For the places that hear a pitch rather than read a note, where
  /// there is no spelling to go on: the tuner hears 277 Hz, and whether
  /// that is a C♯ or a D♭ is not a question sound can answer. Where a
  /// note is written down, [chordColourForNote] is the one to use.
  Color? chordColourFor(int pitchClass) => _colourChords
      ? _chordColours.ofPitch(pitchClass, split: _splitEnharmonics)
      : null;

  /// The colour for a written note.
  Color? chordColourForNote(Spelling note) => _colourChords
      ? _chordColours.ofSpelling(note, split: _splitEnharmonics)
      : null;

  Future<void> setChordColour(int pitchClass, Color? colour) async {
    _chordColours = _chordColours.set(pitchClass, colour);
    notifyListeners();
    await _saveChordColours();
  }

  Future<void> setChordColourForNote(Spelling note, Color? colour) async {
    _chordColours = _chordColours.setSpelling(note, colour);
    notifyListeners();
    await _saveChordColours();
  }

  Future<void> setSplitEnharmonics(bool value) async {
    if (value == _splitEnharmonics) return;
    _splitEnharmonics = value;
    notifyListeners();
    try {
      await _storage?.setBool(_splitEnharmonicsKey, value);
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  Future<void> clearChordColours() async {
    _chordColours = const ChordColours();
    notifyListeners();
    await _saveChordColours();
  }

  Future<void> setColourChords(bool value) async {
    if (value == _colourChords) return;
    _colourChords = value;
    notifyListeners();
    try {
      await _storage?.setBool(_colourChordsKey, value);
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  Future<void> _saveChordColours() async {
    try {
      await _storage?.setString(
        _chordColoursKey,
        jsonEncode(_chordColours.toJson()),
      );
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  /// The paper the app is printed on, or null to follow the system's
  /// light and dark the way it always has.
  Color? get paper => _paper;
  Color? _paper;

  Future<void> setPaper(Color? value) async {
    if (value == _paper) return;
    _paper = value;
    notifyListeners();
    try {
      if (value == null) {
        await _storage?.remove(_paperKey);
      } else {
        await _storage?.setInt(_paperKey, value.toARGB32());
      }
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  /// How the metronome was left: its tempo, time signature and click.
  int get metronomeTempo => _metronomeTempo;
  int _metronomeTempo;
  int get metronomeBeats => _metronomeBeats;
  int _metronomeBeats;
  Subdivision get metronomeSubdivision => _metronomeSubdivision;
  Subdivision _metronomeSubdivision;

  /// Which beats of the bar it clicks on, and how much of it goes away.
  ClickOn get metronomeClickOn => _metronomeClickOn;
  ClickOn _metronomeClickOn;
  Dropout get metronomeDropout => _metronomeDropout;
  Dropout _metronomeDropout;

  Future<void> setMetronome({
    required int tempo,
    required int beats,
    required Subdivision subdivision,
    ClickOn clickOn = ClickOn.everyBeat,
    Dropout dropout = Dropout.none,
  }) async {
    if (tempo == _metronomeTempo &&
        beats == _metronomeBeats &&
        subdivision == _metronomeSubdivision &&
        clickOn == _metronomeClickOn &&
        dropout == _metronomeDropout) {
      return;
    }
    _metronomeTempo = tempo;
    _metronomeBeats = beats;
    _metronomeSubdivision = subdivision;
    _metronomeClickOn = clickOn;
    _metronomeDropout = dropout;
    notifyListeners();
    try {
      await _storage?.setInt(_metronomeTempoKey, tempo);
      await _storage?.setInt(_metronomeBeatsKey, beats);
      await _storage?.setString(_metronomeClickKey, subdivision.name);
      await _storage?.setString(_metronomeClickOnKey, clickOn.name);
      await _storage?.setString(_metronomeDropoutKey, dropout.name);
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  /// When the chart goes away while the band keeps playing.
  FadeChart get fadeChart => _fadeChart;
  FadeChart _fadeChart;

  Future<void> setFadeChart(FadeChart value) async {
    if (value == _fadeChart) return;
    _fadeChart = value;
    notifyListeners();
    try {
      await _storage?.setString(_fadeChartKey, value.name);
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  /// Which chord tone the arpeggios start from.
  ArpeggioStart get arpeggioStart => _arpeggioStart;
  ArpeggioStart _arpeggioStart;

  Future<void> setArpeggioStart(ArpeggioStart value) async {
    if (value == _arpeggioStart) return;
    _arpeggioStart = value;
    notifyListeners();
    try {
      await _storage?.setString(_arpeggioStartKey, value.name);
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  /// What the arpeggios are played on: piano or guitar.
  Comping get arpeggioSound => _arpeggioSound;
  Comping _arpeggioSound;

  Future<void> setArpeggioSound(Comping value) async {
    if (value == _arpeggioSound) return;
    _arpeggioSound = value;
    notifyListeners();
    try {
      await _storage?.setString(_arpeggioSoundKey, value.name);
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  /// What's written under each chord on the chart, to learn by.
  ChordAid get chordAid => _chordAid;
  ChordAid _chordAid;

  Future<void> setChordAid(ChordAid value) async {
    if (value == _chordAid) return;
    _chordAid = value;
    notifyListeners();
    try {
      await _storage?.setString(_chordAidKey, value.name);
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  Future<void> setInstrument(ChartInstrument value) async {
    if (value == _instrument) return;
    _instrument = value;
    notifyListeners();
    try {
      await _storage?.setString(_instrumentKey, value.name);
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }
}
