// A metronome, for practising away from the band: a tempo, a time
// signature, and the beat divided as you like it.
//
// The clicks are a bar long and play on a loop, so the bar is always a
// whole number of samples and the time never drifts. The dots follow the
// same clock as the sound: a stopwatch started with it.

import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../settings/app_settings.dart';
import '../theme.dart';

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  late int _tempo = widget.settings.metronomeTempo;
  late int _beatsPerBar = widget.settings.metronomeBeats;
  late Subdivision _subdivision = widget.settings.metronomeSubdivision;
  var _playing = false;

  /// Started with the clicks, so the dots keep step with them.
  final _clock = Stopwatch();
  Timer? _ticker;

  /// The beat sounding now, watched by the dots alone: the rest of the
  /// screen isn't rebuilt sixty times a second for them.
  final _beatNow = ValueNotifier(-1);

  /// Dragging the tempo changes it many times a second; the click is only
  /// made again once the dragging stops, or it would stutter.
  Timer? _restart;

  /// When the tempo was last tapped out, to work one out from the taps.
  final _taps = <DateTime>[];

  @override
  void dispose() {
    _ticker?.cancel();
    _restart?.cancel();
    _beatNow.dispose();
    unawaited(widget.player.stopLoop());
    super.dispose();
  }

  /// Which beat of the bar is sounding, from the clock.
  int get _beat {
    if (!_clock.isRunning) return -1;
    final beats = _clock.elapsedMicroseconds / (60000000 / _tempo);
    return beats.floor() % _beatsPerBar;
  }

  Future<void> _start() async {
    await widget.player.playLoop(
      metronomeBar(
        tempo: _tempo,
        beatsPerBar: _beatsPerBar,
        subdivision: _subdivision,
      ),
    );
    _clock
      ..reset()
      ..start();
    _ticker?.cancel();
    // Often enough that the dot lands with the click.
    _ticker = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _beatNow.value = _beat,
    );
    setState(() => _playing = true);
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    _ticker = null;
    _restart?.cancel();
    _clock.stop();
    _beatNow.value = -1;
    await widget.player.stopLoop();
    if (mounted) setState(() => _playing = false);
  }

  /// Changes something about the click. If it's running, it starts again
  /// from the top of the bar with the new setting — once the changes stop
  /// coming, so dragging the tempo doesn't stutter.
  void _change(VoidCallback change) {
    setState(change);
    _restart?.cancel();
    _restart = Timer(const Duration(milliseconds: 180), () {
      unawaited(
        widget.settings.setMetronome(
          tempo: _tempo,
          beats: _beatsPerBar,
          subdivision: _subdivision,
        ),
      );
      if (_playing) unawaited(_start());
    });
  }

  void _tap() {
    final now = DateTime.now();
    _taps
      ..removeWhere((tap) => now.difference(tap) > const Duration(seconds: 3))
      ..add(now);
    if (_taps.length < 2) {
      setState(() {});
      return;
    }
    final gaps = [
      for (var i = 1; i < _taps.length; i++)
        _taps[i].difference(_taps[i - 1]).inMicroseconds,
    ];
    final average = gaps.reduce((a, b) => a + b) / gaps.length;
    _change(() => _tempo = (60000000 / average).round().clamp(40, 320));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Metronome')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // The beat, as dots: the one sounding filled in, the first of
            // the bar in pencil.
            ValueListenableBuilder(
              valueListenable: _beatNow,
              builder: (context, beat, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _beatsPerBar; i++)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: _Dot(
                        on: i == beat,
                        first: i == 0,
                        colour: i == 0 ? scheme.tertiary : scheme.onSurface,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '$_tempo',
                key: const ValueKey('metronome-tempo'),
                style: handLettered(theme.textTheme.displayLarge)
                    .copyWith(height: 1),
              ),
            ),
            Center(
              child: Text('beats a minute', style: theme.textTheme.bodySmall),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.outlined(
                  key: const ValueKey('metronome-slower'),
                  icon: const Icon(Icons.remove),
                  tooltip: 'Slower',
                  onPressed: _tempo > 40 ? () => _change(() => _tempo--) : null,
                ),
                Expanded(
                  child: Slider(
                    value: _tempo.toDouble(),
                    min: 40,
                    max: 320,
                    onChanged: (value) => _change(() => _tempo = value.round()),
                  ),
                ),
                IconButton.outlined(
                  key: const ValueKey('metronome-faster'),
                  icon: const Icon(Icons.add),
                  tooltip: 'Faster',
                  onPressed: _tempo < 320
                      ? () => _change(() => _tempo++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Time', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final beats in [2, 3, 4, 5, 6, 7])
                  ChoiceChip(
                    key: ValueKey('metronome-beats-$beats'),
                    label: Text('$beats/4'),
                    selected: _beatsPerBar == beats,
                    onSelected: (_) => _change(() => _beatsPerBar = beats),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Click On', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final subdivision in Subdivision.values)
                  ChoiceChip(
                    key: ValueKey('metronome-${subdivision.name}'),
                    label: Text(subdivision.label),
                    selected: _subdivision == subdivision,
                    onSelected: (_) =>
                        _change(() => _subdivision = subdivision),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('metronome-play'),
                    icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
                    label: Text(_playing ? 'Stop' : 'Start'),
                    onPressed: () => _playing ? _stop() : _start(),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  key: const ValueKey('metronome-tap'),
                  onPressed: _tap,
                  child: const Text('Tap'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One beat of the bar.
class _Dot extends StatelessWidget {
  const _Dot({required this.on, required this.first, required this.colour});

  final bool on;
  final bool first;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final size = first ? 18.0 : 14.0;
    return SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? colour : Colors.transparent,
            border: Border.all(color: colour, width: 1.5),
          ),
        ),
      ),
    );
  }
}
