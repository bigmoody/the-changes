// The band's sound, pinned.
//
// Nothing here is a claim about what the band should sound like: the
// numbers are whatever it played the day this was written. What it is for
// is the refactor. Pulling the sample bank apart so an imported soundfont
// can stand where the piano stands is the kind of change that is very easy
// to make while altering the sound by one sample somewhere, and no test
// that asks whether an instrument is audible would ever catch it.
//
// So: four renders, chosen to reach every sampled instrument and both
// compers, hashed byte for byte. If one of these numbers moves, the band
// changed, and the change had better have been the point.
//
// When the sound is deliberately changed, these are re-pinned in the same
// commit that changes it, with the reason in the message. Never quietly.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';

/// FNV-1a over the bytes: cheap, and spreads a one-sample change across the
/// whole number so a near miss does not read as a near miss.
int digest(Uint8List bytes) {
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash = (hash ^ byte) * 0x100000001b3;
    hash &= 0xFFFFFFFFFFFFFFFF;
  }
  return hash;
}

Tune tuneNamed(String title) =>
    standards.firstWhere((tune) => tune.title == title);

void main() {
  late SampleBank bank;

  setUpAll(() async {
    bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
  });

  /// Renders [request] and hands back a digest per instrument.
  Map<String, int> render(BackingRequest request) {
    final backing = renderBacking(request);
    return {
      for (final entry in backing.stems.entries)
        entry.key.label: digest(entry.value),
    };
  }

  test('a swing tune, piano comping', () {
    final tune = tuneNamed('A Foggy Day');
    expect(
      render(
        BackingRequest(
          tune: tune,
          loop: LoopRange.wholeTune(tune),
          tempo: 160,
          samples: bank,
          seed: 7,
        ),
      ),
      {
        'Chords': 5040630575083807879,
        'Bass': 2922376460978512219,
        'Drums': -940317503037627305,
      },
    );
  });

  test('rhythm changes, guitar comping and arpeggios', () {
    final tune = tuneNamed('Cotton Tail');
    expect(
      render(
        BackingRequest(
          tune: tune,
          loop: LoopRange.wholeTune(tune),
          tempo: 200,
          samples: bank,
          seed: 3,
          comping: Comping.guitar,
          arpeggios: true,
          arpeggioSound: Comping.guitar,
        ),
      ),
      {
        'Chords': 8416574114384651097,
        'Bass': -8428501499733174900,
        'Drums': 6155078671616695515,
        'Arpeggios': -6529522868437472996,
      },
    );
  });

  test('a bossa, with the arpeggios on the piano', () {
    final tune = tuneNamed('The Shadow of Your Smile');
    expect(
      render(
        BackingRequest(
          tune: tune,
          loop: LoopRange.wholeTune(tune),
          tempo: 130,
          samples: bank,
          seed: 1,
          arpeggios: true,
        ),
      ),
      {
        'Chords': 9049823189860803042,
        'Bass': 447999560278910786,
        'Drums': 8214853811544911010,
        'Arpeggios': 5589457551407717847,
      },
    );
  });

  test('a funk tune, where the bass stops walking', () {
    final tune = tuneNamed('Freedom Jazz Dance');
    expect(
      render(
        BackingRequest(
          tune: tune,
          loop: LoopRange.wholeTune(tune),
          tempo: 138,
          samples: bank,
          seed: 5,
        ),
      ),
      {
        'Chords': -7215746479613155286,
        'Bass': -125329865868221911,
        'Drums': 8622207292756944879,
      },
    );
  });

  test('the same request twice renders the same band', () {
    final tune = tuneNamed('Blue Seven');
    request() => BackingRequest(
      tune: tune,
      loop: LoopRange.wholeTune(tune),
      tempo: 120,
      samples: bank,
      seed: 2,
    );
    expect(render(request()), render(request()));
  });
}
