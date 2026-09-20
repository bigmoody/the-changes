import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/settings/app_settings.dart';

List<String> firstChords(PracticeController c, {bool chart = true}) => [
  for (final slot in (chart ? c.chart : c.tune).bars.first) slot.chord.display,
];

void main() {
  final autumnLeaves = standards.firstWhere((t) => t.title == 'Autumn Leaves');

  PracticeController controllerFor(AppSettings settings) => PracticeController(
    tune: autumnLeaves,
    player: PracticePlayer(),
    settings: settings,
  );

  test('B♭ and E♭ charts are written up from concert pitch', () {
    // Concert: Autumn Leaves in G minor starts on Cm7.
    expect(
      firstChords(controllerFor(AppSettings.inMemory(ChartInstrument.bFlat))),
      ['Dm7'], // trumpet / tenor: A minor
    );
    final alto = controllerFor(AppSettings.inMemory(ChartInstrument.eFlat));
    expect(firstChords(alto), ['Am7']); // alto: E minor
    expect(alto.chart.key, 'E minor');
  });

  test('the band stays at concert pitch whatever the chart shows', () {
    final controller = controllerFor(
      AppSettings.inMemory(ChartInstrument.bFlat),
    );
    expect(firstChords(controller, chart: false), ['Cm7']);
  });

  test('changing instrument or key updates the chart immediately', () {
    final settings = AppSettings.inMemory();
    final controller = controllerFor(settings);
    expect(firstChords(controller), ['Cm7']);

    settings.setInstrument(ChartInstrument.bFlat);
    expect(firstChords(controller), ['Dm7']);

    controller.transpose(-3); // concert E minor → B♭ chart in F♯ minor
    expect(firstChords(controller, chart: false), ['Am7']);
    expect(firstChords(controller), ['Bm7']);
    expect(controller.chart.key, 'F♯ minor');
  });
}
