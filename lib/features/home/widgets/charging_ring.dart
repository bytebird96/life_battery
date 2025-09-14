// lib/ui/widgets/charging_ring.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 배터리 잔량 원형 링 (안쪽은 비어있음)
class ChargingRing extends StatelessWidget {
  final double percent;      // 0~1
  final double size;         // 지름
  final double thickness;    // 두께
  final double labelFont;    // 기본 퍼센트 폰트 (center가 없을 때만 사용)

  /// 중앙에 그릴 위젯 (제공되면 내부 기본 텍스트는 그리지 않음)
  final Widget? center;

  /// 배경 트랙/진행 색상 (진행은 start~end 스윕 그라데이션)
  final Color trackColor;
  final Color progressStart;
  final Color progressEnd;

  const ChargingRing({
    super.key,
    required this.percent,
    required this.size,
    required this.thickness,
    required this.labelFont,
    this.center,
    this.trackColor = const Color(0xFFE9E8FF),
    this.progressStart = const Color(0xFFC8B6FF),
    this.progressEnd = const Color(0xFF5B2EFF),
  });

  @override
  Widget build(BuildContext context) {
    final p = percent.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          percent: p,
          thickness: thickness,
          trackColor: trackColor,
          start: progressStart,
          end: progressEnd,
        ),
        child: Center(
          // center가 있으면 그걸 쓰고, 없으면 기본 퍼센트 텍스트
          child: center ??
              Text(
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
  final Color trackColor;
  final Color start;
  final Color end;

  _RingPainter({
    required this.percent,
    required this.thickness,
    required this.trackColor,
    required this.start,
    required this.end,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (math.min(size.width, size.height) - thickness) / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    // 트랙
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    // 진행
    if (percent > 0) {
      final sweep = math.pi * 2 * percent;
      final shader = SweepGradient(
        startAngle: -math.pi / 2,               // 12시 고정
        endAngle: -math.pi / 2 + sweep,
        colors: [start, end],                   // 같게 주면 단색
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
  bool shouldRepaint(covariant _RingPainter o) =>
      o.percent != percent ||
          o.thickness != thickness ||
          o.trackColor != trackColor ||
          o.start != start ||
          o.end != end;
}
