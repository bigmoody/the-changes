// Rhythm changes: the form, and the eight bars of it worth learning
// first.
//
// The bridge comes before the A section on this page, which is not the
// order they are played in. It is the order they are worth learning in:
// the A section is turnarounds you already know, and the bridge is four
// chords that unlock a shelf of tunes. Putting the familiar part first
// would bury the reason to be here.
//
// The list of tunes at the bottom is found rather than typed, by asking
// every chart in the library whether it has that bridge. So it cannot go
// stale, and it turned up something worth saying out loud: one of them
// is not rhythm changes at all, it has just borrowed the middle eight.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/arrangement.dart';
import '../music/loop_range.dart';
import '../music/rhythm_changes.dart';
import '../music/tune_library.dart';
import '../settings/app_settings.dart';
import '../theme.dart';

/// Which stretch of the form is playing.
enum _Playing { bridge, aSection, whole }

class RhythmChangesScreen extends StatefulWidget {
  const RhythmChangesScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<RhythmChangesScreen> createState() => _RhythmChangesScreenState();
}

class _RhythmChangesScreenState extends State<RhythmChangesScreen> {
  _Playing? _playing;

  /// The app's own rhythm changes progression, so what is described here
  /// is the chart the band actually plays.
  static final _form = practiceProgressions.firstWhere(
    (tune) => hasTheBridge(tune),
    orElse: () => standards.firstWhere(isRhythmChanges),
  );

  @override
  void dispose() {
    unawaited(widget.player.stop());
    super.dispose();
  }

  Future<void> _stop() async {
    if (mounted) setState(() => _playing = null);
    await widget.player.stop();
  }

  Future<void> _play(_Playing what) async {
    if (_playing == what) {
      await _stop();
      return;
    }
    await _stop();
    setState(() => _playing = what);
    final loop = switch (what) {
      _Playing.bridge => LoopRange.bars(
        _form,
        bridgeFirstBar,
        bridgeFirstBar + bridgeBars - 1,
      ),
      _Playing.aSection => LoopRange.bars(_form, 0, 7),
      _Playing.whole => LoopRange.wholeTune(_form),
    };
    try {
      await widget.player.start(
        BackingRequest(
          tune: _form,
          loop: loop,
          tempo: _form.defaultTempo,
          comping: widget.settings.comping,
          seed: math.Random().nextInt(1 << 31),
          // Eight bars twice, so it comes round and you hear it as a
          // shape rather than a list. The whole form once is plenty.
          arrangement: Arrangement(choruses: what == _Playing.whole ? 1 : 2),
        ),
      );
    } catch (e) {
      debugPrint('Could not play the form: $e');
      await _stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final withBridge = tunesWithTheBridge(standards);
    final borrowers = withBridge.where(borrowsTheBridge).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Rhythm Changes')),
      body: ListView(
        key: const ValueKey('rhythm-changes-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Learn the blues and you can sit in on half the gig. This is '
              'most of the rest: thirty-two bars, AABA, and ${withBridge.length} '
              'tunes in this app are built on it. Both halves are one idea '
              'repeated, which is why it is an evening rather than a month.',
              style: theme.textTheme.bodyMedium,
            ),
          ),

          _Heading('The Bridge'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              'Four dominant 7ths, two bars each, and every one is the V '
              'of the next. No ii chords, no resolutions in the middle: '
              'just a chain falling by fifths until it arrives home.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          _Cycle(steps: cycleSteps(_form)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'This is the part to learn first. The A section is '
              'turnarounds you can already play; these eight bars are the '
              'ones that are actually new, and they turn up in tunes that '
              'are not rhythm changes at all.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          _PlayRow(
            label: 'Hear the Bridge',
            playing: _playing == _Playing.bridge,
            onTap: () => _play(_Playing.bridge),
            id: 'play-bridge',
          ),

          _Heading('The A Section'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Eight bars, and six of them are a turnaround you have '
              'played a hundred times. In numbers rather than chords, so '
              'the repetition is visible:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final part in aSectionParts)
            _APartRow(key: ValueKey('a-part-${part.bars}'), part: part),
          _PlayRow(
            label: 'Hear the A Section',
            playing: _playing == _Playing.aSection,
            onTap: () => _play(_Playing.aSection),
            id: 'play-a-section',
          ),

          _Heading('All of It'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              'A, the same A, the bridge, and the A once more. In '
              '${_form.key}, at ${_form.defaultTempo}, which is where most '
              'people meet it.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          _PlayRow(
            label: 'Hear the Form',
            playing: _playing == _Playing.whole,
            onTap: () => _play(_Playing.whole),
            id: 'play-whole',
          ),

          _Heading('The Tunes'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              '${withBridge.length} tunes in this app have that bridge. '
              'Search for any of them and you already know the middle '
              'eight.',
              key: const ValueKey('tune-count'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.tertiary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tune in withBridge)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(tune.title),
                    labelStyle: theme.textTheme.labelSmall,
                  ),
              ],
            ),
          ),
          if (borrowers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                borrowers.length == 1
                    ? '${borrowers.single.title} is the odd one out: it has '
                          'this bridge but somebody else\'s A sections, so '
                          'it is not rhythm changes. That is the clearest '
                          'argument there is for learning the middle eight '
                          'on its own.'
                    : 'Some of those are not rhythm changes at all. They '
                          'have borrowed the middle eight, which is the '
                          'clearest argument there is for learning it on '
                          'its own.',
                key: const ValueKey('borrowed'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The bridge drawn as a chain, each chord pointing at the one it is the
/// V of, and the last pointing home.
class _Cycle extends StatelessWidget {
  const _Cycle({required this.steps});

  final List<CycleStep> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (steps.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              key: const ValueKey('the-cycle'),
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final step in steps) ...[
                  Text(
                    handSymbol(step.chord.display),
                    textScaler: TextScaler.noScaling,
                    style: handLettered(
                      TextStyle(
                        fontSize: 24,
                        height: 1,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_right_alt,
                      size: 20,
                      color: scheme.tertiary,
                    ),
                  ),
                ],
                // Where the last one lands: the key, and the top of the
                // next A section.
                Text(
                  handSymbol(steps.last.resolvesTo.display),
                  textScaler: TextScaler.noScaling,
                  style: handLettered(
                    TextStyle(
                      fontSize: 24,
                      height: 1,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bars ${bridgeFirstBar + 1} to ${bridgeFirstBar + bridgeBars}, '
            'two bars each. The last one is the V of the key, so the cycle '
            'has been walking home since it started.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two bars of the A section: which bars, what they are in numbers, and
/// what that means.
class _APartRow extends StatelessWidget {
  const _APartRow({super.key, required this.part});

  final APart part;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  part.bars,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  part.numerals,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.tertiary,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 2),
            child: Text(
              part.about,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A section title, in the app's own lettering.
class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// One play button, which stops what it started.
class _PlayRow extends StatelessWidget {
  const _PlayRow({
    required this.label,
    required this.playing,
    required this.onTap,
    required this.id,
  });

  final String label;
  final bool playing;
  final VoidCallback onTap;
  final String id;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: SizedBox(
      width: double.infinity,
      child: playing
          ? FilledButton.icon(
              key: ValueKey(id),
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
              onPressed: onTap,
            )
          : FilledButton.tonalIcon(
              key: ValueKey(id),
              icon: const Icon(Icons.play_arrow),
              label: Text(label),
              onPressed: onTap,
            ),
    ),
  );
}
