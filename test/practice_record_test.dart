// The practice record: what counts as a run, what counts as clean, and
// when you have earned the next four beats a minute.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/practice/practice_record.dart';

/// A run, newest-first order being the caller's job. [ago] is days back.
Run run({int tempo = 140, int asked = 12, int hits = 12, int ago = 0}) => (
  at: DateTime(2026, 9, 21).subtract(Duration(days: ago)),
  tempo: tempo,
  asked: asked,
  hits: hits,
);

void main() {
  group('what a run says', () {
    test('a run nobody marked has no verdict on it', () {
      final unmarked = run(asked: 0, hits: 0);
      expect(unmarked.accuracy, isNull);
      expect(unmarked.isGraded, isFalse);
      expect(unmarked.isClean, isFalse, reason: 'unmarked is not clean');
    });

    test('too few changes is not enough to judge', () {
      // You can land four chord tones by accident.
      expect(run(asked: 4, hits: 4).isGraded, isFalse);
      expect(run(asked: 4, hits: 4).isClean, isFalse);
      expect(run(asked: gradeableChanges, hits: 8).isGraded, isTrue);
    });

    test('clean is most of them, not all of them', () {
      expect(run(asked: 10, hits: 10).isClean, isTrue);
      expect(run(asked: 10, hits: 8).isClean, isTrue, reason: 'four fifths');
      expect(run(asked: 10, hits: 7).isClean, isFalse);
    });
  });

  group('the tempo it opens at', () {
    test('a tune never played opens where it is written', () {
      expect(tempoToOpenAt(const []), isNull);
    });

    test('where you left off, not the best you ever managed', () {
      // The complaint this guards against: opening at your record means
      // every session starts by failing.
      final runs = [
        run(tempo: 120, ago: 0),
        run(tempo: 200, ago: 1),
        run(tempo: 120, ago: 2),
      ];
      expect(tempoToOpenAt(runs), 120);
      expect(bestCleanTempo(runs), 200, reason: 'still the record');
    });

    test('a scruffy run still counts as where you left off', () {
      expect(tempoToOpenAt([run(tempo: 180, asked: 12, hits: 2)]), 180);
    });

    test('the best clean tempo ignores the runs that were not clean', () {
      expect(
        bestCleanTempo([
          run(tempo: 220, asked: 12, hits: 3),
          run(tempo: 140, asked: 12, hits: 12),
        ]),
        140,
      );
      expect(bestCleanTempo([run(asked: 0, hits: 0)]), isNull);
    });
  });

  group('earning the next step', () {
    test('one clean run is not enough', () {
      expect(readyToMoveUp([run(tempo: 140)], at: 140), isNull);
    });

    test('two clean runs at the tempo earns four more', () {
      expect(readyToMoveUp([run(tempo: 140), run(tempo: 140)], at: 140), 144);
    });

    test('a scruffy run since then puts it back', () {
      // Newest first: clean, clean, but a miss in between them.
      expect(
        readyToMoveUp([
          run(tempo: 140),
          run(tempo: 140, asked: 12, hits: 4),
          run(tempo: 140),
        ], at: 140),
        isNull,
      );
    });

    test('clean runs at another tempo say nothing about this one', () {
      expect(
        readyToMoveUp([run(tempo: 120), run(tempo: 120)], at: 140),
        isNull,
      );
    });

    test('an unmarked run is passed over, not held against you', () {
      // You played it through without the microphone. That is not a
      // failure, so it does not break the streak.
      expect(
        readyToMoveUp([
          run(tempo: 140),
          run(tempo: 140, asked: 0, hits: 0),
          run(tempo: 140),
        ], at: 140),
        144,
      );
    });

    test('a run too short to grade is passed over too', () {
      expect(
        readyToMoveUp([
          run(tempo: 140),
          run(tempo: 140, asked: 3, hits: 0),
          run(tempo: 140),
        ], at: 140),
        144,
      );
    });
  });

  group('keeping them', () {
    test('the newest goes on the front', () {
      final runs = withRun([run(tempo: 120)], run(tempo: 140));
      expect(runs.first.tempo, 140);
      expect(runs.last.tempo, 120);
    });

    test('a long record is trimmed, oldest off the end', () {
      var runs = <Run>[];
      for (var i = 0; i < runsKept + 10; i++) {
        runs = withRun(runs, run(tempo: 100 + i));
      }
      expect(runs, hasLength(runsKept));
      expect(runs.first.tempo, 100 + runsKept + 9, reason: 'newest kept');
      expect(runs.map((r) => r.tempo), isNot(contains(100)));
    });
  });

  group('by tempo', () {
    test('fastest first, with how many were clean at each', () {
      final rows = byTempo([
        run(tempo: 120),
        run(tempo: 160, asked: 12, hits: 3),
        run(tempo: 120),
        run(tempo: 160),
        run(tempo: 120, asked: 0, hits: 0),
      ]);
      expect([for (final row in rows) row.tempo], [160, 120]);
      expect(rows.first.runs, 2);
      expect(rows.first.clean, 1);
      // The unmarked run at 120 isn't counted either way.
      expect(rows.last.runs, 2);
      expect(rows.last.clean, 2);
    });

    test('nothing marked, nothing to show', () {
      expect(byTempo([run(asked: 0, hits: 0)]), isEmpty);
    });
  });

  group('how long ago', () {
    final now = DateTime(2026, 9, 21, 14);
    test('days, because that is how practice is counted', () {
      expect(howLongAgo(DateTime(2026, 9, 21, 9), now: now), 'today');
      expect(howLongAgo(DateTime(2026, 9, 20, 23), now: now), 'yesterday');
      expect(howLongAgo(DateTime(2026, 9, 18), now: now), '3 days ago');
      expect(howLongAgo(DateTime(2026, 9, 13), now: now), 'last week');
      expect(howLongAgo(DateTime(2026, 9, 5), now: now), '2 weeks ago');
      expect(howLongAgo(DateTime(2026, 6, 1), now: now), 'a while ago');
    });

    test('late last night is yesterday, not two hours ago', () {
      // Counted by the calendar, not by the clock.
      expect(howLongAgo(DateTime(2026, 9, 20, 23, 30), now: now), 'yesterday');
    });
  });

  group('saved and read back', () {
    final tune = TuneRef.standard('Autumn Leaves');

    test('a run survives being written out and read in', () async {
      final store = LibraryStore.inMemory();
      await store.noteRun(tune, run(tempo: 152, asked: 11, hits: 9));
      final back = LibraryStore.readRuns(store.toJson());
      expect(back[tune], hasLength(1));
      expect(back[tune]!.single.tempo, 152);
      expect(back[tune]!.single.asked, 11);
      expect(back[tune]!.single.hits, 9);
      expect(back[tune]!.single.at.year, 2026);
    });

    test('a record that will not read is dropped, not fatal', () {
      final back = LibraryStore.readRuns({
        'runs': {
          's:Broken': [
            [1, 2],
          ],
          's:Fine': [
            [1700000000000, 140, 12, 10],
          ],
        },
      });
      expect(back.containsKey(TuneRef.standard('Broken')), isFalse);
      expect(back[TuneRef.standard('Fine')], hasLength(1));
    });

    test('the store keeps them newest first and forgets on request', () async {
      final store = LibraryStore.inMemory();
      await store.noteRun(tune, run(tempo: 120, ago: 1));
      await store.noteRun(tune, run(tempo: 140));
      expect([for (final r in store.runsFor(tune)) r.tempo], [140, 120]);
      await store.clearRuns(tune);
      expect(store.runsFor(tune), isEmpty);
    });
  });
}
