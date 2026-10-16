// What Reset at the top of the mixer resets.
//
// It used to be the faders, the mutes and the solos, because that is
// what the sheet was when the button was written. The sheet has since
// grown the whole band, the swing, the figure and the count-in, so a
// Reset that moved three sliders was answering a question nobody was
// asking.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/comping.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/settings/app_settings.dart';

void main() {
  test('Reset puts the tune back, and keeps what is not the tune', () {
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
    settings.setDrumSound(DrumSound.brushes);
    settings.setComping(Comping.guitar);

    controller.resetSheet();

    expect(controller.styleIsChosen, isFalse);
    expect(controller.style, tune.style, reason: 'the band as written');
    expect(controller.style.figure, isNull);
    expect(controller.swing, isNull, reason: 'back to following the tempo');
    expect(controller.countInBars, 1);
    expect(controller.arpeggios, isFalse);
    expect(controller.isMuted(Instrument.bass), isFalse);
    expect(controller.isSoloed(Instrument.drums), isFalse);
    expect(controller.volumeOf(Instrument.chords), 1.0);
    // Not the tune's, so not reset: which kit and who plays the chords
    // follow the player from tune to tune.
    expect(settings.drumSound, DrumSound.brushes);
    expect(settings.comping, Comping.guitar);
  });
}
