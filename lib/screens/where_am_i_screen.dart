// Where am I? The exercise, one question at a time.
//
// The band plays a standard from the top with nothing on screen, cuts out
// somewhere, and you say which bar you were in by tapping it on a grid of
// empty boxes. Nothing is shown while it plays, because anything shown is
// something to read, and reading is the thing being taken away.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/practice_player.dart';
import '../music/tune.dart';
import '../music/tune_library.dart';
import '../practice/practice_controller.dart';
import '../practice/where_am_i.dart';
import '../settings/app_settings.dart';
import '../theme.dart';

/// A few standards with forms worth learning to count: a 32-bar AABA, an
/// ABAC, a blues, a long one that never sits still.
const _tunes = [
  'Take the "A" Train',
  'Autumn Leaves',
  'All of Me',
  'Blue Bossa',
  'Now\'s the Time',
  'Cherokee',
];

/// What the exercise is doing.
enum _Stage { ready, playing, asking, answered }

class WhereAmIScreen extends StatefulWidget {
  const WhereAmIScreen({
    super.key,
    required this.player,
    required this.settings,
    this.random,
  });

  final PracticePlayer player;
  final AppSettings settings;

  /// Fixed in tests, so a question can be a known one.
  @visibleForTesting
  final math.Random? random;

  @override
  State<WhereAmIScreen> createState() => _WhereAmIScreenState();
}

class _WhereAmIScreenState extends State<WhereAmIScreen> {
  late final _random = widget.random ?? math.Random();
  late String _title = _tunes.first;
  late Tune _tune = _find(_title);
  PracticeController? _controller;

  var _stage = _Stage.ready;
  StopPoint? _stop;
  int? _answer;
  Tally _tally = (asked: 0, right: 0);

  static Tune _find(String title) =>
      standards.firstWhere((tune) => tune.title == title);

  @override
  void dispose() {
    _controller?.removeListener(_watch);
    _controller?.dispose();
    super.dispose();
  }

  void _pick(String title) {
    if (title == _title) return;
    unawaited(_controller?.stop());
    setState(() {
      _title = title;
      _tune = _find(title);
      _stage = _Stage.ready;
      _stop = null;
      _answer = null;
    });
  }

  Future<void> _ask() async {
    _controller?.removeListener(_watch);
    unawaited(_controller?.stop());
    _controller?.dispose();
    final controller = PracticeController(
      tune: _tune,
      player: widget.player,
      settings: widget.settings,
    )..addListener(_watch);
    _controller = controller;
    setState(() {
      _stop = chooseStop(_tune, _random);
      _answer = null;
      _stage = _Stage.playing;
    });
    await controller.play();
  }

  /// Cuts the band off the moment it reaches the question's stopping point.
  void _watch() {
    final controller = _controller;
    final stop = _stop;
    if (controller == null || stop == null || _stage != _Stage.playing) return;
    // The controller counts choruses from one; the question from nought.
    final chorus = controller.chorus;
    if (!reached(
      stop,
      _tune,
      chorus: chorus == null ? null : chorus - 1,
      beat: controller.currentBeat,
    )) {
      return;
    }
    unawaited(controller.stop());
    setState(() => _stage = _Stage.asking);
  }

  void _answerWith(int bar) {
    final stop = _stop;
    if (stop == null || _stage != _Stage.asking) return;
    final marking = markAnswer(bar, stop.bar, _tune.barCount);
    setState(() {
      _answer = bar;
      _stage = _Stage.answered;
      _tally = (
        asked: _tally.asked + 1,
        right: _tally.right + (marking.isRight ? 1 : 0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stop = _stop;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Where Am I?'),
        actions: [
          if (_tally.asked > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  describeTally(_tally),
                  key: const ValueKey('tally'),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  Text(
                    'Knowing the changes and knowing where you are in them '
                    'are two different things, and only one of them is on '
                    'the chart. The band plays from the top and cuts out. '
                    'Say which bar it stopped in.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text('Tune', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final title in _tunes)
                        ChoiceChip(
                          key: ValueKey('tune-$title'),
                          label: Text(title),
                          selected: _title == title,
                          onSelected: _stage == _Stage.playing
                              ? null
                              : (_) => _pick(title),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  switch (_stage) {
                    _Stage.ready => _Waiting(
                      '${_tune.barCount} bars. It starts at the top, so '
                      'you have somewhere to count from.',
                    ),
                    _Stage.playing => const _Waiting(
                      'Listening. Keep count; it will stop.',
                      key: ValueKey('listening'),
                    ),
                    _Stage.asking || _Stage.answered => _Answering(
                      tune: _tune,
                      stop: stop,
                      answer: _answer,
                      onTap: _answerWith,
                    ),
                  },
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('ask'),
                  onPressed: _stage == _Stage.playing ? null : _ask,
                  child: Text(switch (_stage) {
                    _Stage.ready => 'Start',
                    _Stage.playing => 'Playing…',
                    _Stage.asking => 'Give Up, Ask Again',
                    _Stage.answered => 'Again',
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet line where the grid will be.
class _Waiting extends StatelessWidget {
  const _Waiting(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The question and the grid to answer it on.
class _Answering extends StatelessWidget {
  const _Answering({
    required this.tune,
    required this.stop,
    required this.answer,
    required this.onTap,
  });

  final Tune tune;
  final StopPoint? stop;
  final int? answer;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stop = this.stop;
    final answer = this.answer;
    final marking = stop == null || answer == null
        ? null
        : markAnswer(answer, stop.bar, tune.barCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          marking == null
              ? 'Which bar did it stop in?'
              : '${marking.label}. It was bar ${stop!.bar + 1}'
                    '${stop.chorus > 0 ? ', chorus ${stop.chorus + 1}' : ''}'
                    ': ${tune.slotAtBeat(tune.barStartBeat(stop.bar)).chord.display}.',
          key: const ValueKey('question'),
          style: theme.textTheme.titleMedium,
        ),
        if (marking != null && marking != Marking.spotOn)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${barsOut(answer!, stop!.bar, tune.barCount)} '
              '${barsOut(answer, stop.bar, tune.barCount) == 1 ? 'bar' : 'bars'}'
              ' out.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 12),
        _BarGrid(
          tune: tune,
          answer: answer,
          actual: marking == null ? null : stop!.bar,
          onTap: onTap,
        ),
      ],
    );
  }
}

/// The tune's bars as empty boxes, four to a row.
///
/// Every bar gets its own box, which the chart itself does not do: it
/// folds a section played twice into one set of boxes with a repeat round
/// it. That is right for reading and wrong for answering: the whole
/// question is which time round you were, so bar 9 has to be tappable even
/// when it is written as bar 1 again.
class _BarGrid extends StatelessWidget {
  const _BarGrid({
    required this.tune,
    required this.answer,
    required this.actual,
    required this.onTap,
  });

  final Tune tune;
  final int? answer;
  final int? actual;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = (tune.barCount / 4).ceil();
    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    // The rehearsal letter, where one starts on this row.
                    tune.sections[row * 4] ?? '',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                for (var col = 0; col < 4; col++) ...[
                  if (col > 0) const SizedBox(width: 4),
                  Expanded(
                    child: row * 4 + col >= tune.barCount
                        ? const SizedBox(height: 44)
                        : _Box(
                            bar: row * 4 + col,
                            answer: answer,
                            actual: actual,
                            onTap: onTap,
                            scheme: scheme,
                          ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.bar,
    required this.answer,
    required this.actual,
    required this.onTap,
    required this.scheme,
  });

  final int bar;
  final int? answer;
  final int? actual;
  final ValueChanged<int> onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final isAnswer = answer == bar;
    final isActual = actual == bar;
    // The two have to be told apart at a glance and they sit side by side,
    // so they differ in more than shade: the true bar is filled and ringed
    // in pencil red, what you said is ringed in the error colour.
    final colour = isActual
        ? scheme.tertiaryContainer
        : isAnswer
        ? scheme.errorContainer
        : cardColour(scheme);
    final edge = isActual
        ? scheme.tertiary
        : isAnswer
        ? scheme.error
        : scheme.outlineVariant;
    return SizedBox(
      height: 44,
      child: Material(
        color: colour,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: edge, width: isActual || isAnswer ? 2.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('bar-${bar + 1}'),
          onTap: actual == null ? () => onTap(bar) : null,
          child: Center(
            // Never colour alone: what each box means is said as well as
            // shown, for anyone reading the screen rather than seeing it.
            child: Text(
              '${bar + 1}',
              semanticsLabel: switch ((isActual, isAnswer)) {
                (true, true) => 'Bar ${bar + 1}, right',
                (true, false) => 'Bar ${bar + 1}, where it stopped',
                (false, true) => 'Bar ${bar + 1}, what you said',
                _ => 'Bar ${bar + 1}',
              },
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isActual || isAnswer
                    ? FontWeight.w700
                    : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
