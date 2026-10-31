// Licks in context, from the Practice tab and from Learn.
//
// A lick written over its changes in today's key, and the band playing
// those changes round. By default it is call and response: the band plays
// the lick, then the changes go round again and it is yours, then the band
// again. That is how the vocabulary was always learned, off records and
// on the stand, and it is the only way a lick turns into something you
// can say rather than something you can recite.

import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/drum_patterns.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/swing.dart';
import '../practice/licks.dart';
import '../practice/roadmap.dart';
import '../practice/roadmap_progress.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'key_menu.dart';
import 'stave.dart';
import 'swing_screen.dart' show ridePattern;

/// Who plays the lick on each time round.
enum LickTurns {
  callAndResponse('Band, Then You'),
  together('Together'),
  changesOnly('Just the Changes');

  const LickTurns(this.label);

  final String label;
}

class LickScreen extends StatefulWidget {
  const LickScreen({
    super.key,
    required this.licks,
    required this.keyName,
    required this.instrument,
    required this.progress,
    required this.player,
    required this.settings,
    this.title = 'Licks in Context',
    this.onDone,
    this.level = PlayerLevel.intermediate,
  });

  /// Who is playing, which sets the tempo the licks start at.
  final PlayerLevel level;

  final List<Lick> licks;

  /// The key the licks are played in, as the player reads it.
  final String keyName;
  final RoadmapInstrument instrument;
  final RoadmapProgress progress;
  final PracticePlayer player;
  final AppSettings settings;
  final String title;

  /// Called when the last lick is done, to tick its block off. Null where
  /// the screen was opened to browse, from Learn.
  final VoidCallback? onDone;

  @override
  State<LickScreen> createState() => _LickScreenState();
}

class _LickScreenState extends State<LickScreen> {
  var _at = 0;
  var _times = 4;
  var _turns = LickTurns.callAndResponse;
  late var _key = widget.keyName;
  late var _tempo = widget.progress.scaleTempo(
    _tempoKey,
    widget.level.tempo(100),
  );

  /// Which note of the lick is sounding (or would be, on your turn).
  int? _playing;

  /// Which bar of the changes is sounding, or null before the band is in.
  int? _bar;

  /// Whether this time round is the band's or yours.
  bool _bandsTurn = true;
  Timer? _clock;

  Lick get _lick => widget.licks[_at];
  String get _tempoKey => 'Lick ${_lick.name}';

  bool get _bass => widget.instrument == RoadmapInstrument.bass;

  /// Where the lick is written: around middle C, and down an octave in the
  /// bass clef for the bass.
  int get _floor => _bass ? 46 : 58;

  static const _countIn = 4;

  @override
  void dispose() {
    _clock?.cancel();
    unawaited(widget.player.stopSnippet());
    super.dispose();
  }

  bool _lickOn(int pass) => switch (_turns) {
    LickTurns.callAndResponse => pass.isEven,
    LickTurns.together => true,
    LickTurns.changesOnly => false,
  };

  Future<void> _play() async {
    if (_playing != null) return _stop();
    final bank = widget.player.samples;
    if (bank == null) return;
    final beat = 60 / _tempo;
    final lead = _countIn * beat;
    final octaveDown = _bass || widget.instrument == RoadmapInstrument.guitar
        ? 12
        : 0;
    final band = lickBand(
      _lick,
      _key,
      tempo: _tempo,
      times: _times,
      floor: _floor,
      lickOn: _lickOn,
      from: lead,
      // The band at concert pitch; the lick as the instrument sounds it.
      down: widget.settings.instrument.semitones,
      lickDown: widget.settings.instrument.semitones + octaveDown,
      ride: (bars) =>
          ridePattern(tempo: _tempo, at: swingAt(_tempo), bars: bars),
    );
    final drums = <SnippetDrum>[
      for (var b = 0; b < _countIn; b++)
        (
          at: b * beat,
          drum: Drum.crossStick,
          velocity: b == 0 ? 0.8 : 0.6,
          hard: b == 0,
        ),
      ...band.drums,
    ];
    setState(() {
      _playing = -1;
      _bandsTurn = _lickOn(0);
    });
    await widget.player.playSnippet(
      renderSnippet(bank, band.notes, drums: drums, pianoRelease: 0.08),
    );
    final starts = lickStarts(_lick, _tempo);
    final passSeconds = _lick.beats * beat;
    _clock = Timer.periodic(const Duration(milliseconds: 15), (_) {
      // The snippet's own position, not a clock of the screen's:
      // paused, the lit note holds; stopped, the screen stops.
      final heard = widget.player.snippetPosition();
      if (heard == null) {
        _stop();
        return;
      }
      final seconds = heard.inMicroseconds / 1e6 - lead;
      if (seconds >= passSeconds * _times + beat) {
        _stop();
        return;
      }
      var index = -1;
      var pass = 0;
      int? bar;
      if (seconds >= 0) {
        pass = seconds ~/ passSeconds;
        final within = (seconds % passSeconds) / beat;
        bar = within ~/ 4;
        for (var i = 0; i < starts.length; i++) {
          if (starts[i] <= within) index = i;
        }
      }
      final bands = _lickOn(pass);
      if ((index != _playing || bands != _bandsTurn || bar != _bar) &&
          mounted) {
        setState(() {
          _playing = index;
          _bandsTurn = bands;
          _bar = bar;
        });
      }
    });
  }

  Future<void> _stop() async {
    _clock?.cancel();
    _clock = null;
    if (mounted) {
      setState(() {
        _playing = null;
        _bar = null;
      });
    }
    await widget.player.stopSnippet();
  }

  void _setTempo(int tempo) {
    setState(() => _tempo = tempo.clamp(40, 280));
    widget.progress.setScaleTempo(_tempoKey, _tempo);
  }

  void _goTo(int index) {
    unawaited(_stop());
    setState(() {
      _at = index;
      _tempo = widget.progress.scaleTempo(_tempoKey, widget.level.tempo(100));
    });
  }

  void _next() {
    if (_at == widget.licks.length - 1) {
      unawaited(_stop());
      widget.onDone?.call();
      Navigator.of(context).pop();
      return;
    }
    _goTo(_at + 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lick = _lick;
    final events = lickIn(lick, _key, floor: _floor);
    final changes = changesIn(lick, _key);
    final last = _at == widget.licks.length - 1;
    final clef = _bass ? Clef.bass : Clef.treble;
    final playing = _playing;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          KeyMenu(
            keyName: _key,
            onChanged: (key) {
              unawaited(_stop());
              setState(() => _key = key);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Text(
                    'Lick ${_at + 1} of ${widget.licks.length} · in $_key',
                    key: const ValueKey('lick-step'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    lick.name,
                    key: const ValueKey('lick-name'),
                    style: handLettered(theme.textTheme.headlineMedium),
                  ),
                  const SizedBox(height: 4),
                  Text(lick.about, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  // The changes, a bar at a time, as a chart writes them.
                  // Ruled off like a chart: the lettering has no bar line of
                  // its own, so each bar is a box with a line down its side.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      key: const ValueKey('lick-changes'),
                      children: [
                        for (final (i, bar) in _bars(changes).indexed)
                          // The bar the band is in, lit while it plays.
                          Container(
                            key: ValueKey('lick-bar-$i'),
                            constraints: const BoxConstraints(minWidth: 84),
                            padding: const EdgeInsets.fromLTRB(8, 2, 12, 2),
                            decoration: BoxDecoration(
                              color: i == _bar
                                  ? scheme.primary.withValues(alpha: 0.22)
                                  : null,
                              border: Border(
                                left: BorderSide(color: scheme.onSurface),
                              ),
                            ),
                            child: Text(
                              bar,
                              style: handLettered(theme.textTheme.titleLarge)
                                  .copyWith(
                                    color: i == _bar ? scheme.primary : null,
                                  ),
                            ),
                          ),
                        Container(
                          width: 1,
                          height: 30,
                          color: scheme.onSurface,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Stave(
                      key: const ValueKey('lick-stave'),
                      clef: clef,
                      notes: lineOnStave(
                        [
                          for (final e in events)
                            (pitch: e.pitch, name: e.name),
                        ],
                        clef: clef,
                        marked: {if (playing != null && playing >= 0) playing},
                      ),
                      space: MediaQuery.sizeOf(context).width > 600 ? 12 : 8,
                      semanticsLabel: lick.name,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    events.map((e) => e.name).join(' '),
                    key: const ValueKey('lick-notes'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (playing != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      key: const ValueKey('lick-turn'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _bandsTurn
                            ? scheme.secondaryContainer
                            : scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        playing < 0
                            ? 'Counting in'
                            : _bandsTurn
                            ? (_turns == LickTurns.together
                                  ? 'Together'
                                  : 'Listen: the band plays it')
                            : 'Your turn',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton.outlined(
                        key: const ValueKey('lick-slower'),
                        tooltip: 'Slower',
                        icon: const Icon(Icons.remove),
                        onPressed: () => _setTempo(_tempo - 5),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$_tempo',
                              key: const ValueKey('lick-tempo'),
                              style: theme.textTheme.headlineSmall,
                            ),
                            Text(
                              'BPM, swung eighths',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.outlined(
                        key: const ValueKey('lick-faster'),
                        tooltip: 'Faster',
                        icon: const Icon(Icons.add),
                        onPressed: () => _setTempo(_tempo + 5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SegmentedButton<LickTurns>(
                        key: const ValueKey('lick-turns'),
                        showSelectedIcon: false,
                        segments: [
                          for (final turns in LickTurns.values)
                            ButtonSegment(
                              value: turns,
                              label: Text(turns.label),
                            ),
                        ],
                        selected: {_turns},
                        onSelectionChanged: (value) {
                          unawaited(_stop());
                          setState(() => _turns = value.first);
                        },
                      ),
                      SegmentedButton<int>(
                        key: const ValueKey('lick-times'),
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 2, label: Text('2 Times')),
                          ButtonSegment(value: 4, label: Text('4 Times')),
                          ButtonSegment(value: 8, label: Text('8 Times')),
                        ],
                        selected: {_times},
                        onSelectionChanged: (value) =>
                            setState(() => _times = value.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    switch (_turns) {
                      LickTurns.callAndResponse =>
                        'A bar counted in, then the band plays the lick over '
                            'the changes, and the next time round it is yours. '
                            'Then the band again.',
                      LickTurns.together =>
                        'The band plays the lick with you every time round.',
                      LickTurns.changesOnly =>
                        'Only the changes: the lick is yours every time round. '
                            'Try it starting somewhere else in the bar.',
                    },
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  if (_at > 0) ...[
                    IconButton.outlined(
                      key: const ValueKey('lick-back'),
                      tooltip: 'Previous lick',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _goTo(_at - 1),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('lick-play'),
                      icon: Icon(
                        playing == null ? Icons.play_arrow : Icons.stop,
                      ),
                      label: Text(playing == null ? 'Play' : 'Stop'),
                      onPressed: _play,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('lick-next'),
                      onPressed: last && widget.onDone == null ? null : _next,
                      child: Text(
                        last
                            ? (widget.onDone == null ? 'Last Lick' : 'Done')
                            : 'Next Lick',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The changes a bar at a time ("Dm7", "G7", "CΔ7", "CΔ7"), two short
  /// chords sharing a bar, a long one written again in each of its bars.
  List<String> _bars(List<({Chord chord, double at, int beats})> changes) {
    final bars = <List<String>>[];
    for (final change in changes) {
      final first = change.at ~/ 4;
      final last = (change.at + change.beats - 1) ~/ 4;
      for (var bar = first; bar <= last; bar++) {
        while (bars.length <= bar) {
          bars.add([]);
        }
        bars[bar].add(change.chord.display);
      }
    }
    return [for (final bar in bars) bar.join('  ')];
  }
}
