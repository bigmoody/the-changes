// Following a chart by ear, tested on the app's own band.
//
// The band is rendered with its real samples, mixed down to one track the
// way a microphone would hear it, and fed to the follower a few
// milliseconds at a time. Where the band actually was at every moment is
// known exactly, so how often the follower agrees is a number.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/meter.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/practice/chart_follower.dart';

import 'band_audio.dart';

void main() {
  late SampleBank bank;

  setUpAll(() async {
    bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
  });

  for (final (title, tempo) in [
    ('Autumn Leaves', 140),
    ('Blue Bossa', 150),
    ('Cherokee', 200),
  ]) {
    test('follows $title from the top, at the tempo it was told', () {
      final tune = standard(title);
      final band = renderBand(bank, tune, tempo);
      final follower = ChartFollower(tune: tune, tempo: tempo.toDouble());
      feed(follower.hear, band.audio);
      final share = onTheBar(
        follower.tune,
        follower.heardBeats,
        band,
        settle: 4,
      );
      // ignore: avoid_print
      print(
        '$title: ${(share * 100).toStringAsFixed(1)}% on the bar, '
        'tempo heard ${follower.position?.tempo.toStringAsFixed(1)}',
      );
      expect(share, greaterThan(0.9));
      expect(
        leaps(follower.tune, follower.heardBeats),
        0,
        reason: 'it goes forward, never leaps',
      );
      // And it knows it is hearing music, or the stage would mark nothing.
      final heard = follower.heardBeats.where((beat) => beat.at > 6);
      final musical = heard.where((beat) => beat.hearsMusic).length;
      expect(musical / heard.length, greaterThan(0.9));
    });
  }

  test('finds the tempo when the band is not at the one it was told', () {
    // The record is faster than the chart says, which records usually
    // are: the follower is told 160 and the band plays 176.
    final tune = standard('Autumn Leaves');
    final band = renderBand(bank, tune, 176);
    final follower = ChartFollower(tune: tune, tempo: 160);
    feed(follower.hear, band.audio);
    final share = onTheBar(follower.tune, follower.heardBeats, band, settle: 8);
    // ignore: avoid_print
    print(
      'Told 160, played 176: ${(share * 100).toStringAsFixed(1)}%, '
      'tempo heard ${follower.position?.tempo.toStringAsFixed(1)}',
    );
    expect(follower.position!.tempo, closeTo(176, 3));
    expect(share, greaterThan(0.85));
  });

  test('finds its place when it starts in the middle', () {
    // Nobody told it where: it comes in at bar 9 of Blue Bossa knowing
    // nothing, and has only the chords to go on.
    final tune = standard('Blue Bossa');
    final band = renderBand(bank, tune, 150);
    final follower = ChartFollower(tune: tune, tempo: 150, fromTheTop: false);
    final from =
        (band.countInBeats + 8 * tune.beatsPerBar) * band.samplesPerBeat;
    feed(follower.hear, Float32List.sublistView(band.audio, from));
    // The beats it reports are timed from where it started listening.
    final offset = from / 44100;
    var right = 0;
    var counted = 0;
    for (final heard in follower.heardBeats) {
      // Two times round the eight bars it can tell apart before it is
      // held to it.
      if (heard.at < 16 * 60 / 150 * 4 / 4 * 2) continue;
      final actual =
          (((heard.at + offset) * 44100 / band.samplesPerBeat).round() -
              band.countInBeats) %
          tune.totalBeats;
      counted++;
      if (actual ~/ 4 == heard.bar) right++;
    }
    final share = right / counted;
    // ignore: avoid_print
    print('From the middle: ${(share * 100).toStringAsFixed(1)}%');
    expect(share, greaterThan(0.85));
  });

  for (final (loudness, needs) in [(0.1, 0.85), (0.2, 0.0)]) {
    test('keeps its place with a noisy room over the band ($loudness)', () {
      final tune = standard('Autumn Leaves');
      final band = renderBand(bank, tune, 140);
      final random = math.Random(7);
      var peak = 0.0;
      for (final sample in band.audio) {
        peak = math.max(peak, sample.abs());
      }
      final noisy = Float32List(band.audio.length);
      for (var i = 0; i < noisy.length; i++) {
        // Hiss at a tenth of the band's peak is a loud room: a fan, a
        // crowd talking. A fifth is as loud as the band itself, and is
        // only here to say how it does, not to hold it to anything.
        noisy[i] =
            band.audio[i] + (random.nextDouble() * 2 - 1) * peak * loudness;
      }
      final follower = ChartFollower(tune: tune, tempo: 140);
      feed(follower.hear, noisy);
      final share = onTheBar(
        follower.tune,
        follower.heardBeats,
        band,
        settle: 4,
      );
      // ignore: avoid_print
      print('Noise at $loudness: ${(share * 100).toStringAsFixed(1)}%');
      expect(share, greaterThan(needs));
    });
  }

  // Harder for the count: a slow ballad on brushes has soft attacks and
  // few of them, and a waltz counts three. Each played twice, by two
  // different performances, so nothing here is tuned to one take.
  for (final (name, tune, tempo, needs) in [
    (
      'a brushed ballad',
      standard('Stella by Starlight').withStyle(BandStyle.of(Feel.ballad)),
      66,
      0.85,
    ),
    (
      'a jazz waltz',
      standard('Days of Wine and Roses')
          .inMeter(const Meter(3, 4))
          .withStyle(BandStyle.of(Feel.jazzWaltz)),
      150,
      0.85,
    ),
  ]) {
    for (final seed in [2, 3]) {
      test('follows $name (performance $seed)', () {
        final band = renderBand(bank, tune, tempo, seed: seed);
        final follower = ChartFollower(tune: tune, tempo: tempo.toDouble());
        feed(follower.hear, band.audio);
        final share = onTheBar(
          follower.tune,
          follower.heardBeats,
          band,
          settle: 6,
        );
        // ignore: avoid_print
        print(
          '$name, performance $seed: '
          '${(share * 100).toStringAsFixed(1)}%, tempo heard '
          '${follower.position?.tempo.toStringAsFixed(1)}',
        );
        expect(share, greaterThan(needs));
        final heard = follower.heardBeats.where((beat) => beat.at > 6);
        final musical = heard.where((beat) => beat.hearsMusic).length;
        expect(musical / heard.length, greaterThan(0.9));
      });
    }
  }

  test('nor is a noisy one with no band in it', () {
    // Hiss and knocks at the level of a room people are talking in, with
    // nothing playing: it stands out, it has notes in it, and it has no
    // beat.
    final tune = standard('Autumn Leaves');
    for (final level in [0.01, 0.05]) {
      final random = math.Random(5);
      final room = Float32List(44100 * 30);
      for (var i = 0; i < room.length; i++) {
        room[i] = (random.nextDouble() * 2 - 1) * level;
      }
      for (
        var at = 4410;
        at < room.length - 3000;
        at += 9000 + random.nextInt(20000)
      ) {
        for (var i = 0; i < 2000; i++) {
          room[at + i] += math.sin(i * 0.3) * level * 8 * math.exp(-i / 300);
        }
      }
      final follower = ChartFollower(tune: tune, tempo: 140);
      feed(follower.hear, room);
      expect(
        follower.heardBeats.where((beat) => beat.hearsMusic),
        isEmpty,
        reason: 'noise at $level',
      );
    }
  });

  test('switched on mid-song, it finds its place by itself', () {
    // The usual way it will be used: the band is already playing when
    // somebody turns the ear on. It starts out thinking it is at the top,
    // which is wrong, and the chords have to talk it out of that.
    final tune = standard('Blue Bossa');
    final band = renderBand(bank, tune, 150);
    // Not told it is at the top: it looks, and once sure it counts on.
    final follower = ChartFollower(tune: tune, tempo: 150, fromTheTop: false);
    final from =
        (band.countInBeats + 20 * tune.beatsPerBar + 2) * band.samplesPerBeat;
    feed(follower.hear, Float32List.sublistView(band.audio, from));
    final offset = from / 44100;
    var right = 0;
    var counted = 0;
    for (final heard in follower.heardBeats) {
      if (heard.at < 20) continue;
      final actual =
          (((heard.at + offset) * 44100 / band.samplesPerBeat).round() -
              band.countInBeats) %
          tune.totalBeats;
      counted++;
      if (actual ~/ 4 == heard.bar) right++;
    }
    final share = right / counted;
    // ignore: avoid_print
    print('Switched on mid-song: ${(share * 100).toStringAsFixed(1)}%');
    expect(share, greaterThan(0.85));
  });

  test('a tap on a bar puts it there, and it counts on from it', () {
    // Turned on in the middle, at bar 17, and told so with a tap as the
    // bar comes round.
    final tune = standard('Autumn Leaves');
    final band = renderBand(bank, tune, 140);
    final follower = ChartFollower(tune: tune, tempo: 140);
    final bar17 =
        (band.countInBeats + 16 * tune.beatsPerBar) * band.samplesPerBeat;
    // A little of bar 16 heard first, as it would be.
    final from = bar17 - 2 * band.samplesPerBeat;
    final tapAt = bar17 + band.samplesPerBeat ~/ 10;
    feed(follower.hear, Float32List.sublistView(band.audio, from, tapAt));
    follower.placeAt(16 * tune.beatsPerBar);
    expect(follower.position!.bar, 16);
    feed(follower.hear, Float32List.sublistView(band.audio, tapAt));
    final offset = from / 44100;
    var right = 0;
    var counted = 0;
    for (final heard in follower.heardBeats) {
      if (heard.at + offset < tapAt / 44100 + 1) continue;
      final actual =
          (((heard.at + offset) * 44100 / band.samplesPerBeat).round() -
              band.countInBeats) %
          tune.totalBeats;
      counted++;
      if (actual ~/ 4 == heard.bar) right++;
    }
    // ignore: avoid_print
    print(
      'From a tap at bar 17: ${(right / counted * 100).toStringAsFixed(1)}%',
    );
    expect(right / counted, greaterThan(0.9));
    expect(
      leaps(
        follower.tune,
        follower.heardBeats,
        after: (tapAt - from) / 44100 + 1,
      ),
      0,
    );
  });

  test('a wrong tap is believed: it counts on from where it was told', () {
    // Nothing it hears moves it a section away, not even to put right a
    // tap; another tap does that. What it may do is settle the beat.
    final tune = standard('Autumn Leaves');
    final band = renderBand(bank, tune, 140);
    final follower = ChartFollower(tune: tune, tempo: 140);
    final twoBars = (band.countInBeats + 8) * band.samplesPerBeat;
    feed(follower.hear, Float32List.sublistView(band.audio, 0, twoBars));
    follower.placeAt(16 * tune.beatsPerBar);
    feed(follower.hear, Float32List.sublistView(band.audio, twoBars));
    expect(
      leaps(follower.tune, follower.heardBeats, after: twoBars / 44100 + 1),
      0,
    );
  });

  test('a quiet room is not taken for a band', () {
    // What the simulator's microphone hears, and a stand between tunes:
    // a faint hiss with the odd click in it, which stands out from the
    // silence round it but is not music.
    final tune = standard('Autumn Leaves');
    final random = math.Random(3);
    final room = Float32List(44100 * 20);
    for (var i = 0; i < room.length; i++) {
      room[i] = (random.nextDouble() * 2 - 1) * 0.0005;
    }
    for (var at = 44100; at < room.length; at += 44100 * 7 ~/ 10) {
      for (var i = 0; i < 200; i++) {
        room[at + i] += (random.nextDouble() * 2 - 1) * 0.002;
      }
    }
    final follower = ChartFollower(tune: tune, tempo: 140);
    feed(follower.hear, room);
    expect(follower.heardBeats.where((beat) => beat.hearsMusic), isEmpty);
  });

  test('when the band stops, it holds rather than counting on', () {
    final tune = standard('Autumn Leaves');
    final band = renderBand(bank, tune, 140);
    final follower = ChartFollower(tune: tune, tempo: 140);
    final eightBars = (band.countInBeats + 32) * band.samplesPerBeat;
    feed(follower.hear, Float32List.sublistView(band.audio, 0, eightBars));
    final before = follower.heardBeats.length;
    // Ten seconds of nothing.
    feed(follower.hear, Float32List(44100 * 10));
    // Two bars of beats counted into the silence before it gives up, and
    // a little ring from the last chord: not twenty-odd.
    expect(follower.heardBeats.length - before, lessThan(12));
  });

  // A record is whatever speed it is, and the chart's tempo is whatever
  // somebody last practised it at: half as fast again, or two thirds. It
  // says it hears a groove it is not counting, and a few taps along with
  // the record put it right.
  for (final (told, played) in [(100, 150), (200, 130)]) {
    test('told $told, the record at $played: tapping along puts it right', () {
      final tune = standard('Autumn Leaves');
      final band = renderBand(bank, tune, played);
      final follower = ChartFollower(tune: tune, tempo: told.toDouble());
      // Eight bars of not keeping up.
      final eightBars = (band.countInBeats + 32) * band.samplesPerBeat;
      feed(follower.hear, Float32List.sublistView(band.audio, 0, eightBars));
      // ignore: avoid_print
      print(
        'Told $told, played $played: hears a groove at '
        '${follower.roomTempo?.toStringAsFixed(1)}',
      );
      final early = follower.heardBeats.where((b) => b.at > 6).toList();
      // ignore: avoid_print
      print(
        '  before tapping: tempo ${follower.position?.tempo.toStringAsFixed(1)}, '
        'music ${early.where((b) => b.hearsMusic).length}/${early.length}',
      );
      // It never claims to be following at the wrong tempo. It may or may
      // not be able to say what the room's tempo is (two beats at 130
      // and three at 195 line up, and so do others), which is why the
      // screen asks for taps either way.
      expect(early.where((b) => b.hearsMusic), isEmpty);
      // Four taps on the beat, a little late as a hand is.
      var at = eightBars;
      for (var beat = 0; beat < 4; beat++) {
        final tapAt =
            eightBars + beat * band.samplesPerBeat + band.samplesPerBeat ~/ 10;
        feed(follower.hear, Float32List.sublistView(band.audio, at, tapAt));
        at = tapAt;
        follower.tap();
      }
      feed(follower.hear, Float32List.sublistView(band.audio, at));
      expect(follower.position!.tempo, closeTo(played, 4));
      final share = onTheBar(
        follower.tune,
        follower.heardBeats,
        band,
        settle: (eightBars + 12 * band.samplesPerBeat) / 44100 + 8,
      );
      // ignore: avoid_print
      print('  after tapping: ${(share * 100).toStringAsFixed(1)}%');
      expect(share, greaterThan(0.85));
    });
  }

  // Under a solo the piano often lays out and it is bass and drums; in a
  // drum solo, or trading fours, it is the drums alone. Eight bars of the
  // whole band, then the rest without.
  for (final (name, who, needs) in [
    ('bass and drums', {Instrument.bass, Instrument.drums}, 0.9),
    ('the drums alone', {Instrument.drums}, 0.85),
  ]) {
    for (final title in ['Autumn Leaves', 'Blue Bossa', 'Cherokee']) {
      test('keeps its place through $name ($title)', () {
        final tune = standard(title);
        final whole = renderBand(bank, tune, 160);
        final without = renderBand(bank, tune, 160, only: who);
        final split = (whole.countInBeats + 32) * whole.samplesPerBeat;
        final track = Float32List(whole.audio.length)
          ..setRange(0, split, whole.audio)
          ..setRange(split, whole.audio.length, without.audio, split);
        final follower = ChartFollower(tune: tune, tempo: 160);
        feed(follower.hear, track);
        final share = onTheBar(
          follower.tune,
          follower.heardBeats,
          whole,
          settle: (split + 4 * whole.samplesPerBeat) / 44100,
        );
        // ignore: avoid_print
        print('$title, $name: ${(share * 100).toStringAsFixed(1)}%');
        expect(share, greaterThan(needs));
      });
    }
  }

  // A real record: a soloist playing all over the changes, the band
  // under them, a room round it all. It must keep its place by counting
  // and never leap to some other section that shares the chords.
  for (final title in ['Autumn Leaves', 'Cherokee', 'Blue Bossa']) {
    test('keeps its place under a soloist, in a room ($title)', () {
      final tune = standard(title);
      final band = renderBand(bank, tune, 160);
      final record = inARoom(
        withASoloist(
          band.audio,
          band.samplesPerBeat,
          band.countInBeats * band.samplesPerBeat,
        ),
      );
      final follower = ChartFollower(tune: tune, tempo: 160);
      feed(follower.hear, record);
      final share = onTheBar(
        follower.tune,
        follower.heardBeats,
        band,
        settle: 4,
      );
      // ignore: avoid_print
      print(
        '$title, soloist in a room: ${(share * 100).toStringAsFixed(1)}%, '
        '${leaps(follower.tune, follower.heardBeats)} leaps',
      );
      expect(leaps(follower.tune, follower.heardBeats), 0);
      expect(share, greaterThan(0.9));
    });
  }
}
