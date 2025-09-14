import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 안쪽이 비어있는 배터리 링 (그라데이션은 링에만 적용)
class ChargingRing extends StatelessWidget {
  final double percent;    // 0~1
  final bool charging;     // (여긴 쓰지 않음 - 래퍼에서 처리)
  final double size;       // 지름
  final double thickness;  // 두께
  final double labelFont;  // 퍼센트 폰트

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
    final c = Offset(size.width/2, size.height/2);
    final r = (math.min(size.width, size.height) - thickness)/2;
    final rect = Rect.fromCircle(center: c, radius: r);

    // 배경 트랙
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE9E8FF);
    canvas.drawArc(rect, 0, math.pi*2, false, track);

    // 진행 링(그라데이션, stroke-only)
    if (percent > 0) {
      final sweep = math.pi * 2 * percent;
      final shader = SweepGradient(
        startAngle: -math.pi/2,
        endAngle: -math.pi/2 + sweep,
        colors: const [Color(0xFFC8B6FF), Color(0xFF5B2EFF)],
      ).createShader(rect);

      final prog = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..shader = shader;
      canvas.drawArc(rect, -math.pi/2, sweep, false, prog);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.percent != percent || old.thickness != thickness;
}
