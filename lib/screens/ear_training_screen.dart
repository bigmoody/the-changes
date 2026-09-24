// Naming what you hear.
//
// The app plays, you answer. Everything else in here that listens is
// listening to the player; this is the one place the player is listening
// to the app, and it is the skill that decides whether somebody can play
// over a tune or only through it.
//
// Three things make it teach rather than merely test. It moves key every
// question, so what is learned is the sound of the thing and not the
// pitch of C. The wrong answers come from the same group, so the choice
// is between things that really could be confused. And a wrong answer is
// followed by an explanation and by the chance to hear both, side by
// side, which is where the learning actually happens: being told you
// were wrong teaches nothing at all.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/drill_sounds.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/ear_training.dart';
import '../settings/app_settings.dart';
import '../theme.dart';

class EarTrainingScreen extends StatefulWidget {
  const EarTrainingScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<EarTrainingScreen> createState() => _EarTrainingScreenState();
}

class _EarTrainingScreenState extends State<EarTrainingScreen> {
  var _group = EarGroup.cadence;
  late EarDealer _dealer = EarDealer(group: _group);
  late EarAsk _ask = _dealer.next();

  EarQuestion? _picked;
  var _asked = 0;
  var _right = 0;
  String? _problem;

  bool get _answered => _picked != null;

  Future<void> _play([EarQuestion? which]) async {
    final bank = widget.player.samples;
    if (bank == null) {
      setState(
        () => _problem =
            'The instruments are still loading. Try again in a moment.',
      );
      return;
    }
    setState(() => _problem = null);
    // Whatever is asked for, in the key this question was asked in, so
    // the two can be compared without one of them moving as well.
    final chords = which == null ? _ask.chords : inKey(which, _ask.key);
    await widget.player.playSnippet(
      renderSnippet(bank, progressionSnippet(chords)),
    );
  }

  void _answer(EarQuestion picked) {
    if (_answered) return;
    setState(() {
      _picked = picked;
      _asked++;
      if (_ask.isRight(picked)) _right++;
    });
  }

  void _next() {
    setState(() {
      _ask = _dealer.next();
      _picked = null;
      _problem = null;
    });
    _play();
  }

  void _setGroup(EarGroup group) {
    setState(() {
      _group = group;
      _dealer = EarDealer(group: group);
      _ask = _dealer.next();
      _picked = null;
      _asked = 0;
      _right = 0;
      _problem = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final picked = _picked;
    final rightOne = _ask.answer;
    return Scaffold(
      appBar: AppBar(title: const Text('Name What You Hear')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            SegmentedButton<EarGroup>(
              key: const ValueKey('ear-group'),
              showSelectedIcon: false,
              segments: [
                for (final group in EarGroup.values)
                  ButtonSegment(value: group, label: Text(group.label)),
              ],
              selected: {_group},
              onSelectionChanged: (value) => _setGroup(value.first),
            ),
            const SizedBox(height: 6),
            Text(
              _group.about,
              key: const ValueKey('ear-about'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('ear-play'),
                    icon: const Icon(Icons.volume_up_outlined),
                    label: Text(_answered ? 'Hear It Again' : 'Play It'),
                    onPressed: _play,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _asked == 0 ? '' : '$_right of $_asked',
                  key: const ValueKey('ear-score'),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            if (_problem case final problem?) ...[
              const SizedBox(height: 10),
              Text(
                problem,
                key: const ValueKey('ear-problem'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            for (final choice in _ask.choices)
              _Choice(
                question: choice,
                answered: _answered,
                isAnswer: choice.name == rightOne.name,
                wasPicked: picked != null && choice.name == picked.name,
                // What that answer would have been in the key this one
                // was played in, so the alternatives can be compared
                // against what was actually heard.
                chords: inKey(choice, _ask.key),
                onPick: () => _answer(choice),
                onHear: () => _play(choice),
              ),
            if (_answered) ...[
              const SizedBox(height: 14),
              _Verdict(
                right: _ask.isRight(picked!),
                answer: rightOne,
                picked: picked,
                askedIn: _ask.key,
                onHearBoth: () => _play(picked),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('ear-next'),
                  onPressed: _next,
                  child: const Text('Next One'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One answer to choose, and once chosen, what it was.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.question,
    required this.answered,
    required this.isAnswer,
    required this.wasPicked,
    required this.chords,
    required this.onPick,
    required this.onHear,
  });

  final EarQuestion question;
  final bool answered;
  final bool isAnswer;
  final bool wasPicked;

  /// This answer's chords in the key the question was asked in.
  final List<Chord> chords;

  final VoidCallback onPick;
  final VoidCallback onHear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // A tick and a cross rather than two colours. The app's accent is a
    // red pencil mark and the error colour is red as well, so right and
    // wrong came out looking the same; a mark says which is which
    // whatever the palette does, and reads for anybody who cannot tell
    // the two reds apart in the first place.
    //
    // Nothing is marked until an answer is in, or the right one would
    // stand out before it had been chosen.
    final mark = !answered
        ? null
        : isAnswer
        ? (Icons.check, scheme.tertiary)
        : wasPicked
        ? (Icons.close, scheme.onSurfaceVariant)
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        // Only the right one is tinted, so it is the single coloured
        // thing on the screen once the answer is in.
        color: answered && isAnswer
            ? scheme.tertiary.withValues(alpha: 0.10)
            : null,
        child: ListTile(
          key: ValueKey('ear-choice-${question.name}'),
          leading: !answered
              ? null
              : SizedBox.square(
                  dimension: 24,
                  child: mark == null
                      ? null
                      : Icon(mark.$1, color: mark.$2, size: 22),
                ),
          title: Text(
            question.name,
            style: theme.textTheme.titleMedium?.copyWith(
              color: answered && isAnswer ? scheme.tertiary : null,
            ),
          ),
          subtitle: answered
              ? Text(
                  handSymbol(
                    [for (final chord in chords) chord.display].join('  '),
                  ),
                )
              : null,
          trailing: answered
              ? IconButton(
                  key: ValueKey('ear-hear-${question.name}'),
                  icon: const Icon(Icons.volume_up_outlined),
                  tooltip: 'Hear ${question.name}',
                  onPressed: onHear,
                )
              : null,
          onTap: answered ? null : onPick,
        ),
      ),
    );
  }
}

/// What it was, and why it sounds like that.
///
/// The explanation is the point of the screen. Being told you were wrong
/// and nothing else leaves you exactly where you started, and the next
/// one is then another guess.
class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.right,
    required this.answer,
    required this.picked,
    required this.askedIn,
    required this.onHearBoth,
  });

  final bool right;
  final EarQuestion answer;
  final EarQuestion picked;

  /// The key it was asked in. Not called "key": a widget already has one
  /// of those and it means something else entirely.
  final String askedIn;
  final VoidCallback onHearBoth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          right ? 'Yes: ${answer.name} in $askedIn' : 'It was ${answer.name}',
          key: const ValueKey('ear-verdict'),
          style: theme.textTheme.titleMedium?.copyWith(
            color: right ? scheme.tertiary : scheme.error,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          answer.about,
          key: const ValueKey('ear-why'),
          style: theme.textTheme.bodyMedium,
        ),
        if (!right) ...[
          const SizedBox(height: 10),
          Text(
            'You said ${picked.name}. Hear them one after the other: '
            'that is the difference worth learning.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          TextButton(
            key: const ValueKey('ear-hear-yours'),
            onPressed: onHearBoth,
            child: Text('Hear ${picked.name} Again'),
          ),
        ],
      ],
    );
  }
}
