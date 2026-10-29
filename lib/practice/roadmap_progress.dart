// Where somebody is on the roadmap: which instrument, which stage, the
// goals they have ticked, how long they practise, and what of today's
// routine is done. Kept on the device.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'roadmap.dart';

class RoadmapProgress extends ChangeNotifier {
  RoadmapProgress._(this._storage);

  /// Progress that isn't saved anywhere, for tests.
  RoadmapProgress.inMemory({RoadmapInstrument? instrument})
    : _storage = null,
      // A private field can't be a named parameter.
      // ignore: prefer_initializing_formals
      _instrument = instrument;

  static const _key = 'roadmap';

  static Future<RoadmapProgress> load() async {
    final storage = SharedPreferencesAsync();
    final progress = RoadmapProgress._(storage);
    try {
      final saved = await storage.getString(_key);
      if (saved != null) {
        progress._read(jsonDecode(saved) as Map<String, Object?>);
      }
    } catch (e) {
      debugPrint('Could not read the roadmap: $e');
    }
    return progress;
  }

  final SharedPreferencesAsync? _storage;

  /// Null until somebody says what they play.
  RoadmapInstrument? get instrument => _instrument;
  RoadmapInstrument? _instrument;

  final _stage = <RoadmapInstrument, int>{};
  final _ticked = <String>{};
  int _minutes = 30;
  int? _doneDay;
  final _done = <String>{};
  final _tempos = <String, int>{};
  final _sessionTunes = <String>[];

  /// The tunes somebody's own jam session calls, by their titles in the
  /// library, in the order they were added.
  List<String> get sessionTunes => List.unmodifiable(_sessionTunes);

  void addSessionTune(String title) {
    if (_sessionTunes.contains(title)) return;
    _sessionTunes.add(title);
    _changed();
  }

  void removeSessionTune(String title) {
    if (!_sessionTunes.remove(title)) return;
    _changed();
  }

  /// The tempo [scale] was last played at, or [start] the first time. A
  /// scale is pushed a little faster week by week, so the next session
  /// starts where the last one got to rather than at the bottom again.
  int scaleTempo(String scale, int start) => _tempos[scale] ?? start;

  void setScaleTempo(String scale, int tempo) {
    if (_tempos[scale] == tempo) return;
    _tempos[scale] = tempo;
    _changed();
  }

  /// The stage being worked on with [instrument], from 1.
  int stageOf(RoadmapInstrument instrument) => _stage[instrument] ?? 1;

  int get minutes => _minutes;

  /// Whether [goal] is ticked for [instrument]. The ticks are kept for
  /// each instrument apart: a guitarist who takes up the sax has not
  /// learned the sax by ticking the guitar's goals.
  bool isTicked(RoadmapInstrument instrument, Goal goal) =>
      _ticked.contains('${instrument.name}:${goal.id}');

  /// Whether every goal on [stage] is ticked.
  bool stageDone(RoadmapInstrument instrument, Stage stage) =>
      stage.goals.every((goal) => isTicked(instrument, goal));

  /// Whether block [index] of today's routine has been done, on [day].
  bool isDone(int day, int index, String title) =>
      _doneDay == day && _done.contains('$index:$title');

  void setInstrument(RoadmapInstrument value) {
    if (value == _instrument) return;
    _instrument = value;
    _changed();
  }

  void setStage(RoadmapInstrument instrument, int stage) {
    if (stage == stageOf(instrument)) return;
    _stage[instrument] = stage.clamp(1, 6);
    _changed();
  }

  void setMinutes(int value) {
    if (value == _minutes) return;
    _minutes = value;
    _changed();
  }

  void tick(RoadmapInstrument instrument, Goal goal, bool on) {
    final id = '${instrument.name}:${goal.id}';
    if (on ? !_ticked.add(id) : !_ticked.remove(id)) return;
    _changed();
  }

  void markDone(int day, int index, String title, bool done) {
    if (_doneDay != day) {
      _doneDay = day;
      _done.clear();
    }
    final id = '$index:$title';
    if (done ? !_done.add(id) : !_done.remove(id)) return;
    _changed();
  }

  void _changed() {
    notifyListeners();
    unawaited(_save());
  }

  Future<void> _save() async {
    try {
      await _storage?.setString(_key, jsonEncode(_toJson()));
    } catch (e) {
      debugPrint('Could not save the roadmap: $e');
    }
  }

  Map<String, Object?> _toJson() => {
    'instrument': _instrument?.name,
    'stages': {for (final e in _stage.entries) e.key.name: e.value},
    'ticked': _ticked.toList(),
    'minutes': _minutes,
    'doneDay': _doneDay,
    'done': _done.toList(),
    'tempos': _tempos,
    'sessionTunes': _sessionTunes,
  };

  void _read(Map<String, Object?> json) {
    _instrument = RoadmapInstrument.values
        .where((i) => i.name == json['instrument'])
        .firstOrNull;
    final stages = json['stages'];
    if (stages is Map) {
      for (final instrument in RoadmapInstrument.values) {
        final stage = stages[instrument.name];
        if (stage is num) _stage[instrument] = stage.toInt().clamp(1, 6);
      }
    }
    _ticked.addAll((json['ticked'] as List?)?.whereType<String>() ?? []);
    final minutes = json['minutes'];
    if (minutes is num && sessionLengths.contains(minutes)) {
      _minutes = minutes.toInt();
    }
    _doneDay = (json['doneDay'] as num?)?.toInt();
    _done.addAll((json['done'] as List?)?.whereType<String>() ?? []);
    _sessionTunes.addAll(
      (json['sessionTunes'] as List?)?.whereType<String>() ?? const [],
    );
    if (json['tempos'] case final Map<String, Object?> tempos) {
      for (final MapEntry(:key, :value) in tempos.entries) {
        if (value is num) _tempos[key] = value.toInt();
      }
    }
  }
}
