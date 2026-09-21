// Trading fours: the band plays four, you play four, round and round.
//
// The app could already do this from the arrangement sheet, and what it
// could not do is tell you whose four it is while it goes past. On a
// chart that hardly matters because you can see where the bar is; in
// this exercise it is the whole thing, because the point is that you
// come in on time without being asked twice.
//
// So the screen is one enormous word that changes every four bars. Four
// bars at a medium tempo is about six seconds, which is long enough to
// lose if you are thinking about what to play, and the cue is there so
// that losing it is a mistake you notice rather than one you make.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/arrangement.dart';
import '../music/loop_range.dart';
import '../music/tune_library.dart';
import '../settings/app_settings.dart';

/// The blues, because trading is something you do on a form you already
/// know, and twelve bars is short enough that the swaps come round.
const _tune = 'Jazz blues in F';

class TradingScreen extends StatefulWidget {
  const TradingScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<TradingScreen> createState() => _TradingScreenState();
}

class _TradingScreenState extends State<TradingScreen> {
  var _trading = Trading.fours;
  var _with = TradeWith.drums;
  var _playing = false;

  /// Whose four it is now, and which bar of it, read off the clock.
  bool? _mine;
  int? _bar;
  Timer? _ticker;

  static final _form = practiceProgressions.firstWhere(
    (tune) => tune.title == _tune,
    orElse: () => practiceProgressions.first,
  );

  Arrangement get _arrangement =>
      Arrangement(trading: _trading, tradeWith: _with);

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(widget.player.stop());
    super.dispose();
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    _ticker = null;
    if (mounted) {
      setState(() {
        _playing = false;
        _mine = null;
        _bar = null;
      });
    }
    await widget.player.stop();
  }

  Future<void> _start() async {
    if (_playing) {
      await _stop();
      return;
    }
    await _stop();
    setState(() => _playing = true);
    try {
      await widget.player.start(
        BackingRequest(
          tune: _form,
          loop: LoopRange.wholeTune(_form),
          tempo: _form.defaultTempo,
          comping: widget.settings.comping,
          seed: math.Random().nextInt(1 << 31),
          arrangement: _arrangement,
        ),
      );
    } catch (e) {
      debugPrint('Could not start trading: $e');
      await _stop();
      return;
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted || !_playing) return;
      final at = widget.player.position();
      final beat = at?.tuneBeat;
      if (beat == null) return;
      final bar = beat ~/ _form.beatsPerBar;
      final mine = _arrangement.yours(at?.chorus ?? 0, bar);
      if (mine != _mine || bar != _bar) {
        setState(() {
          _mine = mine;
          _bar = bar;
        });
      }
    });
  }

  /// How far into the current four you are, counted from one.
  int? get _count {
    final bar = _bar;
    if (bar == null || _trading == Trading.off) return null;
    return bar % _trading.bars + 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Trading Fours')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const ValueKey('trading-list'),
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      'The oldest way of learning this music: somebody '
                      'plays four bars, you play the next four, round and '
                      'round the form. You cannot stop to think, which is '
                      'the point of it.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  _Whose(mine: _mine, count: _count, playing: _playing),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text('How Many', style: theme.textTheme.titleSmall),
                  ),
                  _Chips(
                    values: [
                      for (final trading in Trading.values)
                        if (trading != Trading.off)
                          (trading.name, trading.label),
                    ],
                    selected: _trading.name,
                    onPick: (name) {
                      unawaited(_stop());
                      setState(
                        () => _trading = Trading.values.firstWhere(
                          (t) => t.name == name,
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text(
                      'Who Answers',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  _Chips(
                    values: [
                      for (final who in TradeWith.values) (who.name, who.label),
                    ],
                    selected: _with.name,
                    onPick: (name) {
                      unawaited(_stop());
                      setState(
                        () => _with = TradeWith.values.firstWhere(
                          (w) => w.name == name,
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Text(
                      _with == TradeWith.drums
                          ? 'What a band does. The drummer answers you, and '
                                'a good one answers what you actually '
                                'played rather than just filling the gap.'
                          : 'The practice version, and harder than it '
                                'sounds. Nobody fills the four, so keeping '
                                'your place in the form for four bars is '
                                'entirely on you.',
                      key: const ValueKey('about-who'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text(
                      'On ${_form.title}, at ${_form.defaultTempo}. The '
                      'band is out on your four either way: what you are '
                      'playing over is the form, not a backing track.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: SizedBox(
                width: double.infinity,
                child: _playing
                    ? FilledButton.icon(
                        key: const ValueKey('play-trading'),
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                        onPressed: _start,
                      )
                    : FilledButton.icon(
                        key: const ValueKey('play-trading'),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Trading'),
                        onPressed: _start,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whose four it is, in letters big enough to read from a music stand.
class _Whose extends StatelessWidget {
  const _Whose({
    required this.mine,
    required this.count,
    required this.playing,
  });

  final bool? mine;
  final int? count;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final waiting = mine == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        key: const ValueKey('whose-four'),
        width: double.infinity,
        height: 132,
        decoration: BoxDecoration(
          color: waiting
              ? scheme.surfaceContainerHighest
              : mine!
              ? scheme.tertiaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              waiting
                  ? (playing ? 'Counting in' : 'Ready')
                  : mine!
                  ? 'Yours'
                  : 'Theirs',
              key: const ValueKey('whose-word'),
              style: theme.textTheme.displaySmall?.copyWith(
                color: waiting
                    ? scheme.onSurfaceVariant
                    : mine!
                    ? scheme.tertiary
                    : scheme.onSurfaceVariant,
              ),
            ),
            if (count != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'bar $count',
                  key: const ValueKey('which-bar'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A row of chips that scrolls sideways.
class _Chips extends StatelessWidget {
  const _Chips({
    required this.values,
    required this.selected,
    required this.onPick,
  });

  final List<(String, String)> values;
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final (value, written) in values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: ValueKey('pick-$value'),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
                label: Text(written),
                selected: value == selected,
                onSelected: (_) => onPick(value),
              ),
            ),
        ],
      ),
    ),
  );
}
