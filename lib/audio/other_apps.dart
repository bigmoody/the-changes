// Hearing what another app is playing, in builds being worked on only.
//
// Nothing follows it yet. This is the proof that it can be heard at all:
// iOS lets one app hear another's sound only through a broadcast that
// the person starts, with the red recording indicator on, and the
// extension that receives it (ios/BroadcastExtension) writes what
// arrives where the app can read it. Read here a few times a second: the
// format, how loud, how steady.
//
// Protected sound, Apple Music's among it, is silenced in a broadcast,
// the same as in a screen recording.
//
// Taps made along with it are kept too, on the phone's clock, which the
// extension's timestamps are on. Saved, they become a log beside the
// last minute it kept, in the ear's format (see
// room_listener.dart), so a tracker's barlines can be checked against
// where somebody listening put them.
//
// And it can be followed: Beat This! runs in the app on what the
// broadcast hears, once a second (see BeatTracker.swift), and each new
// barline it hears is handed on, as how long ago it was, for the count to
// be nudged by (see tap_follower.dart).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../music/tune.dart';

/// The channel the native side answers on.
const otherAppsChannel = MethodChannel('the_changes/broadcast');

/// What the extension last wrote.
class OtherAppsReport {
  const OtherAppsReport({
    required this.state,
    required this.updated,
    required this.format,
    required this.sampleRate,
    required this.channels,
    required this.framesPerBuffer,
    required this.buffers,
    required this.silentBuffers,
    required this.frames,
    required this.seconds,
    required this.level,
    required this.peak,
    required this.longestGap,
    required this.jumps,
  });

  factory OtherAppsReport.fromJson(Map<String, dynamic> json) {
    double number(String key) => (json[key] as num?)?.toDouble() ?? 0;
    int whole(String key) => (json[key] as num?)?.toInt() ?? 0;
    return OtherAppsReport(
      state: json['state'] as String? ?? '',
      updated: DateTime.fromMillisecondsSinceEpoch(
        (number('updated') * 1000).round(),
      ),
      format: json['format'] as String? ?? '',
      sampleRate: number('sampleRate'),
      channels: whole('channels'),
      framesPerBuffer: whole('framesPerBuffer'),
      buffers: whole('buffers'),
      silentBuffers: whole('silentBuffers'),
      frames: whole('frames'),
      seconds: number('seconds'),
      level: number('level'),
      peak: number('peak'),
      longestGap: number('longestGap'),
      jumps: whole('jumps'),
    );
  }

  /// Started, paused or finished: the broadcast's, not the sound's.
  final String state;

  /// When it was written, which says whether anything is still arriving.
  final DateTime updated;

  /// The format in words, as the extension found it.
  final String format;
  final double sampleRate;
  final int channels;
  final int framesPerBuffer;

  final int buffers;

  /// Buffers with nothing in them at all, which is what protected sound
  /// arrives as.
  final int silentBuffers;
  final int frames;

  /// From the first buffer to the last, by the phone's clock.
  final double seconds;

  /// The last buffer's loudness, root mean square, from 0 to 1.
  final double level;
  final double peak;

  /// The longest wait between two buffers, in seconds.
  final double longestGap;

  /// Buffers that did not start where the one before ended, by the
  /// buffers' own clock.
  final int jumps;

  /// Frames a second, by the phone's clock: the sample rate, if the
  /// sound is keeping up.
  double? get arrivingRate => seconds > 1 ? frames / seconds : null;
}

/// The extension's numbers, read while something wants them.
class OtherAppsSound extends ChangeNotifier {
  OtherAppsSound({
    this.channel = otherAppsChannel,
    DateTime Function()? now,
    Duration Function()? clock,
  }) : _now = now ?? DateTime.now,
       _clock = clock ?? _stopwatch {
    channel.setMethodCallHandler(_fromThePhone);
  }

  /// Taken rather than reached for, so a test can answer as the phone.
  final MethodChannel channel;
  final DateTime Function() _now;

  /// What time it is here, for timing taps; a test's own clock in a test.
  final Duration Function() _clock;
  static final _watch = Stopwatch()..start();
  static Duration _stopwatch() => _watch.elapsed;

  /// The phone's clock less this one's, in seconds, once asked.
  double? _offset;

  /// Taps, on the phone's clock: null for a beat, or the bar tapped.
  final _taps = <({double at, int? bar})>[];

  Timer? _reading;
  OtherAppsReport? _report;

  OtherAppsReport? get report => _report;

  /// Whether the last numbers are recent: the extension writes ten times
  /// a second while sound arrives, so a second without any is a stop.
  bool get arriving {
    final report = _report;
    return report != null &&
        report.state == 'started' &&
        _now().difference(report.updated) < const Duration(seconds: 1);
  }

  bool get reading => _reading != null;

  void startReading() {
    _reading ??= Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => read(),
    );
    read();
    if (_offset == null) _setClock();
  }

  /// Finds the phone's clock from here. Asked a few times and the
  /// quickest answer kept: the one that waited least on the way.
  Future<void> _setClock() async {
    double? best;
    double? bestTrip;
    for (var i = 0; i < 5; i++) {
      try {
        final before = _clock().inMicroseconds / 1e6;
        final phone = await channel.invokeMethod<double>('now');
        final after = _clock().inMicroseconds / 1e6;
        if (phone == null) return;
        final trip = after - before;
        if (bestTrip == null || trip < bestTrip) {
          bestTrip = trip;
          best = phone - (before + after) / 2;
        }
      } catch (e) {
        debugPrint('Could not read the phone\'s clock: $e');
        return;
      }
    }
    _offset = best;
  }

  /// A tap along with the other app: null for a beat, or the bar.
  void tapped(int? bar) {
    final offset = _offset;
    if (offset == null) return;
    _taps.add((at: _clock().inMicroseconds / 1e6 + offset, bar: bar));
    // Far more than twenty minutes' worth.
    if (_taps.length > 5000) _taps.removeAt(0);
  }

  /// What the count and the ear did, said in a line for the log: what
  /// was on the screen, beside what was heard.
  void noted(String event) {
    final offset = _offset;
    if (offset == null) return;
    _notes.add((at: _clock().inMicroseconds / 1e6 + offset, event: event));
    if (_notes.length > 5000) _notes.removeAt(0);
  }

  final _notes = <({double at, String event})>[];

  void stopReading() {
    _reading?.cancel();
    _reading = null;
  }

  Future<void> read() async {
    try {
      final text = await channel.invokeMethod<String>('read');
      if (text == null) return;
      _report = OtherAppsReport.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Could not read what the broadcast heard: $e');
    }
  }

  /// Told of each new barline Beat This! hears, as how long ago it was.
  void Function(Duration ago)? onBarline;

  /// Told of every look's beats, each as how long ago it was.
  void Function(List<Duration> beats)? onBeats;

  /// Told of what the chords say every few seconds (ChordFollower.swift):
  /// a bar that started [ago], which bar of the chart it was, and the
  /// tempo.
  void Function(Duration ago, int bar, double tempo)? onChords;

  /// The tune's chords, half a bar at a time, for following by them.
  Tune? tune;

  /// [tune]'s chart as the phone wants it: each half bar's notes and bass.
  static List<Map<String, Object>> chartOf(Tune tune) {
    final perBar = tune.beatsPerBar;
    return [
      for (var half = 0; half < tune.barCount * 2; half++)
        () {
          final chord = tune
              .slotAtBeat((half ~/ 2) * perBar + (half % 2) * (perBar ~/ 2))
              .chord;
          return {'pcs': chord.pitchClasses, 'bass': chord.bass};
        }(),
    ];
  }

  /// Told of each new bar heard whole: how long ago its middle was, and
  /// what sounded in it (see form_finder.dart).
  void Function(Duration ago, List<double> pitches)? onBar;

  /// The start of the last bar handed on, by the phone's clock.
  double? _lastBar;

  /// Each bar handed on, for the log: when it started and what sounded.
  final _barsHeard = <({double heard, double start, List<double> pitches})>[];

  /// Whether Beat This! has been asked to follow.
  bool get following => _following;
  var _following = false;

  /// Why it cannot follow, or what it is waiting for, in words.
  String? get problem => _problem;
  String? _problem;
  String? get waiting => _waiting;
  String? _waiting;

  /// How many barlines it has heard since it was asked to follow.
  int get barlinesHeard => _barlinesHeard;
  var _barlinesHeard = 0;

  /// How long its last look took, in seconds.
  double? get took => _took;
  double? _took;

  /// Barlines are handed on once two looks agree on them.
  var _confirm = BarlineFilter();

  /// Each barline handed on and when it was, by the phone's clock, kept
  /// for the log beside what the broadcast kept: with the taps, enough to
  /// play the count through again on a computer.
  final _barlines = <({double heard, double at})>[];

  /// Starts Beat This! on what the broadcast hears.
  /// Whether it follows the room through the microphone rather than a
  /// broadcast: the same Beat This!, the same count, the sound from the
  /// phone's own microphone (see MicRecorder.swift).
  bool get microphone => _microphone;
  var _microphone = false;

  /// Follows through the microphone, or the broadcast, from now on.
  Future<void> useMicrophone(bool on) async {
    if (on == _microphone) return;
    final wasFollowing = _following;
    if (wasFollowing) await stopFollowing();
    _microphone = on;
    _waiting = null;
    _problem = null;
    if (wasFollowing) await follow();
    notifyListeners();
  }

  Future<void> follow() async {
    _following = true;
    _barlinesHeard = 0;
    _confirm = BarlineFilter();
    _lastBar = null;
    try {
      final tune = this.tune;
      _problem = await channel.invokeMethod<String>('follow', {
        'source': _microphone ? 'microphone' : 'broadcast',
        if (tune != null) 'chart': chartOf(tune),
        if (tune != null) 'beatsPerBar': tune.beatsPerBar,
      });
    } catch (e) {
      _problem = 'Beat This! could not start: $e';
    }
    if (_offset == null) await _setClock();
    notifyListeners();
  }

  Future<void> stopFollowing() async {
    _following = false;
    try {
      await channel.invokeMethod<void>('stopFollowing');
    } catch (e) {
      debugPrint('Could not stop Beat This!: $e');
    }
    if (!_disposed) notifyListeners();
  }

  Future<dynamic> _fromThePhone(MethodCall call) async {
    if (call.method != 'heard') return null;
    final heard = Map<String, dynamic>.from(call.arguments as Map);
    _problem = heard['problem'] as String?;
    _waiting = heard['waiting'] as String?;
    _took = (heard['took'] as num?)?.toDouble() ?? _took;
    final downbeats = [
      for (final d in heard['downbeats'] as List? ?? const [])
        (d as num).toDouble(),
    ]..sort();
    final offset = _offset;
    if (offset != null && _following) {
      final now = _clock().inMicroseconds / 1e6 + offset;
      if (heard['chords'] case final Map chords) {
        onChords?.call(
          Duration(
            microseconds: ((now - (chords['barStart'] as num).toDouble()) * 1e6)
                .round(),
          ),
          (chords['bar'] as num).toInt(),
          (chords['tempo'] as num).toDouble(),
        );
      }
      onBeats?.call([
        for (final b in heard['beats'] as List? ?? const [])
          Duration(microseconds: ((now - (b as num).toDouble()) * 1e6).round()),
      ]);
      for (final d in _confirm.take(downbeats)) {
        _barlinesHeard++;
        _barlines.add((heard: now, at: d));
        if (_barlines.length > 10000) _barlines.removeAt(0);
        onBarline?.call(Duration(microseconds: ((now - d) * 1e6).round()));
      }
      final bars = [
        for (final b in heard['bars'] as List? ?? const [])
          Map<String, dynamic>.from(b as Map),
      ];
      for (var i = 0; i < bars.length; i++) {
        final start = (bars[i]['start'] as num).toDouble();
        final last = _lastBar;
        if (last != null && start <= last + 0.2) continue;
        // Its end is where the next bar starts, or the last barline heard.
        final end = i + 1 < bars.length
            ? (bars[i + 1]['start'] as num).toDouble()
            : downbeats.isEmpty
            ? null
            : downbeats.last;
        if (end == null || end <= start) continue;
        final pitches = [
          for (final p in bars[i]['pitches'] as List) (p as num).toDouble(),
        ];
        _lastBar = start;
        _barsHeard.add((heard: now, start: start, pitches: pitches));
        if (_barsHeard.length > 5000) _barsHeard.removeAt(0);
        final middle = (start + end) / 2;
        onBar?.call(
          Duration(microseconds: ((now - middle) * 1e6).round()),
          pitches,
        );
      }
    }
    notifyListeners();
    return null;
  }

  /// Puts up the system's sheet for starting or stopping the broadcast.
  Future<bool> pick() async {
    try {
      return await channel.invokeMethod<bool>('pick') ?? false;
    } catch (e) {
      debugPrint('Could not start the broadcast: $e');
      return false;
    }
  }

  /// The last minute it heard, as a WAV, if any were kept.
  Future<Uint8List?> kept() async {
    try {
      return await channel.invokeMethod<Uint8List>('kept');
    } catch (e) {
      debugPrint('Could not read what the broadcast kept: $e');
      return null;
    }
  }

  /// The last minute kept, and a log of the taps made in them,
  /// headed by [header]. The log is also left beside the sound, so both
  /// can be copied off the phone. Null if nothing was kept.
  Future<({Uint8List wav, String log})?> keep({required String header}) async {
    Uint8List? wav;
    var placed = const <String, dynamic>{};
    // Everything heard since it started following, by broadcast or
    // microphone, when it has followed; otherwise the last minute.
    try {
      final kept = await channel.invokeMethod<Map>('keptListening');
      wav = kept?['wav'] as Uint8List?;
      placed = Map<String, dynamic>.from(kept?['placed'] as Map? ?? const {});
    } catch (e) {
      debugPrint('Could not read what was heard while following: $e');
    }
    if (wav != null) {
      // Kept by the app as it was heard.
    } else if (_microphone) {
      // The microphone's minute, kept by the app itself.
      try {
        final kept = await channel.invokeMethod<Map>('keptMicrophone');
        wav = kept?['wav'] as Uint8List?;
        placed = Map<String, dynamic>.from(kept?['placed'] as Map? ?? const {});
      } catch (e) {
        debugPrint('Could not read what the microphone kept: $e');
      }
    } else {
      wav = await kept();
      String? text;
      try {
        text = await channel.invokeMethod<String>('keptPlaced');
      } catch (e) {
        debugPrint('Could not read when the broadcast was kept: $e');
      }
      if (text != null) placed = jsonDecode(text) as Map<String, dynamic>;
    }
    if (wav == null) return null;
    final seconds = (placed['seconds'] as num?)?.toDouble();
    final byTimestamp = (placed['endByTimestamp'] as num?)?.toDouble();
    final byArrival = (placed['endByArrival'] as num?)?.toDouble();
    // The buffers' own timestamps say when the sound was played, so they
    // are taken when they look like the phone's clock: within a second of
    // when the last buffer arrived.
    final useTimestamp =
        byTimestamp != null &&
        (byArrival == null || (byArrival - byTimestamp).abs() < 1);
    final end = useTimestamp ? byTimestamp : byArrival;
    final placedBy = end == null
        ? 'nothing, so no taps'
        : useTimestamp
        ? 'timestamp'
        : 'arrival';
    final held = byTimestamp != null && byArrival != null
        ? '${(byArrival - byTimestamp).toStringAsFixed(3)} s'
        : 'unknown';
    final log = StringBuffer()
      ..writeln(header)
      ..writeln(
        '# ${_microphone ? 'microphone' : 'broadcast'}: end placed by '
        '$placedBy, arrival minus timestamp $held',
      )
      ..writeln('# seconds  event');
    if (end != null && seconds != null) {
      final start = end - seconds;
      final lines = <(double, String)>[
        for (final tap in _taps)
          if (tap.at >= start && tap.at <= end)
            (
              tap.at,
              tap.bar == null ? 'TAP THE BEAT' : 'TAPPED BAR ${tap.bar! + 1}',
            ),
        for (final note in _notes)
          if (note.at >= start && note.at <= end) (note.at, note.event),
        // When Beat This! heard it, then when it was.
        for (final b in _barlines)
          if (b.heard >= start && b.heard <= end)
            (b.heard, 'HEARD BARLINE ${(b.at - start).toStringAsFixed(3)}'),
        // When it was heard, then when it started and what sounded.
        for (final b in _barsHeard)
          if (b.heard >= start && b.heard <= end)
            (
              b.heard,
              'HEARD BAR ${(b.start - start).toStringAsFixed(3)} '
                  '${b.pitches.map((p) => p.toStringAsFixed(4)).join(' ')}',
            ),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      for (final (at, event) in lines) {
        log.writeln('${(at - start).toStringAsFixed(3)}  $event');
      }
    }
    try {
      await channel.invokeMethod<bool>('keepTaps', log.toString());
    } catch (e) {
      debugPrint('Could not leave the taps beside the broadcast: $e');
    }
    return (wav: wav, log: log.toString());
  }

  @override
  void dispose() {
    stopReading();
    _disposed = true;
    // Never left running with nothing to hear it.
    if (_following) unawaited(stopFollowing());
    super.dispose();
  }

  var _disposed = false;
}

/// Barlines Beat This! has said twice.
///
/// It looks at the last twenty seconds once a second, so each barline is
/// in about twenty looks, and what it says of a barline near the newest
/// edge of a look, with little after it to go on, is its least sure: on a
/// Miles Davis record about one barline in ten was a beat early, a half
/// bar, or two a quarter of a second apart, and, handed on the first time
/// it was heard, each one dragged the count. A barline is handed on here
/// only when two looks in a row put it in the same place, within [within]
/// seconds, which costs a second.
class BarlineFilter {
  BarlineFilter({this.within = 0.04});

  final double within;

  var _previous = const <double>[];
  double? _last;

  /// The barlines in this look, sorted, that the one before agreed on and
  /// that have not been handed on already.
  List<double> take(List<double> downbeats) {
    final out = <double>[];
    for (final d in downbeats) {
      double? agreed;
      for (final p in _previous) {
        if ((p - d).abs() <= within) agreed = (p + d) / 2;
      }
      if (agreed == null) continue;
      final last = _last;
      // The same barline again, a frame or two either way.
      if (last != null && agreed <= last + 0.2) continue;
      _last = agreed;
      out.add(agreed);
    }
    _previous = downbeats;
    return out;
  }
}
