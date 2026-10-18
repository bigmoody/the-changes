// Following a chart by ear without being told the tempo: it has to hear
// it, and to choose between the beat, half of it and twice it, which the
// attacks alone cannot tell apart, by which of them the chart's chords
// line up with.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/meter.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/practice/room_follower.dart';

import 'band_audio.dart';

void main() {
  late SampleBank bank;

  setUpAll(() async {
    bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
  });

  ({double share, double? tempo, int leaps}) follow(
    Tune tune,
    int tempo, {
    int seed = 1,
    Set<Instrument>? only,
    bool soloist = false,
    int fromBar = 0,
  }) {
    final band = renderBand(bank, tune, tempo, seed: seed, only: only);
    var audio = band.audio;
    if (soloist) {
      // The head first, as a record has it, and then the solo: over the
      // second half of the form, which is where the chorus repeats.
      audio = inARoom(
        withASoloist(
          audio,
          band.samplesPerBeat,
          (band.countInBeats + tune.totalBeats ~/ 2) * band.samplesPerBeat,
        ),
      );
    }
    final from = fromBar == 0
        ? 0
        : (band.countInBeats + fromBar * tune.beatsPerBar) *
              band.samplesPerBeat;
    final follower = RoomFollower(tune: tune);
    feed(follower.hear, Float32List.sublistView(audio, from));
    // Timed from where it started listening; held to it from twelve
    // seconds on, which leaves it time to hear the tempo and choose.
    final offset = from / 44100;
    var right = 0;
    var counted = 0;
    for (final heard in follower.heardBeats) {
      if (heard.at < 12) continue;
      // Half a beat's grace at the barline: coming in mid-song on a
      // bossa, whose off-beats are as loud as its beats, it can count on
      // the "and", which puts every bar half a beat early, and nothing in
      // the attacks says which half is the beat.
      final beats =
          (heard.at + offset) * 44100 / band.samplesPerBeat - band.countInBeats;
      final bars = {
        for (final at in [beats - 0.5, beats, beats + 0.5])
          (at.round() % tune.totalBeats) ~/ tune.beatsPerBar,
      };
      counted++;
      if (bars.contains(heard.bar)) right++;
    }
    return (
      share: counted == 0 ? 0 : right / counted,
      tempo: follower.position?.tempo,
      leaps: leaps(tune, follower.heardBeats, after: 12),
    );
  }

  void report(String what, ({double share, double? tempo, int leaps}) got) {
    // ignore: avoid_print
    print(
      '$what: ${(got.share * 100).toStringAsFixed(1)}% on the bar, '
      'heard ${got.tempo?.toStringAsFixed(1)} BPM, ${got.leaps} leaps',
    );
  }

  for (final (title, tempo) in [
    ('Autumn Leaves', 140),
    ('Blue Bossa', 150),
    ('Cherokee', 200),
    ('St. Thomas', 180),
    ('Autumn Leaves', 100),
  ]) {
    test('$title at $tempo, from the top, told nothing', () {
      final got = follow(standard(title), tempo);
      report('$title at $tempo', got);
      expect(got.tempo, closeTo(tempo, tempo * 0.03));
      expect(got.share, greaterThan(0.9));
      expect(got.leaps, 0);
    });
  }

  test('a ballad at 66, which could as well be 132', () {
    final tune = standard('Stella by Starlight')
        .withStyle(BandStyle.of(Feel.ballad));
    final got = follow(tune, 66);
    report('Ballad at 66', got);
    expect(got.tempo, closeTo(66, 3));
    expect(got.share, greaterThan(0.85));
  });

  test('a waltz at 150, whose bar is its strongest repeat', () {
    final tune = standard('Days of Wine and Roses')
        .inMeter(const Meter(3, 4))
        .withStyle(BandStyle.of(Feel.jazzWaltz));
    final got = follow(tune, 150);
    report('Waltz at 150', got);
    expect(got.tempo, closeTo(150, 5));
    expect(got.share, greaterThan(0.85));
  });

  test('switched on in the middle, told nothing', () {
    final got = follow(standard('Blue Bossa'), 150, fromBar: 9);
    report('Blue Bossa from bar 9', got);
    expect(got.tempo, closeTo(150, 5));
    expect(got.share, greaterThan(0.85));
  });

  test('the head, then a soloist, in a room, told nothing', () {
    final got = follow(standard('Autumn Leaves'), 160, soloist: true);
    report('Soloist in a room at 160', got);
    expect(got.tempo, closeTo(160, 5));
    expect(got.share, greaterThan(0.85));
    expect(got.leaps, 0);
  });

  test('Tap the Beat chooses the tempo at once', () {
    final tune = standard('Autumn Leaves');
    final band = renderBand(bank, tune, 140);
    final follower = RoomFollower(tune: tune);
    // A bar in, three taps on the beat.
    var at = 0;
    for (var beat = 0; beat < 3; beat++) {
      final tapAt = (band.countInBeats + 4 + beat) * band.samplesPerBeat;
      feed(follower.hear, Float32List.sublistView(band.audio, at, tapAt));
      at = tapAt;
      follower.tap();
    }
    expect(follower.following, isNotNull);
    feed(follower.hear, Float32List.sublistView(band.audio, at));
    expect(follower.position!.tempo, closeTo(140, 3));
  });

  test('the St. Thomas recording, told nothing', () {
    const path = 'ear_captures/heard-St-Thomas-2026-10-17T01-28-05.wav';
    final file = File(path);
    if (!file.existsSync()) return;
    final wav = readWavSamples(file.readAsBytesSync());
    final tune = standard('St. Thomas');
    final follower = RoomFollower(tune: tune);
    for (var at = 0; at < wav.length; at += 2048) {
      follower.hear(
        Float32List.sublistView(wav, at, math.min(at + 2048, wav.length)),
      );
    }
    const barOne = 13.1667;
    const bar = 60 / 180 * 4;
    var right = 0;
    var counted = 0;
    for (final heard in follower.heardBeats) {
      if (heard.at < 12 || heard.at > 27) continue;
      final actual = ((heard.at - barOne + bar / 8) / bar).floor() % 16;
      counted++;
      if (actual == heard.bar) right++;
    }
    // ignore: avoid_print
    print(
      'St. Thomas recording, told nothing: '
      '${counted == 0 ? 0 : (right / counted * 100).toStringAsFixed(1)}%, '
      'heard ${follower.position?.tempo.toStringAsFixed(1)} BPM',
    );
    expect(follower.position!.tempo, closeTo(180, 4));
    expect(right / counted, greaterThan(0.85));
  });
}
