import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/lt_colors.dart';

/// Painted LemonTrack mark — lemon arc ring with an ember core.
/// No asset pipeline needed, works everywhere including web hot restarts.
class LtLogo extends StatelessWidget {
  final double size;
  const LtLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _LogoPainter());
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.14;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final ring = Paint()
      ..color = LTColors.lemon
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi * 0.28, math.pi * 1.62, false, ring);

    final core = Paint()..color = LTColors.ember;
    final coreRadius = size.width * 0.13;
    canvas.drawCircle(center, coreRadius, core);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => false;
}
