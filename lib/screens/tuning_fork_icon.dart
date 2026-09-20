// A tuning fork, drawn: the standard icon set doesn't have one.

import 'package:flutter/material.dart';

class TuningForkIcon extends StatelessWidget {
  const TuningForkIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = this.size ?? theme.size ?? 24;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _TuningForkPainter(color ?? theme.color ?? Colors.black),
      ),
    );
  }
}

class _TuningForkPainter extends CustomPainter {
  _TuningForkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Two prongs joined in a U, then the handle down to a small ball.
    final fork = Path()
      ..moveTo(8 * s, 2.5 * s)
      ..lineTo(8 * s, 11 * s)
      ..arcToPoint(
        Offset(16 * s, 11 * s),
        radius: Radius.circular(4 * s),
        clockwise: false,
      )
      ..lineTo(16 * s, 2.5 * s)
      ..moveTo(12 * s, 15 * s)
      ..lineTo(12 * s, 20 * s);
    canvas.drawPath(fork, stroke);
    canvas.drawCircle(
      Offset(12 * s, 21.2 * s),
      1.6 * s,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_TuningForkPainter old) => old.color != color;
}
