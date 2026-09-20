// The tune's name across the top of the practice screen.
//
// It used to shrink to whatever fitted on one line, with no floor. With
// the back arrow, three buttons and a menu beside it there is not much
// line to fit into, and "On the Sunny Side of the Street" came out at
// under seven points.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/take_store.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

/// The real hand lettering, loaded so the title is measured in the font it
/// is actually drawn in. A widget test otherwise draws every character as a
/// full square, which is far wider than the letters are — wide enough to
/// make a title look as though it cannot possibly fit.
Future<void> _loadLettering() async {
  var directory = File(Platform.resolvedExecutable).parent;
  while (directory.path != directory.parent.path) {
    final fonts = Directory('${directory.path}/artifacts/material_fonts');
    if (fonts.existsSync()) break;
    directory = directory.parent;
  }
  for (final (family, path) in [
    ('Roboto', '${directory.path}/artifacts/material_fonts/Roboto-Regular.ttf'),
    (handFont, 'assets/fonts/PetalumaScript.otf'),
  ]) {
    final bytes = await File(path).readAsBytes();
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
  handFontFallback = ['Roboto'];
}

/// The title as drawn, on the fullest the bar ever is: a takes store means
/// the recording button is there too, which is what it looks like in the
/// app. Measuring without it gives the title room it hasn't really got.
Future<Text> _title(WidgetTester tester, Tune tune, {Size? size}) async {
  tester.view
    ..physicalSize = (size ?? const Size(402, 874)) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: PracticeScreen(
        tune: tune,
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
        takes: TakeStore.inMemory(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<Text>(find.text(tune.title));
}

Tune _longest() => ([
  ...standards,
]..sort((a, b) => b.title.length.compareTo(a.title.length))).first;

void main() {
  setUpAll(_loadLettering);

  testWidgets('a short name gets the full size, on one line', (tester) async {
    final title = await _title(
      tester,
      standards.firstWhere((t) => t.title == 'Wave'),
    );
    expect(title.style?.fontSize, 26);
    expect(title.maxLines, 1);
  });

  testWidgets('the longest name in the book is still readable', (tester) async {
    final tune = _longest();
    final title = await _title(tester, tune);
    expect(
      title.style!.fontSize!,
      greaterThanOrEqualTo(12),
      reason: '"${tune.title}" at ${title.style!.fontSize}pt',
    );
  });

  testWidgets('and is written out in full, not docked', (tester) async {
    // Two lines rather than an ellipsis: the bar is the same height
    // either way, so a second line costs the chart nothing.
    for (final tune
        in [...standards]
          ..sort((a, b) => b.title.length.compareTo(a.title.length))
          ..length = 6) {
      final title = await _title(tester, tune);
      debugPrint(
        '${title.style!.fontSize!.toStringAsFixed(0)}pt  "${tune.title}"',
      );
      expect(
        title.overflow,
        isNot(TextOverflow.ellipsis),
        reason: '"${tune.title}" had its end taken off',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('a narrow phone still says which tune it is', (tester) async {
    final title = await _title(tester, _longest(), size: const Size(320, 568));
    expect(title.style!.fontSize!, greaterThanOrEqualTo(12));
  });
}
