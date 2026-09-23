// A recording of real players, and the sums that let the app play it at a
// tempo and in a key other than the one it was played in.
//
// The band is generated, so it can be asked for any tempo and any key and
// simply plays it. A recording cannot: it was played once, at one tempo,
// in one key, and everything else is the audio engine pushing it about.
// What follows is how far it is being pushed, and how to tell when that is
// too far.
//
// Two knobs do the work, and it matters which is which:
//
//  • Relative play speed resamples. A recording played at 1.1 runs ten per
//    cent faster and sounds a whole tone higher, the way tape did. It is
//    exact: nothing is invented, so nothing can sound wrong.
//  • The pitch shift filter moves the pitch without the speed. This is the
//    one that guesses, and every artefact comes from it.
//
// So to play a take at tempo T in a key k semitones from the one it was
// recorded in, the speed is T/bpm and the filter has to undo whatever
// pitch that dragged along with it:
//
//     speed = T / bpm
//     shift = 2^(k/12) / speed
//
// and the single honest measure of how hard the recording is working is
// how far that shift is from 1, in cents. That is also why the template
// asks for the same changes at two tempos in two keys: playing faster and
// higher partly cancels, so four takes cover far more ground than four
// times as much of one.

import 'dart:math' as math;

/// One of the three files that make up a take.
///
/// Three rather than a mix because the mixer is the point: with stems you
/// can pull the piano down, or drop it entirely and sit in the chair
/// yourself while the real bass and drums keep going.
enum TakeStem {
  bass('Bass'),
  drums('Drums'),
  comp('Comp');

  const TakeStem(this.label);
  final String label;
}

/// How hard the pitch shifter is working, in words.
///
/// The boundaries are a starting point, not a measurement. Nobody knows
/// what this shifter sounds like on a real rhythm section until somebody
/// listens to one, which is exactly what the pilot is for. They are here
/// so the app says something honest in the meantime, and they are meant to
/// be moved once there is an answer.
enum TakeStrain {
  asRecorded('As recorded'),
  close('Close to it'),
  stretched('Stretched'),
  tooFar('Too far');

  const TakeStrain(this.label);
  final String label;
}

/// What the audio engine has to do to play a take where it is wanted.
class TakeShift {
  const TakeShift({required this.speed, required this.shift});

  /// The engine's relative play speed: 1 is the tempo it was recorded at.
  final double speed;

  /// The pitch shift filter's ratio: 1 is the key it was recorded in.
  final double shift;

  /// How far the filter is moving the pitch. Negative is down.
  ///
  /// This is the number that says whether it will sound all right, because
  /// the speed change on its own cannot sound wrong.
  double get cents => 1200 * math.log(shift) / math.ln2;

  /// How much faster or slower than recorded, as a percentage.
  double get stretchPercent => (speed - 1) * 100;

  TakeStrain get strain => switch (cents.abs()) {
    < 50 => TakeStrain.asRecorded,
    < 200 => TakeStrain.close,
    < 400 => TakeStrain.stretched,
    _ => TakeStrain.tooFar,
  };

  /// Whether this is far enough to be worth saying out loud.
  bool get worthSaying => strain.index >= TakeStrain.stretched.index;
}

/// A recording made to the template, and the facts the app needs about it.
///
/// Every one of these is something no audio file carries and only the
/// person who recorded it knows. The template asks for them in writing for
/// that reason.
class RecordedTake {
  const RecordedTake({
    required this.name,
    required this.files,
    required this.bpm,
    required this.key,
    required this.bars,
    required this.choruses,
    this.beatsPerBar = 4,
    this.startSeconds = 0,
  });

  /// What the mixer and the picker call it.
  final String name;

  /// The file name of each stem, not its path: where the app may keep its
  /// files moves between one launch and the next on iOS.
  final Map<TakeStem, String> files;

  /// The number the click was set to, not an estimate made afterwards.
  final double bpm;

  /// The pitch class it was played in, C being 0.
  final int key;

  /// The bars in one chorus.
  final int bars;

  /// How many times round the form the recording goes.
  final int choruses;

  final int beatsPerBar;

  /// Where bar 1 beat 1 is in the file.
  ///
  /// The template says to trim the count-in off so this is zero, and it
  /// usually will be. It is here because a file that is a few milliseconds
  /// late is otherwise unusable, and nudging it is a great deal cheaper
  /// than recording it again.
  final double startSeconds;

  int get beats => bars * choruses * beatsPerBar;

  /// How long the music should last at the tempo it says it was played at.
  double get seconds => bpm <= 0 ? 0 : beats * 60 / bpm;

  /// The tempo a recording this long was really played at, given that it
  /// holds the number of choruses it says it does.
  ///
  /// For checking a stated tempo against the file rather than taking it on
  /// trust: a take labelled 120 that comes out at 124 puts the chart half
  /// a bar out by the last chorus, and nothing on screen would say why.
  double bpmFrom(double playingSeconds) =>
      playingSeconds <= 0 ? 0 : beats * 60 / playingSeconds;

  /// How far off the stated tempo a file of [playingSeconds] is, as a
  /// percentage. Zero when it is exactly as claimed.
  double tempoErrorFrom(double playingSeconds) {
    if (bpm <= 0 || playingSeconds <= 0) return 0;
    return (bpmFrom(playingSeconds) - bpm) / bpm * 100;
  }

  /// The semitones from the key this was played in to [soundingKey],
  /// whichever way round is shorter.
  ///
  /// Nearest rather than always upward, because register is worth more
  /// than the shifter's comfort: a bass line moved up seven semitones
  /// stops being a bass line, while the same line down five is still one.
  int moveTo(int soundingKey) => ((soundingKey - key + 6) % 12 + 12) % 12 - 6;

  /// What the engine has to do to play this at [tempo] in [soundingKey].
  TakeShift shiftTo({required num tempo, required int soundingKey}) {
    final speed = bpm <= 0 ? 1.0 : tempo / bpm;
    return TakeShift(
      speed: speed,
      shift: math.pow(2, moveTo(soundingKey) / 12) / speed,
    );
  }

  RecordedTake renamed(String name) => _copy(name: name);
  RecordedTake atTempo(double bpm) => _copy(bpm: bpm);
  RecordedTake inKey(int key) => _copy(key: key);
  RecordedTake startingAt(double seconds) => _copy(startSeconds: seconds);

  RecordedTake _copy({
    String? name,
    double? bpm,
    int? key,
    double? startSeconds,
  }) => RecordedTake(
    name: name ?? this.name,
    files: files,
    bpm: bpm ?? this.bpm,
    key: key ?? this.key,
    bars: bars,
    choruses: choruses,
    beatsPerBar: beatsPerBar,
    startSeconds: startSeconds ?? this.startSeconds,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'files': {for (final e in files.entries) e.key.name: e.value},
    'bpm': bpm,
    'key': key,
    'bars': bars,
    'choruses': choruses,
    'beatsPerBar': beatsPerBar,
    'startSeconds': startSeconds,
  };

  /// Null rather than throwing when the stored shape is not what this
  /// version writes: a take is never worth losing a tune over.
  static RecordedTake? fromJson(Map<String, Object?> json) {
    final files = json['files'];
    final bpm = json['bpm'];
    final bars = json['bars'];
    if (files is! Map || bpm is! num || bars is! num) return null;
    final stems = <TakeStem, String>{};
    for (final entry in files.entries) {
      final stem = TakeStem.values.where((s) => s.name == entry.key);
      if (stem.isEmpty || entry.value is! String) continue;
      stems[stem.first] = entry.value as String;
    }
    if (stems.isEmpty) return null;
    return RecordedTake(
      name: json['name'] as String? ?? 'Recording',
      files: stems,
      bpm: bpm.toDouble(),
      key: (json['key'] as num?)?.round() ?? 0,
      bars: bars.round(),
      choruses: (json['choruses'] as num?)?.round() ?? 1,
      beatsPerBar: (json['beatsPerBar'] as num?)?.round() ?? 4,
      startSeconds: (json['startSeconds'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// The takes imported for one tune.
///
/// A set rather than one recording because that is what the template
/// delivers, and because it is the whole reason for recording four of
/// them: asked for a tempo and a key, the app plays whichever take needs
/// the least pushing about to get there.
class TakeSet {
  const TakeSet(this.takes);

  static const empty = TakeSet([]);

  final List<RecordedTake> takes;

  bool get isEmpty => takes.isEmpty;
  int get length => takes.length;

  /// The take that lands closest to [tempo] and [soundingKey].
  ///
  /// Least work for the pitch shifter wins, because that is where every
  /// artefact comes from. A tie goes to the take that is also nearest in
  /// tempo, which only happens when two takes are a tritone apart.
  RecordedTake? bestFor({required num tempo, required int soundingKey}) {
    RecordedTake? best;
    TakeShift? bestShift;
    for (final take in takes) {
      final shift = take.shiftTo(tempo: tempo, soundingKey: soundingKey);
      if (bestShift == null ||
          shift.cents.abs() < bestShift.cents.abs() - 0.001 ||
          (shift.cents.abs() < bestShift.cents.abs() + 0.001 &&
              shift.stretchPercent.abs() < bestShift.stretchPercent.abs())) {
        best = take;
        bestShift = shift;
      }
    }
    return best;
  }

  TakeSet plus(RecordedTake take) => TakeSet([...takes, take]);

  TakeSet without(String name) => TakeSet([
    for (final take in takes)
      if (take.name != name) take,
  ]);

  TakeSet replacing(String name, RecordedTake take) => TakeSet([
    for (final t in takes)
      if (t.name == name) take else t,
  ]);

  List<Map<String, Object?>> toJson() => [for (final t in takes) t.toJson()];

  static TakeSet fromJson(Object? json) {
    if (json is! List) return empty;
    return TakeSet([
      for (final entry in json)
        if (entry is Map<String, Object?>) ?RecordedTake.fromJson(entry),
    ]);
  }
}
