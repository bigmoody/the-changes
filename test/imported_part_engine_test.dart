// An imported part, once the band gets hold of it.
//
// The model's tests say where the notes go. These say they arrive: that the
// part has its own channel rather than leaking into somebody else's, that
// all three instruments can play it, and above all that it is measured in
// beats. That last one is the whole claim of the feature. If the part were
// ever placed in seconds it would still sound fine at the tempo it was
// imported at and drift at every other one, which is exactly the kind of
// bug that ships.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/imported_part.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune_library.dart';

/// A part with one note, a bar in: enough to find an onset and say when it
/// happened.
ImportedPart _oneNote({int pitch = 60, PartVoice voice = PartVoice.piano}) =>
    ImportedPart(
      name: 'Test',
      notes: [(pitch: pitch, beat: 4, beats: 1, velocity: 0.9)],
      lengthBeats: 48,
      voice: voice,
    );

/// The first sample loud enough to be a note starting.
int _onset(Uint8List wav) {
  final samples = decodeWav(wav);
  for (var i = 0; i < samples.length; i++) {
    if (samples[i].abs() > 500) return i;
  }
  return -1;
}

double _rms(Uint8List wav) {
  final samples = decodeWav(wav);
  var sum = 0.0;
  for (final sample in samples) {
    sum += sample * sample.toDouble();
  }
  return sum == 0 ? 0 : (sum / samples.length);
}

void main() {
  late SampleBank bank;

  setUpAll(() async {
    bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
  });

  final tune = practiceProgressions.firstWhere(
    (t) => t.title == 'Jazz blues in F',
  );

  BackingRequest request({ImportedPart? part, int tempo = 120}) =>
      BackingRequest(
        tune: tune,
        loop: LoopRange.bars(tune, 0, tune.barCount - 1),
        tempo: tempo,
        seed: 5,
        samples: bank,
        countInBars: 0,
        imported: part,
      );

  test('no part, no channel', () {
    final without = renderBacking(request());
    expect(without.stems.keys, isNot(contains(Instrument.imported)));
  });

  test('a part gets its own channel and is audible in it', () {
    final with_ = renderBacking(request(part: _oneNote()));
    expect(with_.stems.keys, contains(Instrument.imported));
    expect(_rms(with_.stems[Instrument.imported]!), greaterThan(0));
  });

  test('it does not leak into the parts the band writes', () {
    // The bug this is here for: a new part rendered into the chords mix by
    // mistake would sound perfectly right and be impossible to mute.
    //
    // Leaking is a change of shape, not of level. Every stem is scaled by
    // one gain taken from the whole band's peak, so adding a part makes
    // all of them quieter together, and comparing absolute levels would
    // call that leakage. What has to be true is that they all move by the
    // same amount: a part leaking into the chords would push that one and
    // not the others.
    final without = renderBacking(request());
    final with_ = renderBacking(request(part: _oneNote()));
    final ratios = {
      for (final part in [Instrument.chords, Instrument.bass, Instrument.drums])
        part: _rms(with_.stems[part]!) / _rms(without.stems[part]!),
    };
    final values = ratios.values.toList();
    for (final ratio in values) {
      expect(
        ratio,
        closeTo(values.first, values.first * 0.01),
        reason: 'the parts did not all scale together: $ratios',
      );
    }
  });

  test('all three instruments will play one', () {
    for (final voice in PartVoice.values) {
      final rendered = renderBacking(
        request(
          part: _oneNote(
            pitch: voice == PartVoice.bass ? 40 : 60,
            voice: voice,
          ),
        ),
      );
      expect(
        _rms(rendered.stems[Instrument.imported]!),
        greaterThan(0),
        reason: 'nothing came out of the ${voice.label}',
      );
    }
  });

  test('it is placed in beats, so the tempo moves it', () {
    // The note is a bar in. At twice the tempo it should arrive at half the
    // time, near enough: the onset is where the sound crosses a threshold,
    // not the exact sample the note was scheduled at.
    final slow = _onset(
      renderBacking(request(part: _oneNote(), tempo: 100))
          .stems[Instrument.imported]!,
    );
    final fast = _onset(
      renderBacking(request(part: _oneNote(), tempo: 200))
          .stems[Instrument.imported]!,
    );
    expect(slow, greaterThan(0));
    expect(fast, greaterThan(0));
    expect(
      fast / slow,
      closeTo(0.5, 0.05),
      reason: 'a part in seconds would have landed in the same place twice',
    );
  });

  test('a note a bar in lands a bar in', () {
    const tempo = 120;
    final onset = _onset(
      renderBacking(request(part: _oneNote(), tempo: tempo))
          .stems[Instrument.imported]!,
    );
    // Four beats at 120 is two seconds, and the render is 44.1 kHz mono.
    expect(onset / 44100, closeTo(4 * 60 / tempo, 0.05));
  });

  test('transposing the part moves what is played', () {
    final home = renderBacking(request(part: _oneNote()));
    final up = renderBacking(request(part: _oneNote().transposedBy(5)));
    expect(
      _rms(up.stems[Instrument.imported]!),
      isNot(closeTo(_rms(home.stems[Instrument.imported]!), 0.001)),
    );
  });

  test('an empty part is no part at all', () {
    const empty = ImportedPart(name: 'Empty', notes: [], lengthBeats: 48);
    final rendered = renderBacking(request(part: empty));
    expect(rendered.stems.keys, isNot(contains(Instrument.imported)));
  });
}
