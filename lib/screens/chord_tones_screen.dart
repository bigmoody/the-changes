// Chord-tone drills: see a chord, tap its notes, as fast as you can.
//
// Answers are tapped on a 12-note pad and marked the moment enough notes are
// in, so the drill rewards instant recall rather than working it out. The
// right answer is always shown spelled properly, with each note's degree,
// and can be heard against the chord.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/drill_sounds.dart';
import '../audio/practice_player.dart';
import '../music/chord_drill.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'chart_instrument_button.dart';
import 'chord_diagram.dart';
import 'stave.dart';

class ChordTonesScreen extends StatefulWidget {
  const ChordTonesScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<ChordTonesScreen> createState() => _ChordTonesScreenState();
}

class _ChordTonesScreenState extends State<ChordTonesScreen> {
  var _mode = DrillMode.spell;
  var _source = DrillSource.twoFiveOne;
  var _level = DrillLevel.sevenths;
  var _target = DrillTarget.third;

  late ChordDrill _drill;
  late DrillQuestion _question;
  final _tapped = <int>{};
  bool? _wasRight;
  final _clock = Stopwatch();

  var _asked = 0;
  var _right = 0;
  var _streak = 0;
  var _best = 0;
  final _times = <int>[];

  @override
  void initState() {
    super.initState();
    _restart();
  }

  /// A fresh drill with the current settings, and a new score.
  void _restart() {
    if (_mode == DrillMode.aim &&
        _source == DrillSource.anyChord &&
        !_level.offers(_target)) {
      _target = DrillTarget.values.firstWhere(_level.offers);
    }
    _drill = ChordDrill(
      mode: _mode,
      source: _source,
      level: _level,
      target: _target,
    );
    _asked = _right = _streak = 0;
    _times.clear();
    _nextQuestion();
  }

  void _nextQuestion() {
    _question = _drill.next();
    _tapped.clear();
    _wasRight = null;
    _clock
      ..reset()
      ..start();
  }

  void _tap(int pitchClass) {
    if (_wasRight != null) return;
    setState(() {
      if (!_tapped.remove(pitchClass)) _tapped.add(pitchClass);
      // Marked as soon as enough notes are in: no Check button to slow you.
      if (_tapped.length == _question.answer.length) _mark();
    });
  }

  void _mark() {
    _clock.stop();
    final right = _question.isRight(_tapped);
    _wasRight = right;
    _asked++;
    if (right) {
      _right++;
      _streak++;
      _best = _streak > _best ? _streak : _best;
      _times.add(_clock.elapsedMilliseconds);
    } else {
      _streak = 0;
    }
  }

  Future<void> _hear() async {
    final bank = widget.player.samples;
    if (bank == null) return;
    final wav = renderSnippet(
      bank,
      drillSnippet(
        _question,
        concertShift: -widget.settings.instrument.semitones,
        withAnswer: _wasRight != null,
      ),
    );
    await widget.player.playSnippet(wav);
  }

  void _change(VoidCallback update) => setState(() {
    update();
    _restart();
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Chord Quiz'),
          actions: [ChartInstrumentButton(settings: widget.settings)],
        ),
        // Next sits at the bottom, under your thumb, so a drill never needs
        // a scroll between questions.
        bottomNavigationBar: _wasRight == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: FilledButton(
                    onPressed: () => setState(_nextQuestion),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Next', style: TextStyle(fontSize: 17)),
                    ),
                  ),
                ),
              ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _settings(context),
              const SizedBox(height: 12),
              _Score(
                right: _right,
                asked: _asked,
                streak: _streak,
                best: _best,
                times: _times,
              ),
              const SizedBox(height: 12),
              _questionCard(context),
              const SizedBox(height: 16),
              _NotePad(
                question: _question,
                tapped: _tapped,
                marked: _wasRight != null,
                onTap: _tap,
              ),
              if (_wasRight != null) ...[
                const SizedBox(height: 16),
                _answer(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _settings(BuildContext context) {
    final targets = [
      for (final target in DrillTarget.values)
        if (_source != DrillSource.anyChord || _level.offers(target)) target,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<DrillMode>(
          showSelectedIcon: false,
          segments: [
            for (final mode in DrillMode.values)
              ButtonSegment(value: mode, label: Text(mode.label)),
          ],
          selected: {_mode},
          onSelectionChanged: (value) => _change(() => _mode = value.first),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _Picker<DrillSource>(
              label: 'Chords',
              value: _source,
              options: DrillSource.values,
              name: (source) => source.label,
              onChanged: (value) => _change(() => _source = value),
            ),
            if (_source == DrillSource.anyChord)
              _Picker<DrillLevel>(
                label: 'Level',
                value: _level,
                options: DrillLevel.values,
                name: (level) => level.label,
                onChanged: (value) => _change(() => _level = value),
              ),
            if (_mode == DrillMode.aim)
              _Picker<DrillTarget>(
                label: 'Aim For',
                value: _target,
                options: targets,
                name: (target) => target.label,
                onChanged: (value) => _change(() => _target = value),
              ),
            _Picker<ChordDiagram>(
              label: 'Fingering',
              value: widget.settings.diagram,
              options: ChordDiagram.values,
              name: (diagram) => diagram.label,
              onChanged: widget.settings.setDiagram,
            ),
          ],
        ),
      ],
    );
  }

  Widget _questionCard(BuildContext context) {
    final theme = Theme.of(context);
    final question = _question;
    final prompt = question.mode == DrillMode.spell
        ? 'Tap its ${question.answer.length} notes'
        : _target == DrillTarget.guideTones
        ? 'Its 3rd and 7th?'
        : _target == DrillTarget.root
        ? 'Its root?'
        : 'Its ${_target.label}?';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          children: [
            if (question.progression.isNotEmpty)
              _Progression(question: question),
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      question.chord.display,
                      key: const ValueKey('drill-chord'),
                      style: handLettered(theme.textTheme.displayMedium),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.volume_up),
                  tooltip: _wasRight == null
                      ? 'Hear the chord'
                      : 'Hear the answer against the chord',
                  onPressed: widget.player.samples == null ? null : _hear,
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(prompt, style: theme.textTheme.titleMedium),
            ),
          ],
        ),
      ),
    );
  }

  Widget _answer(BuildContext context) {
    final theme = Theme.of(context);
    final right = _wasRight!;
    final question = _question;
    final time = (_clock.elapsedMilliseconds / 1000).toStringAsFixed(1);
    final diagram = widget.settings.diagram;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              right ? Icons.check_circle : Icons.cancel,
              color: right
                  ? successColour(theme.colorScheme)
                  : theme.colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text(
              right ? 'Right — $time s' : 'Not quite',
              style: theme.textTheme.titleMedium,
            ),
            // Now and then — not every time, or it'd be noise — a word
            // from the bandstand.
            if (right && streakRemark(_streak) != null)
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      streakRemark(_streak)!,
                      key: const ValueKey('streak-remark'),
                      style: handLettered(theme.textTheme.titleLarge)
                          .copyWith(color: theme.colorScheme.tertiary),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final note in question.solution)
              Chip(
                label: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: note.note,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: '  ${note.degree == '1' ? 'root' : note.degree}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  style: theme.textTheme.titleMedium,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // The chord as it's written, the note to aim for in pencil; and
        // where it sits under the fingers, if that's shown.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 24,
          runSpacing: 12,
          children: [
            Stave(
              key: const ValueKey('quiz-stave'),
              notes: chordOnStave(
                question.chord,
                clef: diagram == ChordDiagram.bass ? Clef.bass : Clef.treble,
                extra: question.degrees,
                marked: question.mode == DrillMode.aim
                    ? question.degrees.toSet()
                    : const {},
              ),
              clef: diagram == ChordDiagram.bass ? Clef.bass : Clef.treble,
              chord: true,
              space: 9,
              semanticsLabel:
                  '${question.chord.display} on the stave: '
                  '${question.chord.noteNames.join(', ')}',
            ),
            if (diagram != ChordDiagram.none)
              FingeringDiagram(
                chord: question.chord,
                diagram: diagram,
                height: diagram == ChordDiagram.keyboard ? 70 : 130,
              ),
          ],
        ),
      ],
    );
  }
}

/// A ii–V–I with the chord being asked about picked out.
class _Progression extends StatelessWidget {
  const _Progression({required this.question});

  final DrillQuestion question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Text(
              'in ${question.keyName}:  ',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            for (var i = 0; i < question.progression.length; i++) ...[
              if (i > 0)
                Text(' → ', style: TextStyle(color: theme.colorScheme.outline)),
              Text(
                question.progression[i].display,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: i == question.position
                      ? FontWeight.w800
                      : FontWeight.w400,
                  color: i == question.position
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Right answers so far, the current streak, and how fast.
class _Score extends StatelessWidget {
  const _Score({
    required this.right,
    required this.asked,
    required this.streak,
    required this.best,
    required this.times,
  });

  final int right;
  final int asked;
  final int streak;
  final int best;
  final List<int> times;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final average = times.isEmpty
        ? '–'
        : '${(times.reduce((a, b) => a + b) / times.length / 1000).toStringAsFixed(1)} s';
    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.titleLarge),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    return Row(
      children: [
        stat('$right/$asked', 'right'),
        stat('$streak', best > streak ? 'streak (best $best)' : 'streak'),
        stat(average, 'average'),
      ],
    );
  }
}

/// The twelve notes, in order, to tap answers on. Each black key shows both
/// its names; the answer shows which spelling the chord uses.
class _NotePad extends StatelessWidget {
  const _NotePad({
    required this.question,
    required this.tapped,
    required this.marked,
    required this.onTap,
  });

  final DrillQuestion question;
  final Set<int> tapped;
  final bool marked;
  final ValueChanged<int> onTap;

  static const _names = [
    'C',
    'C♯\nD♭',
    'D',
    'D♯\nE♭',
    'E',
    'F',
    'F♯\nG♭',
    'G',
    'G♯\nA♭',
    'A',
    'A♯\nB♭',
    'B',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final answer = question.answer;
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 4;
        const gap = 8.0;
        final size = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var pitch = 0; pitch < 12; pitch++)
              SizedBox(
                key: ValueKey('pad-$pitch'),
                width: size,
                height: size * 0.62,
                child: _key(scheme, pitch, answer),
              ),
          ],
        );
      },
    );
  }

  Widget _key(ColorScheme scheme, int pitch, Set<int> answer) {
    final isTapped = tapped.contains(pitch);
    final isAnswer = answer.contains(pitch);
    // After marking: right taps green, wrong ones red, missed ones outlined.
    final Color background;
    final Color foreground;
    BorderSide side = BorderSide.none;
    if (!marked) {
      background = isTapped ? scheme.primary : scheme.surfaceContainerHigh;
      foreground = isTapped ? scheme.onPrimary : scheme.onSurface;
    } else if (isTapped && isAnswer) {
      background = successColour(scheme);
      foreground = Colors.white;
    } else if (isTapped) {
      background = scheme.error;
      foreground = scheme.onError;
    } else {
      background = scheme.surfaceContainerHigh;
      foreground = scheme.onSurface;
      if (isAnswer) side = BorderSide(color: successColour(scheme), width: 3);
    }
    return Semantics(
      button: true,
      selected: isTapped,
      label: _names[pitch].replaceAll('\n', ' or '),
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: side,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: marked ? null : () => onTap(pitch),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  _names[pitch],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A chip that opens a menu of choices: "Chords: ii–V–I ▾".
class _Picker<T> extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.value,
    required this.options,
    required this.name,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T) name;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        for (final option in options)
          MenuItemButton(
            leadingIcon: Icon(option == value ? Icons.check : null, size: 18),
            onPressed: () => onChanged(option),
            child: Text(name(option)),
          ),
      ],
      builder: (context, menu, _) => ActionChip(
        label: Text('$label: ${name(value)}'),
        avatar: const Icon(Icons.arrow_drop_down),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

/// What the band says at a streak of [streak] right answers in a row: only
/// at milestones, so it means something when it comes.
@visibleForTesting
String? streakRemark(int streak) => switch (streak) {
  5 => 'Five in a row',
  10 => 'Swingin\'',
  15 => 'In the pocket',
  20 => 'Burnin\'!',
  30 => 'Take another chorus',
  50 => 'Ready for the gig',
  _ when streak > 50 && streak % 25 == 0 => '$streak straight. Wow.',
  _ => null,
};
