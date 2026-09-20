// Taking the chart away while the band keeps playing.
//
// Playing a tune off the page and playing it are not the same thing, and
// the chart is very good at hiding which one you are doing. As long as it
// is there you are reading, and reading is a crutch you cannot take onto a
// stand: nobody puts a chart in front of you at a session.
//
// So it goes, a rung at a time, while the band carries on. First the
// chords, which is the memory test. Then the bars as well, which is the
// harder one — keeping your place in the form with nothing to look at is
// a separate skill from knowing the changes, and it is the one that comes
// apart first when you are nervous.
//
// It always comes back when the band stops. This is an exercise, not a
// punishment, and you have to be able to set up the next run.

/// How much of the chart you can see.
enum ChartShows {
  /// The chart as written.
  everything,

  /// The bars, their numbers and the rehearsal letters, with the bar being
  /// played lit up — but no chords in them. You can see where you are; what
  /// is there is yours to remember.
  whereYouAre,

  /// Nothing but the band.
  nothing;

  /// Whether a chord symbol is written anywhere.
  bool get hasChords => this == everything;

  /// What has just been taken away, as a heading.
  String get title => switch (this) {
    everything => '',
    whereYouAre => 'Chords Off',
    nothing => 'Chart Off',
  };

  /// And what you have left.
  String get line => switch (this) {
    everything => '',
    whereYouAre => 'The bars are still there. What is in them is yours.',
    nothing => 'Nothing but the band.',
  };
}

/// When the chart starts going away, measured in choruses.
enum FadeChart {
  never('Off', choruses: 0),
  afterOne('After 1 Chorus', choruses: 1),
  afterTwo('After 2 Choruses', choruses: 2),
  afterFour('After 4 Choruses', choruses: 4);

  const FadeChart(this.label, {required this.choruses});

  final String label;

  /// How many choruses each rung lasts: read for this many, then the bars
  /// alone for the same again, then nothing.
  final int choruses;

  bool get isOn => this != never;

  /// What the chart shows on [chorus], counting choruses from 1.
  ///
  /// A null chorus is the band stopped or still counting in, and then the
  /// chart is always there — you cannot start a run you cannot set up.
  ChartShows showsOn(int? chorus) {
    if (!isOn || chorus == null) return ChartShows.everything;
    return switch ((chorus - 1) ~/ choruses) {
      <= 0 => ChartShows.everything,
      1 => ChartShows.whereYouAre,
      _ => ChartShows.nothing,
    };
  }
}
