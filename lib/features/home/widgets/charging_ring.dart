import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';

/// 배터리 링 (안쪽은 완전 비움, 링에만 그라데이션)
class ChargingRing extends StatelessWidget {
  final double percent;    // 0.0~1.0
  final bool charging;     // 충전 중 여부
  final double size;       // 원 지름
  final double thickness;  // 링 두께
  final double labelFont;  // 중앙 글자 크기

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

    final ring = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(percent: p, thickness: thickness),
        child: Center(
          child: Text(
            '${(p * 100).round()}%',
            style: TextStyle(
              fontSize: labelFont,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111118),
            ),
          ),
        ),
      ),
    );

    return charging
        ? AvatarGlow(
      glowColor: const Color(0xFFEFFF7A),
      duration: const Duration(milliseconds: 1600),
      repeat: true,
      child: ring,
    )
        : ring;
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  final double thickness;

  _RingPainter({required this.percent, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // stroke 중심 기준 반지름
    final r = (math.min(size.width, size.height) - thickness) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: r);

    // 배경 트랙
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE9E8FF);
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);

    if (percent <= 0) return;

    // ── 링 영역으로만 clip (도넛 모양 마스크)
    final outerR = r + thickness / 2;
    final innerR = r - thickness / 2;
    final outer = Rect.fromCircle(center: center, radius: outerR);
    final inner = Rect.fromCircle(center: center, radius: innerR);

    final ringPath = Path()
      ..addOval(outer)
      ..addOval(inner)
      ..fillType = PathFillType.evenOdd; // 도넛

    canvas.save();
    canvas.clipPath(ringPath);

    final sweep = math.pi * 2 * percent;
    final shader = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + sweep,
      colors: const [Color(0xFFC8B6FF), Color(0xFF5B2EFF)],
      tileMode: TileMode.clamp,
    ).createShader(arcRect);

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..shader = shader;

    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, progress);
    canvas.restore();

    // (안전장치) 안쪽을 확실히 흰색으로 채워 미세한 번짐 제거
    final innerFill = Paint()..color = Colors.white;
    canvas.drawCircle(center, innerR - 0.25, innerFill);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.percent != percent || old.thickness != thickness;
}
