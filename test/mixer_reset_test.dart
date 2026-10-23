// What Reset at the top of the mixer resets.
//
// It used to be the faders, the mutes and the solos, because that is
// what the sheet was when the button was written. The sheet has since
// grown the whole band, the swing, the figure and the count-in, so a
// Reset that moved three sliders was answering a question nobody was
// asking. Then it left the kit and the sounds alone, and brushes stayed
// on after Reset: now it is everything.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/comping.dart';
import 'package:play_along/audio/arpeggios.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/settings/app_settings.dart';

void main() {
  test('Reset puts everything in the sheet back', () async {
    final tune = standards.firstWhere((t) => t.title == 'Blue Bossa');
    final settings = AppSettings.inMemory();
    final controller = PracticeController(
      tune: tune,
      player: PracticePlayer(),
      settings: settings,
    );
    addTearDown(controller.dispose);

    // Move everything the sheet can move.
    controller
      ..setStyle(BandStyle.of(Feel.funk).withFigure(CompFigure.charleston))
      ..setSwing(dottedSwing)
      ..setCountInBars(2)
      ..setArpeggios(true)
      ..toggleMute(Instrument.bass)
      ..toggleSolo(Instrument.drums)
      ..setVolume(Instrument.chords, 0.2);
    await settings.setDrumSound(DrumSound.brushes);
    await settings.setComping(Comping.guitar);
    await settings.setBassSound(BassSound.imported);
    await settings.setArpeggioSound(Comping.guitar);
    await settings.setArpeggioRate(ArpeggioRate.values.last);

    await controller.resetSheet();

    expect(controller.styleIsChosen, isFalse);
    expect(controller.style, tune.style, reason: 'the band as written');
    expect(controller.style.figure, isNull);
    expect(controller.swing, isNull, reason: 'back to following the tempo');
    expect(controller.countInBars, 1);
    expect(controller.arpeggios, isFalse);
    expect(controller.isMuted(Instrument.bass), isFalse);
    expect(controller.isSoloed(Instrument.drums), isFalse);
    expect(controller.volumeOf(Instrument.chords), 1.0);
    // The sounds too: brushes left on after Reset was the complaint.
    expect(settings.drumSound, DrumSound.kit);
    expect(settings.comping, Comping.piano);
    expect(settings.bassSound, BassSound.upright);
    expect(settings.arpeggioSound, Comping.piano);
    expect(settings.arpeggioRate, ArpeggioRate.eighths);
  });
}
