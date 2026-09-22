// Naming a chord by ear.
//
// The test signal isn't synthesised: it's the app's own recorded guitar,
// strummed through the shapes the app itself works out. So what's measured
// here is a real guitar going into the same code the microphone feeds.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/chord_ear.dart';
import 'package:play_along/audio/fft.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/chord_match.dart';
import 'package:play_along/music/guitar_chord_shapes.dart';
import 'package:play_along/music/guitar_voicing.dart';

const _rate = 44100;
const _size = 16384;

Future<SampleBank> _bank() =>
    SampleBank.load((path) async => File('assets/sounds/$path').readAsBytes());

/// A strum of [shape] on the recorded guitar, as the microphone would hear
/// it: a third of a second from just after the pick crosses the strings.
Float32List _strum(SampleBank bank, GuitarVoicing shape) {
  final wav = renderSnippet(room: false, bank, [
    for (final (i, pitch) in shape.pitches.indexed)
      (
        pitch: pitch,
        start: i * 0.03,
        length: 2.5 - i * 0.03,
        velocity: 0.8,
        bass: false,
      ),
  ], guitar: true);
  final pcm = decodeWav(wav);
  final from = (0.35 * _rate).round();
  final window = Float32List(_size);
  for (var i = 0; i < _size && from + i < pcm.length; i++) {
    window[i] = pcm[from + i] / 32768;
  }
  return window;
}

/// The same chord played on the piano, notes struck together.
Float32List _keys(SampleBank bank, List<int> pitches) {
  final wav = renderSnippet(room: false, bank, [
    for (final pitch in pitches)
      (pitch: pitch, start: 0.0, length: 3.0, velocity: 0.8, bass: false),
  ]);
  final pcm = decodeWav(wav);
  final from = (0.3 * _rate).round();
  final window = Float32List(_size);
  for (var i = 0; i < _size && from + i < pcm.length; i++) {
    window[i] = pcm[from + i] / 32768;
  }
  return window;
}

/// [chord] in root position, closed up, with its root at [root].
List<int> _closed(Chord chord, int root) {
  final out = <int>[];
  var last = root - 1;
  for (final pitchClass in chord.pitchClasses) {
    var pitch = root + ((pitchClass - chord.root) % 12);
    while (pitch <= last) {
      pitch += 12;
    }
    out.add(pitch);
    last = pitch;
  }
  return out;
}

/// Whether [guess] is the same chord as [chord], however it's spelled:
/// Eø7 and Em7♭5 are one chord with two symbols.
bool _isSame(ChordGuess guess, Chord chord) {
  final wanted = chord.pitchClasses.toSet();
  final got = guess.chord.pitchClasses.toSet();
  return guess.chord.root == chord.root &&
      got.length == wanted.length &&
      got.containsAll(wanted);
}

void main() {
  group('the transform', () {
    test('finds a sine wave where it is', () {
      final samples = Float32List(_size);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = math.sin(2 * math.pi * 440 * i / _rate);
      }
      final spectrum = magnitudeSpectrum(samples, size: _size);
      var peak = 0;
      for (var i = 1; i < spectrum.length; i++) {
        if (spectrum[i] > spectrum[peak]) peak = i;
      }
      expect(peak * _rate / _size, closeTo(440, 4));
    });

    test('hears two notes at once as two peaks', () {
      final samples = Float32List(_size);
      for (var i = 0; i < samples.length; i++) {
        final t = i / _rate;
        samples[i] =
            math.sin(2 * math.pi * 440 * t) +
            0.7 * math.sin(2 * math.pi * 659.25 * t);
      }
      final spectrum = magnitudeSpectrum(samples, size: _size);
      double at(double hz) => spectrum[(hz * _size / _rate).round()];
      expect(at(440), greaterThan(at(550) * 20));
      expect(at(659.25), greaterThan(at(550) * 20));
    });

    test('silence is silent', () {
      final spectrum = magnitudeSpectrum(Float32List(_size), size: _size);
      expect(spectrum.reduce(math.max), 0);
    });
  });

  group('picking the notes out', () {
    test('a three-note chord of pure tones', () {
      final samples = Float32List(_size);
      for (final hz in [261.63, 329.63, 392.0]) {
        for (var i = 0; i < samples.length; i++) {
          samples[i] += math.sin(2 * math.pi * hz * i / _rate) * 0.3;
        }
      }
      final heard = listenForNotes(samples, sampleRate: _rate, size: _size);
      expect(heard.pitches.map((p) => p % 12).toSet(), {0, 4, 7});
      expect(heard.bass, 60, reason: 'middle C is the lowest');
    });

    test('nothing at all is nothing, not a guess', () {
      final heard = listenForNotes(
        Float32List(_size),
        sampleRate: _rate,
        size: _size,
      );
      expect(heard.isEmpty, isTrue);
      expect(heard.pitches, isEmpty);
      expect(heard.bass, isNull);
      expect(namesFor(heard.chroma), isEmpty);
    });
  });

  group('naming what was played', () {
    test('a real strummed guitar, chord by chord', () async {
      final bank = await _bank();
      const symbols = [
        'C', 'G', 'D', 'A', 'E', 'F', 'Bb', 'Eb', 'Ab', 'Db', 'F#', 'B', //
        'Am', 'Em', 'Dm', 'Bm', 'F#m', 'Cm', 'Gm',
        'C7', 'G7', 'A7', 'E7', 'D7', 'B7', 'F7', 'Bb7',
        'Cm7', 'Dm7', 'Em7', 'Am7', 'Gm7', 'Bm7',
        'C^7', 'F^7', 'G^7', 'A^7', 'Bb^7',
        'Bh7', 'Em7b5', 'Ah7', 'Co7', 'Do7',
        'C6', 'G6', 'Cm6', 'Csus4', 'G7sus4',
        'C9', 'G13', 'E7#9', 'A7b9', 'C+',
      ];
      var first = 0;
      var topThree = 0;
      var total = 0;
      final wrong = <String>[];
      for (final symbol in symbols) {
        final chord = Chord.parse(symbol);
        for (final shape in allGuitarShapes(chord).take(3)) {
          total++;
          final heard = listenForNotes(
            _strum(bank, shape),
            sampleRate: _rate,
            size: _size,
          );
          final guesses = namesFor(
            heard.chroma,
            bass: heard.bass == null ? null : heard.bass! % 12,
          );
          if (guesses.isNotEmpty && _isSame(guesses.first, chord)) {
            first++;
            topThree++;
          } else if (guesses.take(3).any((g) => _isSame(g, chord))) {
            topThree++;
          } else {
            wrong.add(
              '${chord.display} heard as '
              '${guesses.isEmpty ? 'nothing' : guesses.first.display}',
            );
          }
        }
      }
      debugPrint(
        'named right first: $first/$total, in three: $topThree/$total',
      );
      for (final miss in wrong) {
        debugPrint('  $miss');
      }
      // Measured at 146 and 152 of 159 when this was written. The margin is
      // for the shapes changing, not for the ear getting worse.
      expect(first / total, greaterThan(0.86));
      expect(topThree / total, greaterThan(0.92));
    });

    test('it never simply gives up on a chord it can hear', () async {
      final bank = await _bank();
      for (final symbol in ['C', 'Am7', 'G7', 'F^7']) {
        final chord = Chord.parse(symbol);
        final heard = listenForNotes(
          _strum(bank, allGuitarShapes(chord).first),
          sampleRate: _rate,
          size: _size,
        );
        expect(heard.pitches.length, greaterThanOrEqualTo(3), reason: symbol);
        expect(namesFor(heard.chroma), isNotEmpty, reason: symbol);
      }
    });
  });

  group('telling chords of the same notes apart', () {
    // C6 and Am7 are both C, E, G and A. Only the bass says which.
    List<double> chromaOf(Set<int> pitchClasses) => [
      for (var i = 0; i < 12; i++) pitchClasses.contains(i) ? 0.25 : 0.0,
    ];

    test('the note underneath decides', () {
      const notes = {0, 4, 7, 9}; // C E G A
      expect(namesFor(chromaOf(notes), bass: 0).first.chord.display, 'C6');
      expect(namesFor(chromaOf(notes), bass: 9).first.chord.display, 'Am7');
    });

    test('a plain triad is read as a triad, not something rarer', () {
      final guess = namesFor(chromaOf({0, 4, 7}), bass: 0).first;
      expect(guess.chord.display, 'C');
      expect(guess.bass, isNull);
    });

    test('an inversion keeps the chord and says what is underneath', () {
      final guess = namesFor(chromaOf({0, 4, 7}), bass: 4).first;
      expect(guess.chord.display, 'C');
      expect(guess.bass, 'E');
      expect(guess.display, 'C/E');
    });

    test('the 7th is heard when it is there', () {
      expect(
        namesFor(chromaOf({0, 4, 7, 10}), bass: 0).first.chord.display,
        'C7',
      );
      expect(
        namesFor(chromaOf({0, 4, 7, 11}), bass: 0).first.chord.display,
        'CΔ7',
      );
      expect(
        namesFor(chromaOf({0, 3, 7, 10}), bass: 0).first.chord.display,
        'Cm7',
      );
    });

    test('one note on its own is not a chord', () {
      expect(namesFor(chromaOf({0})), isEmpty);
    });
  });

  group('on the piano', () {
    // It was tuned on the guitar, but nothing in it is about guitars: it
    // looks for notes by their harmonics, which is how any string sounds.
    const symbols = [
      'C', 'G', 'F', 'Bb', 'Eb', 'A', 'E', 'D', //
      'Am', 'Dm', 'Em', 'Cm', 'F#m',
      'C7', 'G7', 'F7', 'Bb7', 'A7', 'E7',
      'Dm7', 'Am7', 'Em7', 'Cm7', 'Gm7',
      'C^7', 'F^7', 'Bb^7', 'G^7',
      'Bh7', 'Ah7', 'Co7', 'C6', 'Cm6', 'Csus4', 'C9', 'G13', 'C+',
    ];

    ({int first, int three}) score(SampleBank bank, int octave) {
      var first = 0;
      var three = 0;
      for (final symbol in symbols) {
        final chord = Chord.parse(symbol);
        final heard = listenForNotes(
          _keys(bank, _closed(chord, octave + chord.root)),
          sampleRate: _rate,
          size: _size,
        );
        final guesses = namesFor(
          heard.chroma,
          bass: heard.bass == null ? null : heard.bass! % 12,
        );
        if (guesses.isNotEmpty && _isSame(guesses.first, chord)) first++;
        if (guesses.take(3).any((g) => _isSame(g, chord))) three++;
      }
      return (first: first, three: three);
    }

    test('chords played down where a pianist plays them', () async {
      final bank = await _bank();
      final low = score(bank, 48); // roots from C3
      debugPrint('piano from C3: ${low.first}/37 first, ${low.three}/37 three');
      // Measured at 36 and 36 of 37.
      expect(low.first, greaterThanOrEqualTo(33));
      expect(low.three, greaterThanOrEqualTo(34));
    });

    test('and up around middle C, where the top three carry it', () async {
      final bank = await _bank();
      final middle = score(bank, 60);
      debugPrint(
        'piano from C4: ${middle.first}/37 first, ${middle.three}/37 three',
      );
      // Measured at 23 and 34 of 37: up here a seventh is often heard as
      // the triad underneath it, which is what the alternatives are for.
      expect(middle.first, greaterThanOrEqualTo(20));
      expect(middle.three, greaterThanOrEqualTo(31));
    });

    test('a two-handed voicing, root in the left hand', () async {
      final bank = await _bank();
      for (final (name, pitches, want) in [
        ('Dm7', [38, 60, 65, 69], 'Dm7'),
        ('Dm9', [38, 60, 64, 65, 69], 'Dm9'),
        ('Fm7', [41, 60, 63, 68], 'Fm7'),
        ('CΔ7', [36, 59, 64, 67], 'CΔ7'),
      ]) {
        final heard = listenForNotes(
          _keys(bank, pitches),
          sampleRate: _rate,
          size: _size,
        );
        final guesses = namesFor(
          heard.chroma,
          bass: heard.bass == null ? null : heard.bass! % 12,
        );
        expect(guesses, isNotEmpty, reason: name);
        expect(guesses.first.chord.display, want, reason: name);
      }
    });
  });

  test('the shape shown is the one nearest what was played', () {
    final chord = Chord.parse('C');
    // The open C: x 3 2 0 1 0.
    final open = shapeLike(chord, [48, 52, 55, 60, 64]);
    expect(open?.frets, [null, 3, 2, 0, 1, 0]);
    // The same chord played up at the eighth fret comes back as a barre,
    // not as the open shape.
    final barre = shapeLike(chord, [60, 67, 72, 76, 79]);
    expect(barre, isNotNull);
    expect(barre!.position, greaterThan(2));
  });
}
