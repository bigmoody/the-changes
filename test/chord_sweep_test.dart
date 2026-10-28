// The chord identifier on every chord it knows, in all twelve keys, in the
// first three guitar shapes it suggests for each: 864 strums.
//
// Twice. Once clean, every string ringing on. And once as the player's own
// guitar sounds through an iPad, measured off two screen recordings of it:
// the bass string rings on, the others die in half a second to a second, a
// note fretted on the G string in a tenth to a fifth of a second, now and
// then a string hardly sounds at all, each string at its own loudness, the
// low ones the loudest, and all of it through a microphone rolled off
// below 150 Hz with a little hiss. Read every 60 ms, as the app reads it,
// through the ChordReader, and judged by what is on screen at the end.
//
// Right is the chord's own name over the right bass; fair is another name
// for exactly the notes played (some shapes leave out what their name
// promises: a 7alt shape that is a +7). Measured when this was written:
// clean 823 right and 18 fair of 864, as a guitar on an iPad sounds 685
// and 13, from 815 and 591 before the reading was built for it. The floors
// are below those so that a change to the shapes can move them a little,
// and so that the ear getting worse cannot.
@Tags(['sweep'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/chord_ear.dart';
import 'package:play_along/audio/chord_reader.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/guitar_chord_shapes.dart';

const _rate = 44100;
const _size = 16384;
const _hop = 2646; // 60 ms
const _roots = [
  'C',
  'Db',
  'D',
  'Eb',
  'E',
  'F',
  'F#',
  'G',
  'Ab',
  'A',
  'Bb',
  'B',
];

void main() {
  late SampleBank bank;
  final notes = <int, Float32List>{};
  setUpAll(() async {
    bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
  });

  Float32List note(int pitch) => notes.putIfAbsent(pitch, () {
    final wav = renderSnippet(room: false, bank, [
      (pitch: pitch, start: 0.0, length: 3.0, velocity: 0.8, bass: false),
    ], guitar: true);
    return Float32List.fromList([for (final s in decodeWav(wav)) s / 32768]);
  });

  /// Right and fair, of every strum, [asOnAnIPad] or clean.
  ({int right, int fair, int total}) sweep({required bool asOnAnIPad}) {
    final random = math.Random(7);
    var right = 0;
    var fair = 0;
    var total = 0;
    for (final quality in chordQualities) {
      for (final root in _roots) {
        final chord = Chord.parse('$root${quality.symbols.first}');
        for (final shape in allGuitarShapes(chord).take(3)) {
          total++;
          final pitches = shape.pitches;
          final lowest = pitches.reduce(math.min);
          final strings = [
            for (final (string, fret) in shape.frets.indexed)
              if (fret != null) string,
          ];
          final weak = asOnAnIPad && random.nextDouble() < 0.2
              ? random.nextInt(pitches.length)
              : -1;
          final mix = Float32List((2.6 * _rate).round());
          for (final (i, pitch) in pitches.indexed) {
            final sound = note(pitch);
            final start = (i * 0.025 * _rate).round();
            final fretOnG = strings[i] == 3 && shape.frets[3] != 0;
            final gain = !asOnAnIPad
                ? 1.0
                : i == weak
                ? 0.05 + random.nextDouble() * 0.15
                : pitch == lowest
                ? 1.0 + random.nextDouble() * 0.6
                : 0.6 + random.nextDouble() * 0.8;
            final dies = !asOnAnIPad
                ? 99.0
                : pitch == lowest
                ? 1.5 + random.nextDouble() * 2.5
                : fretOnG
                ? 0.1 + random.nextDouble() * 0.15
                : 0.4 + random.nextDouble() * 0.6;
            for (var k = 0; k + start < mix.length && k < sound.length; k++) {
              mix[start + k] += sound[k] * gain * math.exp(-k / _rate / dies);
            }
          }
          var heard = mix;
          if (asOnAnIPad) {
            for (var pass = 0; pass < 2; pass++) {
              const rc = 1 / (2 * math.pi * 150);
              const dt = 1 / _rate;
              const a = rc / (rc + dt);
              final out = Float32List(heard.length);
              for (var i = 1; i < heard.length; i++) {
                out[i] = a * (out[i - 1] + heard[i] - heard[i - 1]);
              }
              heard = out;
            }
            for (var i = 0; i < heard.length; i++) {
              heard[i] += (random.nextDouble() - 0.5) * 0.0008;
            }
          }
          final reader = ChordReader();
          for (var end = _size; end < heard.length; end += _hop) {
            reader.hear(
              listenForNotes(
                Float32List.sublistView(heard, end - _size, end),
                sampleRate: _rate,
                size: _size,
              ),
            );
          }
          if (reader.guesses.isEmpty) continue;
          final shown = reader.guesses.first;
          final bass = shown.bass == null
              ? shown.chord.bass
              : shown.chord.pitchClasses[shown.chord.noteNames.indexOf(
                  shown.bass!,
                )];
          if (bass != lowest % 12) continue;
          bool same(Set<int> a, Set<int> b) =>
              a.length == b.length && a.containsAll(b);
          final named = shown.chord.pitchClasses.toSet();
          if (shown.chord.root == chord.root &&
              same(named, chord.pitchClasses.toSet())) {
            right++;
          } else if (same(named, {for (final p in pitches) p % 12})) {
            fair++;
          }
        }
      }
    }
    return (right: right, fair: fair, total: total);
  }

  test('strummed clean', () {
    final (:right, :fair, :total) = sweep(asOnAnIPad: false);
    expect(right / total, greaterThan(0.93));
    expect((right + fair) / total, greaterThan(0.95));
  });

  test('strummed as a guitar sounds through an iPad', () {
    final (:right, :fair, :total) = sweep(asOnAnIPad: true);
    expect(right / total, greaterThan(0.76));
    expect((right + fair) / total, greaterThan(0.78));
  });
}
