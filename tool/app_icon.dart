// Draws the app icon at every size iOS and Android ask for.
//
//   flutter test tool/app_icon.dart
//
// The icon is the chart's rehearsal mark (a boxed letter) holding C7: the
// C in ink, the 7 in the red pencil the app uses for the player's own marks.
// Drawn from shapes rather than set in a font, so it's the app's own, and
// written at each size directly (not scaled down from one image) so the
// small ones stay sharp. The PNGs have no alpha channel: the App Store
// rejects icons that do, even fully opaque ones.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const paper = ui.Color(0xFFF7F4EE);
const ink = ui.Color(0xFF1C1B19);
const pencil = ui.Color(0xFFC23B22);

/// The icon on a [size]-pixel square canvas.
void paintIcon(ui.Canvas canvas, double size) {
  final s = size / 1024;
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, size, size),
    ui.Paint()..color = paper,
  );
  // The rehearsal box.
  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(
      ui.Rect.fromCenter(
        center: ui.Offset(512 * s, 512 * s),
        width: 560 * s,
        height: 560 * s,
      ),
      ui.Radius.circular(36 * s),
    ),
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 44 * s
      ..color = ink,
  );
  // The C: a heavy arc, open to the right.
  const gap = 0.78; // radians either side of east
  canvas.drawArc(
    ui.Rect.fromCircle(center: ui.Offset(452 * s, 540 * s), radius: 138 * s),
    gap,
    2 * math.pi - 2 * gap,
    false,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 80 * s
      ..color = ink,
  );
  // The 7 in pencil, raised like a chord symbol's.
  canvas.drawPath(
    ui.Path()
      ..moveTo(590 * s, 352 * s)
      ..lineTo(704 * s, 352 * s)
      ..quadraticBezierTo(650 * s, 420 * s, 628 * s, 506 * s),
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 38 * s
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..color = pencil,
  );
}

/// An RGB PNG (no alpha) of [rgba] pixels.
Uint8List _png(Uint8List rgba, int width, int height) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // no filter
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      raw.add([rgba[i], rgba[i + 1], rgba[i + 2]]);
    }
  }
  final crcTable = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = c & 1 == 1 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });
  int crc(List<int> bytes) {
    var c = 0xFFFFFFFF;
    for (final b in bytes) {
      c = crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
    }
    return c ^ 0xFFFFFFFF;
  }

  final out = BytesBuilder();
  void chunk(String type, List<int> data) {
    final typed = [...type.codeUnits, ...data];
    out
      ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
      ..add(typed)
      ..add((ByteData(4)..setUint32(0, crc(typed))).buffer.asUint8List());
  }

  out.add([137, 80, 78, 71, 13, 10, 26, 10]);
  chunk('IHDR', [
    ...(ByteData(8)
          ..setUint32(0, width)
          ..setUint32(4, height))
        .buffer
        .asUint8List(),
    8, 2, 0, 0, 0, // 8-bit RGB
  ]);
  chunk('IDAT', ZLibCodec(level: 9).encode(raw.toBytes()));
  chunk('IEND', []);
  return out.toBytes();
}

Future<void> _write(String path, int size) async {
  final recorder = ui.PictureRecorder();
  paintIcon(ui.Canvas(recorder), size.toDouble());
  final image = await recorder.endRecording().toImage(size, size);
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  File(path).writeAsBytesSync(_png(rgba!.buffer.asUint8List(), size, size));
}

void main() {
  test('draws the app icon at every size', () async {
    const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    for (final (name, size) in [
      ('1024x1024@1x', 1024),
      ('20x20@1x', 20), ('20x20@2x', 40), ('20x20@3x', 60), //
      ('29x29@1x', 29), ('29x29@2x', 58), ('29x29@3x', 87), //
      ('40x40@1x', 40), ('40x40@2x', 80), ('40x40@3x', 120), //
      ('60x60@2x', 120), ('60x60@3x', 180), //
      ('76x76@1x', 76), ('76x76@2x', 152), ('83.5x83.5@2x', 167),
    ]) {
      await _write('$ios/Icon-App-$name.png', size);
    }
    for (final (density, size) in [
      ('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), //
      ('xxxhdpi', 192),
    ]) {
      await _write(
        'android/app/src/main/res/mipmap-$density/ic_launcher.png',
        size,
      );
    }
  });
}
