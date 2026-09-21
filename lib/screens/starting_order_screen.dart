// Where to start: the book in an order that makes sense to learn in,
// rather than the order the alphabet happens to put it in.

import 'package:flutter/material.dart';

import '../library/find_tune.dart';
import '../library/library_store.dart';
import '../library/starting_order.dart';
import '../music/tune_library.dart';
import '../practice/practice_record.dart';
import 'setlists_screen.dart' show LibraryContext;
import 'tunes_page.dart' show SectionHeader;

class StartingOrderScreen extends StatelessWidget {
  const StartingOrderScreen({super.key, required this.deps});

  final LibraryContext deps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Where To Start')),
      body: ListenableBuilder(
        listenable: deps.library,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'The book is alphabetical, which is no help at all if you '
                'have never played any of it. This is an order to learn in '
                'instead, and a line on each tune saying what it is there '
                'to teach. Nothing is locked and nothing has to be '
                'finished: it is a suggestion, and the whole book is '
                'still where it was.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            for (final (i, stage) in startingOrder.indexed) ...[
              SectionHeader('${i + 1}. ${stage.name}'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  stage.about,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final step in stage.tunes) _StepCard(step: step, deps: deps),
            ],
          ],
        ),
      ),
    );
  }
}

/// One tune on the path: what it teaches, and how you have got on with it.
class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.deps});

  final PathStep step;
  final LibraryContext deps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tune = standards.where((t) => t.title == step.title).firstOrNull;
    // A tune the app hasn't got is left off rather than opening on
    // nothing: the path is written by hand and the book does change.
    if (tune == null) return const SizedBox.shrink();
    final runs = deps.library.runsFor(TuneRef.of(tune));
    final best = bestCleanTempo(runs);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('start-${step.title}'),
          onTap: () => deps.play(context, FoundTune(tune)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              step.title,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          // What the practice record knows about it, which
                          // is the only mark of progress here: no ticks
                          // for opening something, only for playing it.
                          if (runs.isNotEmpty)
                            Text(
                              best == null ? 'Played' : 'Clean at $best',
                              key: ValueKey('done-${step.title}'),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.tertiary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(step.why, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
