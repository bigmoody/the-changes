// A metronome, for practising away from the band: a tempo, a time
// signature, and the beat divided as you like it.
//
// It can also take itself away, which is the part worth having. Clicking
// only on 2 and 4 removes the downbeat you were leaning on; dropping whole
// bars removes the click altogether and hands the time back to you. Both
// are old exercises and neither needs anything the app hasn't got.
//
// The clicks play on a loop, always a whole number of samples long, so the
// time never drifts, which is what makes a silent bar worth anything: the
// click comes back in exactly the right place, and you find out. The dots
// follow the same clock as the sound: a stopwatch started with it. They go
// dark through a silent bar too, or you would simply read the beat off the
// screen instead of keeping it.

import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import '../audio/felt_beat.dart';

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
  late ClickOn _clickOn = widget.settings.metronomeClickOn;
  late Dropout _dropout = widget.settings.metronomeDropout;
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

  /// Which beat of the bar is sounding, from the clock, or -1 when nothing
  /// is: the click stopped, or this is one of the bars it sits out. Through
  /// a silent bar the dots show nothing, because a dot is as good as a
  /// click if you are allowed to watch it.
  int get _beat {
    if (!_clock.isRunning) return -1;
    final beats = _clock.elapsedMicroseconds / (60000000 / _tempo);
    if (!_dropout.sounds(beats ~/ _beatsPerBar)) return -1;
    return beats.floor() % _beatsPerBar;
  }

  Future<void> _start() async {
    await widget.player.playLoop(
      metronomeLoop(
        tempo: _tempo,
        beatsPerBar: _beatsPerBar,
        subdivision: _subdivision,
        clickOn: _clickOn,
        dropout: _dropout,
      ),
    );
    _clock
      ..reset()
      ..start();
    _ticker?.cancel();
    // Often enough that the dot lands with the click.
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final beat = _beat;
      // A bar the click is sitting out is -1, so the tap sits that bar
      // out with it. Dropping the click to test your own time and then
      // being handed the beat through your hand would be no test at all.
      if (beat >= 0 && beat != _beatNow.value) {
        feelBeat(
          widget.settings.feelTheBeat,
          beat: beat,
          beatsPerBar: _beatsPerBar,
        );
      }
      _beatNow.value = beat;
    });
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
  /// from the top of the bar with the new setting, once the changes stop
  /// coming, so dragging the tempo doesn't stutter.
  void _change(VoidCallback change) {
    setState(() {
      change();
      // There is no 4 in a bar of three: moving to odd time puts the click
      // back on every beat rather than somewhere it doesn't mean anything.
      if (!_clickOn.suits(_beatsPerBar)) _clickOn = ClickOn.everyBeat;
    });
    _restart?.cancel();
    _restart = Timer(const Duration(milliseconds: 180), () {
      unawaited(
        widget.settings.setMetronome(
          tempo: _tempo,
          beats: _beatsPerBar,
          subdivision: _subdivision,
          clickOn: _clickOn,
          dropout: _dropout,
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
        // The settings scroll; Start and Tap don't. There are enough
        // settings now that they would otherwise be below the fold on a
        // small phone, and Start is the one thing you always want.
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                              clicks: _clickOn.sounds(i),
                              colour: i == 0
                                  ? scheme.tertiary
                                  : scheme.onSurface,
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
                    child: Text(
                      'beats a minute',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton.outlined(
                        key: const ValueKey('metronome-slower'),
                        icon: const Icon(Icons.remove),
                        tooltip: 'Slower',
                        onPressed: _tempo > 40
                            ? () => _change(() => _tempo--)
                            : null,
                      ),
                      Expanded(
                        child: Slider(
                          value: _tempo.toDouble(),
                          min: 40,
                          max: 320,
                          onChanged: (value) =>
                              _change(() => _tempo = value.round()),
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
                          onSelected: (_) =>
                              _change(() => _beatsPerBar = beats),
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
                  const SizedBox(height: 16),
                  Text('Which Beats', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      // Both are always shown. The backbeat is greyed out
                      // in odd time rather than taken away: that it exists
                      // and doesn't apply here is worth knowing, and a
                      // section that comes and goes just looks broken.
                      for (final clickOn in ClickOn.values)
                        ChoiceChip(
                          key: ValueKey('metronome-${clickOn.name}'),
                          label: Text(clickOn.label),
                          selected: _clickOn == clickOn,
                          onSelected: clickOn.suits(_beatsPerBar)
                              ? (_) => _change(() => _clickOn = clickOn)
                              : null,
                        ),
                    ],
                  ),
                  if (_clickOn == ClickOn.backbeat)
                    _Note(
                      'Nothing on 1 and 3, so the downbeat is yours to carry. It '
                      'is how a drummer hears the bar, and the quickest way to '
                      'find out whether your time is your own.',
                    ),
                  const SizedBox(height: 16),
                  Text('Dropout', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final dropout in Dropout.values)
                        ChoiceChip(
                          key: ValueKey('metronome-${dropout.name}'),
                          label: Text(dropout.label),
                          selected: _dropout == dropout,
                          onSelected: (_) => _change(() => _dropout = dropout),
                        ),
                    ],
                  ),
                  if (_dropout != Dropout.none)
                    _Note(
                      'The click goes away and comes back exactly where it would '
                      'have been. If it lands where you expected, your time held '
                      'through the gap. The dots sit out too: reading them would '
                      'be the same as listening.',
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
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
            ),
          ],
        ),
      ),
    );
  }
}

/// What an exercise is for, under the chips that turn it on.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One beat of the bar.
class _Dot extends StatelessWidget {
  const _Dot({
    required this.on,
    required this.first,
    required this.colour,
    this.clicks = true,
  });

  final bool on;
  final bool first;

  /// Whether this beat is clicked at all. A beat the click sits out is
  /// drawn faintly: it is still part of the bar, and you still have to
  /// count it; it just doesn't make a sound.
  final bool clicks;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final size = first ? 18.0 : 14.0;
    final ink = clicks ? colour : colour.withValues(alpha: 0.3);
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
            color: on && clicks ? ink : Colors.transparent,
            border: Border.all(color: ink, width: 1.5),
          ),
        ),
      ),
    );
  }
}
