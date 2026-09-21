// What you have actually done: every run at a tune, how fast, and how it
// went.
//
// The app was already working all of this out and throwing it away. It
// knew the tempo, and when the microphone was on it marked every change
// and produced a score, and then the screen closed and none of it was
// kept. So the one question a practising musician actually asks (am I
// getting anywhere, and what do I play next), the app couldn't answer,
// and the player was left keeping it on paper.
//
// The rules live here, away from the storage, because they are the part
// worth arguing about: what counts as a run at all, what counts as clean,
// and when you have earned the next four beats a minute.

/// One run at a tune: when it was, how fast, and how it was marked.
///
/// [asked] is nought when the microphone wasn't listening. That is still a
/// run: it says you played the tune, and at what tempo. It just isn't a
/// verdict on how it went.
typedef Run = ({DateTime at, int tempo, int asked, int hits});

/// Fewer changes than this is not enough to call a run good or bad. You
/// can land four chord tones by accident; you cannot land twelve.
const gradeableChanges = 8;

/// The share of changes you have to find for a run to count as clean.
/// Not everything: a run where you found four fifths of the changes is a
/// run you are on top of, and waiting for the perfect one is how people
/// stay at the same tempo for a year.
const cleanEnough = 0.8;

/// How many clean runs in a row earn the next step up.
const runsToMoveUp = 2;

/// How much faster the next step is. Four beats a minute is the step
/// players have always used: big enough to feel, small enough to hold.
const tempoStep = 4;

extension Marking on Run {
  /// Nought to one, or null when nothing was marked.
  double? get accuracy => asked == 0 ? null : hits / asked;

  /// Whether enough was marked for this run to be a verdict.
  bool get isGraded => asked >= gradeableChanges;

  /// A run you were on top of.
  bool get isClean => isGraded && hits / asked >= cleanEnough;
}

/// The tempo to open a tune at, given [runs] (newest first), or null when
/// it has never been played and the written tempo should stand.
///
/// Where you left off, not the best you have ever managed. Opening at your
/// record would mean every session starts by failing, and the tempo you
/// stopped at is the one you were working on.
int? tempoToOpenAt(List<Run> runs) => runs.isEmpty ? null : runs.first.tempo;

/// The fastest tempo you have played this clean, or null if you never have.
int? bestCleanTempo(List<Run> runs) {
  int? best;
  for (final run in runs) {
    if (!run.isClean) continue;
    if (best == null || run.tempo > best) best = run.tempo;
  }
  return best;
}

/// The next tempo to try, or null when you haven't earned it yet.
///
/// Earned means the last [runsToMoveUp] marked runs at this tempo were all
/// clean. Runs at other tempos don't count either way: a clean run at 120
/// says nothing about whether you are ready to leave 140, and an unmarked
/// one says nothing at all, so it is passed over rather than breaking the
/// streak.
int? readyToMoveUp(List<Run> runs, {required int at}) {
  var clean = 0;
  for (final run in runs) {
    if (run.tempo != at || !run.isGraded) continue;
    if (!run.isClean) return null;
    clean++;
    if (clean >= runsToMoveUp) return at + tempoStep;
  }
  return null;
}

/// How many runs at a tune are kept. Enough to see the last few weeks of
/// it, and few enough that a big library is still a small file.
const runsKept = 30;

/// [runs] with [run] added, newest first and trimmed to [runsKept].
List<Run> withRun(List<Run> runs, Run run) =>
    [run, ...runs].take(runsKept).toList();

/// When a run was, as a practising musician thinks of it.
///
/// Days, not dates: what matters about a run is whether it was this
/// afternoon or a fortnight ago. Past a month the exact date stops meaning
/// anything either, so it becomes "a while ago" rather than pretending to
/// be precise about something nobody is counting.
String howLongAgo(DateTime at, {DateTime? now}) {
  final today = now ?? DateTime.now();
  // Whole days apart on the calendar, so 23:00 and 01:00 are "yesterday"
  // rather than "today" on a two-hour difference.
  final days = DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  return switch (days) {
    <= 0 => 'today',
    1 => 'yesterday',
    < 7 => '$days days ago',
    < 14 => 'last week',
    < 31 => '${days ~/ 7} weeks ago',
    _ => 'a while ago',
  };
}

/// Every tempo you have played it at that was marked, fastest first, with
/// how it went at each: what the record is actually for.
List<({int tempo, int runs, int clean})> byTempo(List<Run> runs) {
  final tempos = <int, ({int runs, int clean})>{};
  for (final run in runs) {
    if (!run.isGraded) continue;
    final so = tempos[run.tempo] ?? (runs: 0, clean: 0);
    tempos[run.tempo] = (
      runs: so.runs + 1,
      clean: so.clean + (run.isClean ? 1 : 0),
    );
  }
  final sorted = tempos.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final tempo in sorted)
      (tempo: tempo, runs: tempos[tempo]!.runs, clean: tempos[tempo]!.clean),
  ];
}
