import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/settings/app_settings.dart';

PracticeController _controllerFor(String chart) => PracticeController(
  tune: Tune.fromChart(
    title: 'Test',
    key: 'C',
    defaultTempo: 120,
    chart: chart,
  ),
  player: PracticePlayer(),
  settings: AppSettings.inMemory(),
);

void main() {
  test('the look-ahead skips bars that repeat the chord', () {
    // "Take the 'A' Train": two bars of C6 before the D7♯11.
    final controller = _controllerFor('| C6 | C6 | D7#11 | D7#11 | Dm7 |');
    expect(controller.shownSlot.chord.display, 'C6');
    expect(controller.nextSlot.chord.display, 'D7♯11');
  });

  test('looping one chord, the look-ahead is that chord again', () {
    final controller = _controllerFor('| Dm7 | G7 | CΔ7 | CΔ7 |');
    controller.loopBar(2);
    expect(controller.nextSlot.chord.display, 'CΔ7');
  });
}
