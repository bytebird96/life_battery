// lib/ui/widgets/charging_ring.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class ChargingRing extends StatelessWidget {
  final double percent;   // 0~1
  final bool charging;    // 미사용(레거시 호환)
  final double size;      // 지름
  final double thickness; // 두께
  final double labelFont; // 가운데 퍼센트 폰트

  const ChargingRing({
    super.key,
    required this.percent,
    required this.charging,
    required this.size,
    required this.thickness,
    required this.labelFont,
  });

  @override
  Widget build(BuildContext context) {
    final p = percent.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(percent: p, thickness: thickness),
        child: Center(
          child: Text(
            '${(p * 100).round()}%',
            style: TextStyle(
              fontSize: labelFont,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111118),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  final double thickness;
  _RingPainter({required this.percent, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - thickness) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 배경 트랙 (연한 보라)
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE9E8FF);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    // 진행 링 (Stroke만, 안쪽은 절대 채우지 않음)
    if (percent > 0) {
      final sweep = math.pi * 2 * percent;
      final shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + sweep,
        colors: const [Color(0xFFC8B6FF), Color(0xFF5B2EFF)],
      ).createShader(rect);

      final prog = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..shader = shader;

      canvas.drawArc(rect, -math.pi / 2, sweep, false, prog);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.percent != percent || old.thickness != thickness;
}
