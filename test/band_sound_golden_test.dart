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

  // The bossa re-pinned when its clave stopped being the loudest thing in
  // the kit. Three things in one: the cross-stick is a lighter recording,
  // it is struck 4.4 dB softer, and the ride no longer jumps 2.6 dB above
  // the hi-hat it is standing in for. Nothing else moves: the clave's
  // level is the bossa pattern's, and the softer cross-stick is a layer
  // chosen by how hard the stroke is, which only this feel strikes gently
  // enough to reach.
  //
  // The funk tune re-pinned a fifth time when its kick became the close
  // microphone's as well. The overheads' kick is 22 dB under the snare,
  // which is what a kick sounds like from across a room and cannot be the
  // floor of a funk groove at any velocity. Nothing else moves: the kick
  // is chosen by the groove, like the snare.
  //
  // The funk tune re-pinned a fourth time when its snare became the close
  // microphone's instead of the overheads'. Same drum, same level, half
  // the length: the overhead is the drum in its room and funk wants the
  // drum. No other groove is touched, which the tight snare's own test
  // checks by swapping the recording out and watching which renders
  // notice.
  //
  // The funk tune re-pinned again when its bass was built on the kick
  // instead of beside it: the two were each rolling their own syncopation
  // out of their own random, so they were only ever together by accident.
  // Both read the figure off the bar number now. The kick's own choice
  // moved with it, from a roll a bar to a two-bar riff.
  //
  // The funk tune re-pinned on its own when its kit lost the room and its
  // backbeat came down 5.5 dB. A funk kit is close-miked and dry, and the
  // backbeat was struck at 0.95 against the loudest recording in the
  // bank, which put it 8 dB over the hats. No other feel is touched: the
  // room is now chosen by the groove and the velocity is in the funk
  // pattern alone.
  //
  // The bossa re-pinned on its own when a chorus's last bar started
  // counting as the bar before a section: the bar after it is the first
  // bar, which is where a section begins, so the end of a chorus now
  // leads back to the top the way the end of any other section leads
  // into the next. It reaches any tune whose chart has section markers,
  // which is why one with no piano figure changed in it moved.
  //
  // The three with a piano on them re-pinned when the piano's release
  // came back down from 0.3 of a second to 0.2. At 0.3 every chord was
  // still sounding when the next one landed, which is a blur and not a
  // pedal. Rhythm changes is comped on the guitar, which has its own
  // shorter release, and does not move.
  //
  // The three with a piano on them re-pinned when it was struck 1.6 dB
  // harder for sitting too far back. None of them is modal, so the quartal
  // voicings in the same commit do not reach them; rhythm changes is comped
  // on the guitar and does not move at all this time.
  //
  // All four re-pinned when the compers were given the form to play to on
  // a chart that does not change chord. Every one of them here does change
  // chord, so what reaches them is the second half of it: five beats for a
  // held chord's figure to begin on where there were two, and a weighting
  // against landing twice in the same place. Rhythm changes moves with the
  // rest because the guitarist comps through the same code.
  //
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
  // All four re-pinned when the recorded kit came down 1 dB, to put the
  // comping further forward. Lifting the piano instead would have been
  // the direct way round and was not available: it comes out of the
  // bass's margin over 300 Hz to 3 kHz, which is all a phone speaker
  // plays, and 0.46 dB of that was left. Every stem moves again, the one
  // gain off the summed mix being handed to all of them, so a quieter
  // kit moves the bytes of the bass too. Rhythm changes is among them
  // this time for that reason and not because its guitar changed.
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
        'Chords': -1665969834922227523,
        'Bass': -1789955654117938412,
        'Drums': 2007003399160216928,
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
        'Chords': -1282040926182401071,
        'Bass': 981331333045148967,
        'Drums': -4433178409430512963,
        'Arpeggios': -9193643309482914657,
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
        'Chords': 2487918751794878146,
        'Bass': 4840102059698419593,
        'Drums': -7465439303167663579,
        'Arpeggios': -7356065158708507562,
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
        'Chords': 6229360461391581415,
        'Bass': -4059528358616524240,
        'Drums': 1804155906518307522,
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
