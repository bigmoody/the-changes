// Working out what somebody played.
//
// The playing here is invented, so the answer is known: these are the
// pitches and the moments, to the sample. What is being measured is how
// much of that the app gets back.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/transcribe.dart';
import 'package:play_along/audio/wav_file.dart';
import 'package:play_along/music/tuning.dart';

const rate = 44100;

/// A line played at [bpm], one note per entry of [pitches], each lasting
/// [eighths] of a beat, starting at [from] seconds.
///
/// Each note is a plucked-sounding tone: a few harmonics, a quick attack
/// and a decay, which is what YIN is good at and what a saxophone or a
/// guitar actually is.
WavAudio line(
  List<int> pitches, {
  double bpm = 120,
  double eighths = 0.5,
  double from = 0,
  double gap = 0,
  double swing = 0,
  double seconds = 6,
}) {
  final samples = Float32List((seconds * rate).round());
  final perBeat = 60 / bpm;
  for (final (i, pitch) in pitches.indexed) {
    // Every other note late by [swing] of a beat, as a swung line is.
    final late = i.isOdd ? swing * perBeat : 0.0;
    final at = from + i * eighths * perBeat + late;
    final length = (eighths * perBeat - gap) * rate;
    final start = (at * rate).round();
    final hz = midiToHz(pitch);
    for (var s = 0; s < length && start + s < samples.length; s++) {
      final t = s / rate;
      // Decaying, and eased off at the end rather than cut, because a
      // hard cut is a click and a click reads as another note.
      final left = (length - s) / rate;
      final fade = math.exp(-t * 3) * (left < 0.02 ? left / 0.02 : 1);
      samples[start + s] +=
          (math.sin(2 * math.pi * hz * t) * 0.6 +
              math.sin(4 * math.pi * hz * t) * 0.25 +
              math.sin(6 * math.pi * hz * t) * 0.1) *
          fade *
          0.6;
    }
  }
  return WavAudio(sampleRate: rate, channels: 1, samples: samples);
}

/// A ii-V-I line in C: D E F G, A B C, sitting around middle C.
const iiVI = [62, 64, 65, 67, 69, 71, 72, 74];

void main() {
  group('the pitches', () {
    test('a line comes back note for note', () {
      final heard = hearNotes(line(iiVI));
      expect(heard.map((note) => note.pitch).toList(), iiVI);
    });

    test('low notes and high notes alike', () {
      // Two octaves apart, which is where an octave mistake would show.
      const wide = [50, 74, 52, 76, 55, 79];
      expect(hearNotes(line(wide)).map((n) => n.pitch).toList(), wide);
    });

    test('a repeated note is two notes, not one held', () {
      final heard = hearNotes(line(const [67, 67, 67, 67]));
      expect(heard, hasLength(4));
      expect(heard.map((n) => n.pitch).toSet(), {67});
    });

    test('how sure it is comes back with each note', () {
      for (final note in hearNotes(line(iiVI))) {
        expect(note.clarity, greaterThan(0.5));
      }
    });

    test('silence has nothing in it', () {
      expect(hearNotes(line(const [])), isEmpty);
    });
  });

  group('the timing', () {
    test('each note is where it was played, within a few milliseconds', () {
      final heard = hearNotes(line(iiVI, bpm: 120));
      for (final (i, note) in heard.indexed) {
        expect(
          note.at,
          closeTo(i * 0.25, 0.01),
          reason: 'note $i of an eighth-note line at 120',
        );
      }
    });

    test('a line that starts late is heard late', () {
      final heard = hearNotes(line(iiVI, from: 1.5));
      expect(heard.first.at, closeTo(1.5, 0.01));
    });

    test('notes with air between them are heard as shorter', () {
      final joined = hearNotes(line(const [62, 64, 65, 67]));
      final detached = hearNotes(line(const [62, 64, 65, 67], gap: 0.12));
      expect(
        detached.first.length,
        lessThan(joined.first.length),
        reason: 'a phrase with rests in it should come out with rests',
      );
    });
  });

  group('putting it on a grid', () {
    test('straight eighths land on the halves of the beat', () {
      final heard = hearNotes(line(iiVI, bpm: 120));
      final notes = onTheGrid(heard, bpm: 120, grid: NoteGrid.straightEighths);
      expect(notes.map((note) => note.beat).toList(), [
        0,
        0.5,
        1,
        1.5,
        2,
        2.5,
        3,
        3.5,
      ]);
      expect(notes.map((note) => note.pitch).toList(), iiVI);
    });

    test('swung eighths land two thirds through the beat', () {
      // Played as a jazz musician plays them: the off-beats late.
      final heard = hearNotes(line(iiVI, bpm: 120, swing: 1 / 6));
      final notes = onTheGrid(heard, bpm: 120, grid: NoteGrid.swungEighths);
      final places = notes.map((note) => note.beat).toList();
      expect(places[0], closeTo(0, 0.001));
      expect(places[1], closeTo(2 / 3, 0.001));
      expect(places[2], closeTo(1, 0.001));
      expect(places[3], closeTo(1 + 2 / 3, 0.001));
    });

    test('a line that comes in after the count-in starts at beat nought', () {
      final heard = hearNotes(line(iiVI, from: 2.0));
      final notes = onTheGrid(
        heard,
        bpm: 120,
        grid: NoteGrid.straightEighths,
        startSeconds: 2.0,
      );
      expect(notes.first.beat, 0);
    });

    test('nothing sensible asked for gives nothing back', () {
      expect(
        onTheGrid(const [], bpm: 120, grid: NoteGrid.swungEighths),
        isEmpty,
      );
      expect(
        onTheGrid(hearNotes(line(iiVI)), bpm: 0, grid: NoteGrid.swungEighths),
        isEmpty,
      );
    });
  });

  group('which grid it was played on', () {
    test('a swung line is read as swung', () {
      final heard = hearNotes(line(iiVI, bpm: 120, swing: 1 / 6));
      expect(bestGrid(heard, bpm: 120), NoteGrid.swungEighths);
    });

    test('a straight line is read as straight', () {
      final heard = hearNotes(line(iiVI, bpm: 120));
      expect(bestGrid(heard, bpm: 120), NoteGrid.straightEighths);
    });

    test('reading a swung line straight would be far worse', () {
      // The thing this is protecting against: every off-beat note a sixth
      // of a beat out, which on a stave is simply the wrong rhythm.
      final heard = hearNotes(line(iiVI, bpm: 120, swing: 1 / 6));
      var swung = 0.0;
      var straight = 0.0;
      for (final note in heard) {
        swung += NoteGrid.swungEighths.errorAt(note.at * 2);
        straight += NoteGrid.straightEighths.errorAt(note.at * 2);
      }
      expect(swung, lessThan(straight));
    });

    test('nothing to go on picks the jazz default rather than guessing', () {
      expect(bestGrid(const [], bpm: 120), NoteGrid.swungEighths);
    });
  });

  group('the grids themselves', () {
    test('each snaps to its own places, and to the next beat', () {
      expect(NoteGrid.straightEighths.snap(1.26), 1.5);
      expect(NoteGrid.straightEighths.snap(1.9), 2.0);
      expect(NoteGrid.swungEighths.snap(1.6), closeTo(1 + 2 / 3, 0.001));
      expect(NoteGrid.triplets.snap(1.3), closeTo(1 + 1 / 3, 0.001));
      expect(NoteGrid.sixteenths.snap(1.3), closeTo(1.25, 0.001));
    });

    test('a note already in place is not moved', () {
      expect(NoteGrid.swungEighths.errorAt(2 + 2 / 3), closeTo(0, 1e-9));
      expect(NoteGrid.straightEighths.errorAt(2.5), closeTo(0, 1e-9));
    });
  });
}
