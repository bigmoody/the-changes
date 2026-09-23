// Cutting a recording to the chart.
//
// The recordings here are counted rather than played: every frame holds
// its own number, so an assertion can say which frame of the file came
// out where. A test that only checked lengths would pass happily while
// the second chorus played the first one again.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/take_audio.dart';
import 'package:play_along/audio/wav_file.dart';
import 'package:play_along/music/recorded_take.dart';

/// A recording in which frame n holds n, so it can be followed.
///
/// The second channel holds n + 100000, so an interleaving mistake shows
/// up as a wildly wrong number rather than as a plausible one.
WavAudio counted(int frames, {int channels = 1, int rate = 100}) {
  final samples = Float32List(frames * channels);
  for (var frame = 0; frame < frames; frame++) {
    for (var channel = 0; channel < channels; channel++) {
      samples[frame * channels + channel] = frame + channel * 100000;
    }
  }
  return WavAudio(sampleRate: rate, channels: channels, samples: samples);
}

/// Two bars of four at sixty, so a beat is exactly a hundred frames and a
/// chorus is exactly eight hundred.
RecordedTake take({int bars = 2, int choruses = 3, double start = 0}) =>
    RecordedTake(
      name: 'Counted',
      files: const {TakeStem.bass: 'bass.wav'},
      bpm: 60,
      key: 5,
      bars: bars,
      choruses: choruses,
      startSeconds: start,
    );

/// Which frame of the recording came out at [frame] of the result.
int sourceAt(Float32List out, int frame, {int channels = 1, int channel = 0}) =>
    out[frame * channels + channel].round();

void main() {
  group('the count-in', () {
    test('silence on the front, as long as the count-in at its own tempo', () {
      final out = layStem(
        counted(2400),
        take: take(),
        loopStartBeat: 0,
        loopBeats: 8,
        choruses: 1,
        countInBeats: 4,
      );
      // Four beats at a hundred frames each.
      for (var frame = 0; frame < 400; frame++) {
        expect(out[frame], 0, reason: 'frame $frame should still be silent');
      }
      expect(sourceAt(out, 400), 0, reason: 'bar 1 lands right after it');
      expect(sourceAt(out, 401), 1);
    });

    test('no count-in means the recording starts at once', () {
      final out = layStem(
        counted(2400),
        take: take(),
        loopStartBeat: 0,
        loopBeats: 8,
        choruses: 1,
        countInBeats: 0,
      );
      expect(sourceAt(out, 0), 0);
    });

    test('a file whose bar 1 is late is wound past', () {
      // Twenty frames of room noise before the downbeat.
      final out = layStem(
        counted(2400),
        take: take(start: 0.2),
        loopStartBeat: 0,
        loopBeats: 8,
        choruses: 1,
        countInBeats: 0,
      );
      expect(sourceAt(out, 0), 20);
    });
  });

  group('each chorus takes the next one of the recording', () {
    test('three choruses are three different ones', () {
      final out = layStem(
        counted(2400),
        take: take(),
        loopStartBeat: 0,
        loopBeats: 8,
        choruses: 3,
        countInBeats: 0,
        crossfadeSeconds: 0,
      );
      expect(sourceAt(out, 0), 0, reason: 'the first chorus');
      expect(sourceAt(out, 800), 800, reason: 'the second, not the first');
      expect(sourceAt(out, 1600), 1600, reason: 'the third');
    });

    test('a longer run wraps back round rather than running out', () {
      final out = layStem(
        counted(2400),
        take: take(choruses: 3),
        loopStartBeat: 0,
        loopBeats: 8,
        choruses: 5,
        countInBeats: 0,
        crossfadeSeconds: 0,
      );
      expect(
        sourceAt(out, 2400),
        0,
        reason: 'the fourth goes back to the first',
      );
      expect(sourceAt(out, 3200), 800, reason: 'and the fifth to the second');
    });

    test('the whole thing is as long as the run, not as the recording', () {
      final out = layStem(
        counted(2400),
        take: take(),
        loopStartBeat: 0,
        loopBeats: 8,
        choruses: 10,
        countInBeats: 4,
      );
      expect(out.length, 400 + 800 * 10);
    });
  });

  group('a loop shorter than the form', () {
    // Twelve bars, so bars 7 and 8 are a real place in a blues.
    test('takes the same bars out of the recording', () {
      final out = layStem(
        counted(14400), // three choruses of twelve bars
        take: take(bars: 12),
        loopStartBeat: 24, // bar 7 of a form in four
        loopBeats: 8, // two bars
        choruses: 2,
        countInBeats: 0,
        crossfadeSeconds: 0,
      );
      expect(sourceAt(out, 0), 2400, reason: 'bar 7 of the first chorus');
      expect(
        sourceAt(out, 800),
        4800 + 2400,
        reason: 'bar 7 of the second chorus, not the first again',
      );
    });

    test('and is only as long as the loop', () {
      final out = layStem(
        counted(14400),
        take: take(bars: 12),
        loopStartBeat: 24,
        loopBeats: 8,
        choruses: 4,
        countInBeats: 0,
      );
      expect(out.length, 800 * 4);
    });
  });

  group('the joins', () {
    test('the fade is across the music that really follows there', () {
      // Four bar choruses, looping the first two. So at the join, what
      // the recording really plays next is its bar 3 (frame 800), and
      // what comes in is the top of its second chorus (frame 1600). Two
      // very different numbers, which is the point: a fade that is doing
      // its job lands between them, and one that is not lands on 1600.
      final out = layStem(
        counted(3200),
        take: take(bars: 4, choruses: 2),
        loopStartBeat: 0,
        loopBeats: 8,
        choruses: 2,
        countInBeats: 0,
        crossfadeSeconds: 0.05, // five frames at a hundred a second
      );
      expect(out.length, 1600);
      // A tenth of the way in it is mostly still the old chorus.
      expect(sourceAt(out, 800), closeTo(880, 1));
      // Nine tenths through, mostly the new one.
      expect(sourceAt(out, 804), closeTo(1524, 1));
      // Past the fade, purely the new one.
      expect(sourceAt(out, 805), 1605);
    });

    test('a fade never eats more than a quarter of a short loop', () {
      // One bar looped at a hundred frames a beat is four hundred frames;
      // a fade of five seconds would be far longer than the loop itself.
      final out = layStem(
        counted(2400),
        take: take(),
        loopStartBeat: 0,
        loopBeats: 4,
        choruses: 2,
        countInBeats: 0,
        crossfadeSeconds: 5,
      );
      expect(out.length, 800);
      // The frame right after the join is still mostly the new chorus,
      // which it could not be if the fade ran the whole segment.
      expect(sourceAt(out, 399), isNot(0));
    });
  });

  group('laid out a few choruses at a time', () {
    // A recording is tens of megabytes, so a long run is fed to the
    // engine in pieces. The pieces have to add up to exactly what one
    // long piece would have been, or the seams are audible and the chart
    // drifts by however much the arithmetic is out.
    Float32List whole(int choruses, {int from = 0}) => layStem(
      counted(2400),
      take: take(),
      loopStartBeat: 0,
      loopBeats: 8,
      choruses: choruses,
      countInBeats: 4,
      fromChorus: from,
    );

    test('two pieces of two are the same as one of four', () {
      final atOnce = whole(4);
      final first = whole(2);
      final second = whole(2, from: 2);
      expect(first.length + second.length, atOnce.length);
      for (var frame = 0; frame < first.length; frame++) {
        expect(
          first[frame],
          atOnce[frame],
          reason: 'frame $frame of the first',
        );
      }
      for (var frame = 0; frame < second.length; frame++) {
        expect(
          second[frame],
          atOnce[first.length + frame],
          reason: 'frame $frame of the second',
        );
      }
    });

    test('only the piece that starts the run carries the count-in', () {
      expect(whole(1).length, 400 + 800);
      expect(whole(1, from: 1).length, 800, reason: 'no silence a second time');
    });

    test('a later piece still takes the right chorus of the recording', () {
      final later = whole(1, from: 4);
      // Chorus 4 of the run, from a recording of three, is its second.
      expect(sourceAt(later, 700), 800 + 700);
    });
  });

  group('stereo', () {
    test('the channels stay where they belong', () {
      final out = layStem(
        counted(2400, channels: 2),
        take: take(),
        loopStartBeat: 0,
        loopBeats: 8,
        choruses: 1,
        countInBeats: 4,
        crossfadeSeconds: 0,
      );
      expect(out.length, (400 + 800) * 2);
      expect(sourceAt(out, 400, channels: 2, channel: 0), 0);
      expect(sourceAt(out, 400, channels: 2, channel: 1), 100000);
      expect(sourceAt(out, 500, channels: 2, channel: 0), 100);
      expect(sourceAt(out, 500, channels: 2, channel: 1), 100100);
    });
  });

  group('recordings that are not what they claim', () {
    test('a file that stops early plays out as silence, not a crash', () {
      final out = layStem(
        counted(900), // barely more than one chorus
        take: take(choruses: 3),
        loopStartBeat: 0,
        loopBeats: 8,
        choruses: 3,
        countInBeats: 0,
        crossfadeSeconds: 0,
      );
      expect(out.length, 2400);
      expect(sourceAt(out, 0), 0, reason: 'what is there still plays');
      expect(out[2000], 0, reason: 'what is not there is silence');
    });

    test('and it can be told that it is short', () {
      // Three choruses of two bars at sixty is ninety-six seconds.
      expect(take().seconds, closeTo(24, 0.001));
      expect(takeIsShort(counted(900), take()), isTrue);
      expect(takeIsShort(counted(2400), take()), isFalse);
    });

    test('nothing sensible asked for gives nothing back', () {
      final nothing = counted(2400);
      for (final out in [
        layStem(
          nothing,
          take: take(),
          loopStartBeat: 0,
          loopBeats: 0,
          choruses: 1,
          countInBeats: 0,
        ),
        layStem(
          nothing,
          take: take(),
          loopStartBeat: 0,
          loopBeats: 8,
          choruses: 0,
          countInBeats: 0,
        ),
      ]) {
        expect(out.length, 0);
      }
    });
  });

  group('handing it to the engine', () {
    test('full scale and back', () {
      final pcm = pcm16(Float32List.fromList([0, 1, -1, 0.5]));
      final view = ByteData.sublistView(pcm);
      expect(pcm.length, 8);
      expect(view.getInt16(0, Endian.little), 0);
      expect(view.getInt16(2, Endian.little), 32767);
      expect(view.getInt16(4, Endian.little), -32767);
      expect(view.getInt16(6, Endian.little), closeTo(16384, 1));
    });

    test('anything over full scale is held there rather than wrapping', () {
      final view = ByteData.sublistView(pcm16(Float32List.fromList([4, -4])));
      expect(view.getInt16(0, Endian.little), 32767);
      expect(view.getInt16(2, Endian.little), -32767);
    });
  });
}
