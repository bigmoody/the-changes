// Takes: recordings of you playing over the band.
//
// Only your playing is recorded. The band isn't mixed in and isn't saved;
// it's written again from scratch when you play the take back, from the
// tempo, key, loop and seed kept here. Given those, the band plays exactly
// what it played the first time, note for note, so the two line up without
// anything having to be recorded twice. It also means a take is a few
// seconds of one instrument rather than a whole band, and that the chart
// can follow along as usual.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../music/arrangement.dart';
import '../settings/progression_store.dart'
    show TextStorage, MemoryStorage, preferencesStorage;

/// One recording, and everything needed to put the band back around it.
class Take {
  const Take({
    required this.id,
    required this.at,
    required this.file,
    required this.tune,
    required this.seconds,
    required this.leadIn,
    required this.tempo,
    required this.semitones,
    required this.loopStart,
    required this.loopBeats,
    required this.seed,
    required this.arrangement,
  });

  factory Take.fromJson(Map<String, dynamic> json) => Take(
    id: json['id'] as String,
    at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
    file: json['file'] as String,
    tune: json['tune'] as String,
    seconds: (json['seconds'] as num).toDouble(),
    leadIn: (json['leadIn'] as num? ?? 0).toDouble(),
    tempo: json['tempo'] as int,
    semitones: json['semitones'] as int? ?? 0,
    loopStart: json['loopStart'] as int,
    loopBeats: json['loopBeats'] as int,
    seed: json['seed'] as int,
    arrangement: arrangementFromJson(
      json['arrangement'] as Map<String, dynamic>?,
    ),
  );

  final String id;
  final DateTime at;

  /// The file's name, not its path: where the app may keep its files moves
  /// between one launch and the next on iOS.
  final String file;

  /// The tune it was played over, as it was titled at the time.
  final String tune;
  final double seconds;

  /// How much of the front of the recording is the wait while the band was
  /// written, to be wound past when it's played back.
  final double leadIn;
  final int tempo;

  /// How far the tune had been moved from its written key.
  final int semitones;
  final int loopStart;
  final int loopBeats;

  /// What made the band play it that way; the same seed plays it again.
  final int seed;
  final Arrangement arrangement;

  /// How long you actually played for.
  Duration get length =>
      Duration(milliseconds: ((seconds - leadIn) * 1000).round());

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.millisecondsSinceEpoch,
    'file': file,
    'tune': tune,
    'seconds': seconds,
    'leadIn': leadIn,
    'tempo': tempo,
    'semitones': semitones,
    'loopStart': loopStart,
    'loopBeats': loopBeats,
    'seed': seed,
    'arrangement': arrangementToJson(arrangement),
  };
}

Map<String, dynamic> arrangementToJson(Arrangement a) => {
  if (a.choruses != null) 'choruses': a.choruses,
  if (a.headInAndOut) 'head': true,
  if (a.twoFeelOnHead) 'twoFeel': true,
  if (a.trading != Trading.off) 'trading': a.trading.name,
  if (a.layOut.isNotEmpty) 'layOut': [for (final p in a.layOut) p.name],
  if (a.ramp.isOn) 'rampStep': a.ramp.step,
  if (a.ramp.isOn && a.ramp.climb != null) 'rampClimb': a.ramp.climb,
};

Arrangement arrangementFromJson(Map<String, dynamic>? json) {
  if (json == null) return Arrangement.keepGoing;
  final step = json['rampStep'] as int? ?? 0;
  return Arrangement(
    choruses: json['choruses'] as int?,
    headInAndOut: json['head'] as bool? ?? false,
    twoFeelOnHead: json['twoFeel'] as bool? ?? false,
    trading: Trading.values.firstWhere(
      (t) => t.name == json['trading'],
      orElse: () => Trading.off,
    ),
    layOut: {
      for (final name in (json['layOut'] as List? ?? []))
        ...LayOut.values.where((p) => p.name == name),
    },
    ramp: TempoRamp(step: step, climb: json['rampClimb'] as int?),
  );
}

/// Somewhere to keep the recordings themselves.
abstract interface class TakeFiles {
  /// Where a new recording should be written, and what to call it.
  Future<({String path, String name})> place(String id);

  /// The full path of a saved recording, or null if it has gone.
  Future<String?> pathOf(String name);

  Future<void> remove(String name);
}

/// Keeps nothing anywhere, for tests.
class NoFiles implements TakeFiles {
  final removed = <String>[];

  @override
  Future<({String path, String name})> place(String id) async =>
      (path: '/takes/$id.wav', name: '$id.wav');

  @override
  Future<String?> pathOf(String name) async => '/takes/$name';

  @override
  Future<void> remove(String name) async => removed.add(name);
}

class TakeStore extends ChangeNotifier {
  TakeStore._(this._storage, this.files, this._takes);

  /// Nothing saved anywhere, for tests.
  TakeStore.inMemory([List<Take>? takes])
    : _storage = MemoryStorage(),
      files = NoFiles(),
      _takes = [...?takes];

  static Future<TakeStore> load({
    TextStorage? storage,
    required TakeFiles files,
  }) async {
    final store = storage ?? preferencesStorage('takes');
    var takes = <Take>[];
    try {
      final text = await store.read();
      if (text != null) {
        takes = [
          for (final json in jsonDecode(text) as List)
            Take.fromJson(json as Map<String, dynamic>),
        ];
      }
    } catch (e) {
      debugPrint('Could not read the saved takes: $e');
    }
    return TakeStore._(store, files, takes);
  }

  final TextStorage _storage;
  final TakeFiles files;
  final List<Take> _takes;

  /// Everything recorded, newest first.
  List<Take> get all => [..._takes]..sort((a, b) => b.at.compareTo(a.at));

  /// The takes for one tune, newest first.
  List<Take> forTune(String tune) =>
      all.where((take) => take.tune == tune).toList();

  String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_made++}';
  var _made = 0;

  Future<void> add(Take take) async {
    _takes.add(take);
    notifyListeners();
    await _write();
  }

  Future<void> delete(String id) async {
    final gone = _takes.where((take) => take.id == id).toList();
    _takes.removeWhere((take) => take.id == id);
    notifyListeners();
    for (final take in gone) {
      try {
        await files.remove(take.file);
      } catch (e) {
        debugPrint('Could not delete a take: $e');
      }
    }
    await _write();
  }

  Future<void> _write() async {
    try {
      await _storage.write(jsonEncode([for (final t in _takes) t.toJson()]));
    } catch (e) {
      debugPrint('Could not save the takes: $e');
    }
  }
}
