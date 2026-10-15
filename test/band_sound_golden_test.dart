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

  // The three with a piano on them re-pinned when it was given its tail
  // back: the recordings were all cut at 3 seconds and are now cut where
  // each register has actually died, the pedal is let up over 0.3 of a
  // second rather than 0.18, and the stroke is a hundredth of a decibel
  // softer to leave the band's balance where it was. Rhythm changes is
  // not among them, which is the check: it is comped and arpeggiated on
  // the guitar, so nothing here should have reached it.
  //
  // All four re-pinned when the recorded kit was given a room and its
  // layer chosen by how hard the stroke is. Every stem moved, not only the
  // drums: one gain is worked out from the summed mix and handed to all of
  // them, so a louder kit moves the bytes of the bass as well.
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
        'Chords': -2175515544437863851,
        'Bass': -1133154908398613124,
        'Drums': 8329262449647208300,
      },
    );
  });

  // Re-pinned when the arpeggios were given their own, flatter swing:
  // a running line is not played as a stream of dotted quavers, whatever
  // the ride is doing. All four stems move rather than the arpeggios
  // alone, because one gain is worked out from the peak of the summed
  // mix and applied to every stem, so changing any part changes the
  // level of all of them.
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
        'Chords': 3637804339393996240,
        'Bass': -3609468427492631304,
        'Drums': 366290961986166608,
        'Arpeggios': -2306486937325772848,
      },
    );
  });

  // Back to what they were. These moved once, wrongly: the drum patterns
  // were changed to write straight and lean afterwards, and the change
  // that was meant to hand each feel its own resting place never reached
  // the file, so every even groove was leaned by the swing feel's curve
  // and a bossa's hi-hats lurched. Re-pinning them hid it. The numbers
  // here are the ones from before any of that, which is the point of
  // having them.
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
        'Chords': 5647163268689021234,
        'Bass': 5122604412584054575,
        'Drums': -3230471491011277960,
        'Arpeggios': -6970577978376720112,
      },
    );
  });

  // Back to what they were. These moved once, wrongly: the drum patterns
  // were changed to write straight and lean afterwards, and the change
  // that was meant to hand each feel its own resting place never reached
  // the file, so every even groove was leaned by the swing feel's curve
  // and a bossa's hi-hats lurched. Re-pinning them hid it. The numbers
  // here are the ones from before any of that, which is the point of
  // having them.
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
        'Chords': -1663792146688055098,
        'Bass': 5035989795993764222,
        'Drums': 7870876570978042504,
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
