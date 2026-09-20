import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/settings/app_settings.dart';

void main() {
  final tune = standards.firstWhere((t) => t.title == 'Autumn Leaves');

  PracticeController newController() => PracticeController(
    tune: tune,
    player: PracticePlayer(),
    settings: AppSettings.inMemory(),
  );

  test('dragging selects every bar between start and finish', () {
    final c = newController();
    c.startLoopDrag(5);
    c.updateLoopDrag(6);
    c.updateLoopDrag(9); // across a line break
    expect(c.loop, LoopRange.bars(tune, 5, 9));
    c.endLoopDrag();
    expect(c.loop.describe(tune), 'Bars 6–10');
  });

  test('dragging backwards works too', () {
    final c = newController();
    c.startLoopDrag(12);
    c.updateLoopDrag(3);
    c.endLoopDrag();
    expect(c.loop, LoopRange.bars(tune, 3, 12));
  });

  test('a drag that returns to its start loops just that bar', () {
    final c = newController();
    c.startLoopDrag(7);
    c.updateLoopDrag(10);
    c.updateLoopDrag(7);
    c.endLoopDrag();
    expect(c.loop, LoopRange.bars(tune, 7, 7));
  });
}
