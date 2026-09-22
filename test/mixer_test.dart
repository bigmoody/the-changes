import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/settings/app_settings.dart';

/// Records the volumes the controller sends, without real audio.
class _FakePlayer extends PracticePlayer {
  final volumes = <Instrument, double>{};

  @override
  void setVolume(Instrument instrument, double volume) =>
      volumes[instrument] = volume;
}

void main() {
  late _FakePlayer player;
  late PracticeController controller;

  setUp(() {
    player = _FakePlayer();
    controller = PracticeController(
      tune: standards.first,
      player: player,
      settings: AppSettings.inMemory(),
    );
  });

  test('mute silences one instrument and keeps its volume', () {
    controller.setVolume(Instrument.bass, 0.6);
    controller.toggleMute(Instrument.bass);
    expect(player.volumes[Instrument.bass], 0);
    controller.toggleMute(Instrument.bass);
    expect(player.volumes[Instrument.bass], 0.6);
  });

  test('solo isolates one instrument', () {
    controller.toggleSolo(Instrument.drums);
    expect(player.volumes, {
      Instrument.chords: 0,
      Instrument.bass: 0,
      Instrument.drums: 1,
      Instrument.arpeggio: 0,
      // Soloing silences an imported part too, whether or not one is in.
      Instrument.imported: 0,
    });
    controller.resetMix();
    expect(player.volumes.values, everyElement(1.0));
  });
}
