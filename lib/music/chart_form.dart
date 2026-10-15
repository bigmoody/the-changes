// Where the repeat signs and the ending brackets fall in a chart.
//
// A progression is written as bars, with section letters and, on a
// section, how many times it is played and which bars are its 1st and 2nd
// endings. Every way of writing that chart out again — an iReal Pro link,
// a MusicXML score, a page of music — needs the same thing worked out
// first: which bar opens a repeat, which bar closes it, and where each
// ending bracket starts and stops. Worked out once here, so the exports
// cannot disagree with each other about the form.

import 'user_progression.dart';

/// A section repeated with a 1st and 2nd ending.
typedef ChartEndings = ({
  /// The first bar of the 1st ending, and its last.
  int firstStart,
  int firstEnd,

  /// The first bar of the 2nd ending, and its last.
  int secondStart,
  int secondEnd,
});

/// One section of the chart, and what happens at the end of it.
class ChartSection {
  const ChartSection({
    required this.start,
    required this.end,
    required this.letter,
    required this.times,
    this.endings,
  });

  /// The first bar of the section, and the bar after its last.
  final int start;
  final int end;

  /// The letter on the chart ('A', 'B', 'Intro' …), or null where the
  /// chart has no sections and this stands for the whole of it.
  final String? letter;

  /// How many times through: 1 for a section played once.
  final int times;

  /// Its 1st and 2nd endings, where it has a pair that can be written as
  /// a repeat. Null otherwise, and then the section is written out as it
  /// stands.
  final ChartEndings? endings;

  /// Whether the section is played more than once, either way round.
  bool get repeats => endings != null || times > 1;
}

/// The sections of [progression], in order, with their repeats and
/// endings worked out.
///
/// A chart with no section letters is one section covering all of it.
List<ChartSection> chartForm(UserProgression progression) {
  final bars = progression.bars;
  if (bars.isEmpty) return const [];
  final starts =
      progression.sections.keys.where((i) => i < bars.length).toList()..sort();
  if (starts.isEmpty || starts.first != 0) starts.insert(0, 0);
  return [
    for (var s = 0; s < starts.length; s++)
      () {
        final start = starts[s];
        final end = s + 1 < starts.length ? starts[s + 1] : bars.length;
        return ChartSection(
          start: start,
          end: end,
          letter: progression.sections[start],
          times: progression.repeatsOf(start),
          endings: endingsOf(progression, start, end),
        );
      }(),
  ];
}

/// Where a section's 1st and 2nd endings are, if it has a pair that can be
/// written as a repeat: a run of 1st-ending bars after some body, then as
/// many 2nd-ending bars running to the end of the section. Anything else
/// (an odd ending on its own, endings of different lengths, an ending in
/// the middle of a section) has no repeat sign that would play it back the
/// same way, so it is written out with no endings at all.
ChartEndings? endingsOf(UserProgression progression, int start, int end) {
  List<int> marked(int ending) => [
    for (var i = start; i < end; i++)
      if (progression.endings[i] == ending) i,
  ];
  final first = marked(1);
  final second = marked(2);
  if (first.isEmpty || second.isEmpty) return null;
  if (first.length != second.length) return null;
  bool unbroken(List<int> bars) => bars.last - bars.first == bars.length - 1;
  if (!unbroken(first) || !unbroken(second)) return null;
  // The section needs bars of its own before the 1st ending, and the 2nd
  // ending has to be the last of it.
  if (first.first <= start) return null;
  if (second.first != first.last + 1 || second.last != end - 1) return null;
  return (
    firstStart: first.first,
    firstEnd: first.last,
    secondStart: second.first,
    secondEnd: second.last,
  );
}
