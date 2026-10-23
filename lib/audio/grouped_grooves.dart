// The grooves in three, five and seven.
//
// A groove written for a bar of four and played in another length is
// either cut short or has a beat stuck on, and neither is anything a
// drummer plays. What they do instead is count the bar in groups of two
// and three (see [meterGroups]) and play the groove's own idea in each:
// a jazz drummer in five plays a waltz bar and then half a bar of four;
// a funk drummer in seven plays four and then three, with the backbeat
// at the end of each. So each groove here has a cell for a group of two
// and one for a group of three, written from what that groove is, and a
// bar is its groups one after another.
//
// The grooves in four are not touched: they are written whole and have
// been listened to. A jazz waltz in three keeps its own pattern too.
//
// The kick figures for funk, calypso and bossa are worked out from the
// bar and the group alone (see [groupKicks]), so the bass, which reads
// the same function, lands with the drum without being told.

import 'dart:math' as math;

import '../music/meter.dart';
import '../music/tune.dart';
import 'drum_patterns.dart';

double _human(math.Random random) => 0.85 + random.nextDouble() * 0.15;

/// Where the kick goes in a group of [length] beats, for the grooves
/// whose kick is a figure: funk's riff, calypso's 3+3, bossa's surdo.
/// [bar] and [group] pick the riff, held for two bars as a riff is, so
/// the bass reading this lands where the drum does.
List<double> groupKicks(Feel feel, int length, {int bar = 0, int group = 0}) {
  final riff = bar ~/ 2 + group;
  return switch (feel) {
    // The riff: a two group answers the downbeat on its "and" half the
    // time; a three group puts its second kick before the backbeat on 3.
    Feel.funk => switch (length) {
      2 => riff.isEven ? const [0.0] : const [0.0, 0.5],
      3 => const [
        [0.0, 1.5],
        [0.0, 1.0],
        [0.0, 0.5, 1.5],
      ][riff % 3],
      _ => const [0.0],
    },
    // Three and three in a group of three, the dotted quarters a calypso
    // in three is built on; a group of two is the "2" of the 3-3-2.
    Feel.calypso => length == 3 ? const [0.0, 1.5] : const [0.0],
    // The surdo's heartbeat: the front of the group, and in three its
    // last beat as well, which is where a bossa in three leans.
    Feel.bossa || Feel.samba => length == 3 ? const [0.0, 2.0] : const [0.0],
    _ => const [0.0],
  };
}

/// One bar of [feel] in a bar of [beatsPerBar] simple beats, played as
/// its groups. See the top of the file.
List<DrumHit> groupedDrumBar({
  required Feel feel,
  required int bar,
  required int beatsPerBar,
  required math.Random random,
  bool brushes = false,
}) {
  final lengths = meterGroups(beatsPerBar);
  final starts = groupStarts(beatsPerBar);
  final hits = <DrumHit>[];
  for (var g = 0; g < lengths.length; g++) {
    final cell = _cell(
      feel,
      lengths[g],
      bar: bar,
      group: g,
      firstOfBar: g == 0,
      random: random,
      brushes: brushes,
    );
    for (final hit in cell) {
      hits.add(hit.at(hit.beat + starts[g]));
    }
  }
  // Something a bar or two can hang on, as a drummer leaves one: the
  // comping ghost a swing drummer drops in now and then.
  if ((feel == Feel.swing || feel == Feel.jazzWaltz) &&
      random.nextDouble() < 0.3) {
    hits.add(
      DrumHit(
        drum: Drum.snare,
        beat: random.nextInt(beatsPerBar) + 0.5,
        velocity: (brushes ? 0.18 : 0.22) * _human(random),
      ),
    );
  }
  if (bar % 8 == 7) {
    hits.addAll(
      _fill(feel, lengths.last, starts.last, random, brushes: brushes),
    );
  }
  return hits;
}

/// The end of an eight-bar phrase: the last group played through, so
/// the top of the next one is somewhere to arrive.
List<DrumHit> _fill(
  Feel feel,
  int length,
  int start,
  math.Random random, {
  required bool brushes,
}) {
  if (feel == Feel.ballad || random.nextDouble() > 0.5) return const [];
  final from = start + length - 1.0;
  final latin =
      feel == Feel.bossa || feel == Feel.samba || feel == Feel.calypso;
  if (latin) {
    return [
      DrumHit(drum: Drum.tomHigh, beat: from, velocity: 0.5 * _human(random)),
      DrumHit(
        drum: Drum.tomLow,
        beat: from + 0.5,
        velocity: 0.55 * _human(random),
      ),
    ];
  }
  final level = brushes ? 0.4 : 0.55;
  return [
    DrumHit(drum: Drum.snare, beat: from, velocity: level * _human(random)),
    DrumHit(
      drum: Drum.snare,
      beat: from + 0.5,
      velocity: (level - 0.1) * _human(random),
    ),
  ];
}

List<DrumHit> _cell(
  Feel feel,
  int length, {
  required int bar,
  required int group,
  required bool firstOfBar,
  required math.Random random,
  required bool brushes,
}) {
  final last = length - 1.0;
  final hits = <DrumHit>[];
  void hit(Drum drum, double beat, double velocity, {bool hard = false}) =>
      hits.add(
        DrumHit(
          drum: drum,
          beat: beat,
          velocity: velocity * _human(random),
          hard: hard,
        ),
      );
  void swirl(double beat, double velocity, double beats) => hits.add(
    DrumHit(
      drum: Drum.swirl,
      beat: beat,
      velocity: velocity * _human(random),
      beats: beats,
    ),
  );
  // The foot on the hi-hat closes on the last beat of every group: the
  // 2 and 4 of a bar of four, and in five the 3 and 5, which is what
  // tells the band where each group ends.
  void foot(double velocity) =>
      hit(Drum.hiHatPedal, last, velocity, hard: true);

  switch (feel) {
    case Feel.swing || Feel.jazzWaltz:
      // The ride's "ding, ding-a": every beat, and the skip note after
      // the second beat of the group, where it falls in four and in a
      // waltz. With brushes, the same rhythm tapped on the head and a
      // circle turning under the group.
      for (var beat = 0; beat < length; beat++) {
        final onLast = beat == length - 1;
        hit(
          brushes ? Drum.snare : Drum.ride,
          beat.toDouble(),
          (brushes ? 0.32 : 0.52) + (onLast ? 0.08 : 0),
        );
        hit(Drum.kick, beat.toDouble(), 0.16);
      }
      hit(brushes ? Drum.snare : Drum.ride, 1.5, brushes ? 0.24 : 0.4);
      if (brushes) swirl(0, 0.2, length.toDouble());
      foot(0.5);
    case Feel.ballad:
      // Sparse: the time on the ride or under the brush, nothing pushing.
      for (var beat = 0; beat < length; beat++) {
        if (!brushes) hit(Drum.ride, beat.toDouble(), 0.4);
        hit(Drum.kick, beat.toDouble(), 0.12);
      }
      if (brushes) {
        swirl(0, 0.22, length.toDouble());
        hit(Drum.snare, last, 0.22);
      }
      foot(0.42);
    case Feel.shuffle:
      // The shuffle on the ride, a backbeat on the last beat of each
      // group, the kick on its front.
      for (var beat = 0; beat < length; beat++) {
        hit(Drum.ride, beat.toDouble(), 0.5);
        hit(Drum.ride, beat + 0.5, 0.34);
      }
      hit(Drum.snare, last, 0.5, hard: true);
      hit(Drum.kick, 0, firstOfBar ? 0.5 : 0.4);
      foot(0.4);
    case Feel.funk:
      // Eighths on the hat, leaning on the beat; the backbeat at the end
      // of each group; the kick's riff, which the bass plays too.
      for (var eighth = 0; eighth < length * 2; eighth++) {
        hit(
          Drum.hiHatClosed,
          eighth / 2,
          eighth.isEven ? 0.7 : 0.44,
          hard: eighth.isEven,
        );
      }
      hit(Drum.snare, last, 0.5, hard: true);
      if (length == 3 && random.nextDouble() < 0.4) {
        hit(Drum.snare, 1.5, 0.13);
      }
      for (final beat in groupKicks(feel, length, bar: bar, group: group)) {
        hit(Drum.kick, beat, beat == 0 && firstOfBar ? 0.62 : 0.5);
      }
    case Feel.bossa:
      // The steady eighths (with brushes, a circle a beat), the surdo on
      // the kick, the foot on the group's last beat, and the clave on
      // the rim, its two sides turning over bar by bar.
      for (var beat = 0; beat < length; beat++) {
        if (brushes) {
          swirl(beat.toDouble(), beat == 0 ? 0.22 : 0.18, 1);
        } else {
          hit(Drum.hiHatClosed, beat.toDouble(), 0.3);
          hit(Drum.hiHatClosed, beat + 0.5, 0.2);
        }
      }
      for (final beat in groupKicks(feel, length, bar: bar, group: group)) {
        hit(Drum.kick, beat, beat == 0 ? 0.5 : 0.4);
      }
      foot(0.38);
      final threeSide = (bar + group).isEven;
      final rim = switch (length) {
        3 => threeSide ? const [0.0, 1.5] : const [1.0, 2.5],
        _ => threeSide ? const [0.0, 1.5] : const [1.0],
      };
      for (final beat in rim) {
        hit(Drum.crossStick, beat, 0.42);
      }
    case Feel.samba:
      // The bateria: the shaker in eighths, the surdo light on the front
      // of the group and heavy on its last beat, the tamborim across it.
      for (var beat = 0; beat < length; beat++) {
        hit(Drum.hiHatClosed, beat.toDouble(), 0.28);
        hit(Drum.hiHatClosed, beat + 0.5, 0.17);
      }
      hit(Drum.tomLow, 0, 0.3);
      hit(Drum.kick, 0, 0.34);
      hit(Drum.tomLow, last, 0.72, hard: true);
      hit(Drum.kick, last, 0.5);
      final tamborim = switch ((length, bar.isEven)) {
        (3, true) => const [0.5, 1.5, 2.5],
        (3, false) => const [0.5, 2.0],
        (_, true) => const [0.5, 1.5],
        _ => const [0.5, 1.0],
      };
      for (final beat in tamborim) {
        hit(Drum.crossStick, beat, 0.5, hard: true);
      }
    case Feel.calypso:
      // The bell in eighths with its accents on the 3-3-2's points (in
      // three, 1 and the "and" of 2), the kick under them, the rim on the
      // group's last beat. With brushes, a circle a beat and the accents
      // tapped on the head instead of a brushed cowbell.
      final kicks = groupKicks(feel, length, bar: bar, group: group);
      for (var eighth = 0; eighth < length * 2; eighth++) {
        final beat = eighth / 2;
        final accented = kicks.contains(beat);
        if (brushes) {
          if (eighth.isEven) swirl(beat, 0.2, 1);
          if (accented) hit(Drum.snare, beat, 0.36);
        } else {
          hits.add(
            DrumHit(
              drum: Drum.cowbell,
              beat: beat,
              velocity: (accented ? 0.34 : 0.13) * _human(random),
              hard: accented,
            ),
          );
        }
      }
      for (final beat in kicks) {
        hit(Drum.kick, beat, beat == 0 && firstOfBar ? 0.58 : 0.44);
      }
      hit(Drum.crossStick, last, brushes ? 0.42 : 0.5);
      foot(0.28);
    case Feel.secondLine:
      // The street beat on the snare: ghosts between, an accent on the
      // group's second beat (and in three on its last as well), the bass
      // drum on the front and, in three, pushing the "and" of 2.
      hit(Drum.kick, 0, firstOfBar ? 0.55 : 0.45);
      if (length == 3) hit(Drum.kick, 1.5, 0.4);
      for (var eighth = 1; eighth < length * 2; eighth++) {
        final beat = eighth / 2;
        final accent = beat == 1 || (length == 3 && beat == 2);
        hit(Drum.snare, beat, accent ? 0.58 : 0.18, hard: accent);
      }
      foot(0.32);
    case Feel.afroSix || Feel.gypsy:
      // Written beat by beat elsewhere (the bell) or not played at all.
      break;
  }
  return hits;
}
