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
// last twenty seconds it kept, in the ear's format (see
// room_listener.dart), so a tracker's barlines can be checked against
// where somebody listening put them.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
       _clock = clock ?? _stopwatch;

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
    // Far more than twenty seconds' worth.
    if (_taps.length > 2000) _taps.removeAt(0);
  }

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

  /// Puts up the system's sheet for starting or stopping the broadcast.
  Future<bool> pick() async {
    try {
      return await channel.invokeMethod<bool>('pick') ?? false;
    } catch (e) {
      debugPrint('Could not start the broadcast: $e');
      return false;
    }
  }

  /// The last twenty seconds it heard, as a WAV, if any were kept.
  Future<Uint8List?> kept() async {
    try {
      return await channel.invokeMethod<Uint8List>('kept');
    } catch (e) {
      debugPrint('Could not read what the broadcast kept: $e');
      return null;
    }
  }

  /// The last twenty seconds kept, and a log of the taps made in them,
  /// headed by [header]. The log is also left beside the sound, so both
  /// can be copied off the phone. Null if nothing was kept.
  Future<({Uint8List wav, String log})?> keep({required String header}) async {
    final wav = await kept();
    if (wav == null) return null;
    String? text;
    try {
      text = await channel.invokeMethod<String>('keptPlaced');
    } catch (e) {
      debugPrint('Could not read when the broadcast was kept: $e');
    }
    final placed = text == null
        ? const <String, dynamic>{}
        : jsonDecode(text) as Map<String, dynamic>;
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
        '# broadcast: end placed by $placedBy, arrival minus timestamp $held',
      )
      ..writeln('# seconds  event');
    if (end != null && seconds != null) {
      final start = end - seconds;
      for (final tap in _taps) {
        if (tap.at < start || tap.at > end) continue;
        final at = (tap.at - start).toStringAsFixed(3);
        log.writeln(
          tap.bar == null
              ? '$at  TAP THE BEAT'
              : '$at  TAPPED BAR ${tap.bar! + 1}',
        );
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
    super.dispose();
  }
}
