import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 배터리 잔량을 동그란 링으로 표시하는 위젯.
///
/// `PaintingStyle.stroke`만 사용해 내부는 완전히 비워 두고
/// 바깥 테두리만 색으로 채운다. 진행률은 12시(-90°) 방향을
/// 기준으로 시계방향으로 그려진다.
class ChargingRing extends StatelessWidget {
  /// 0~1 사이의 진행률. 범위를 벗어나면 [0,1]로 보정한다.
  final double percent;

  /// 기존 API 호환용으로 남겨둔 필드. glow 효과는 사용하지 않는다.
  /// 항상 `false`를 전달하면 된다.
  final bool charging;

  /// 링 전체의 지름.
  final double size;

  /// 링 두께.
  final double thickness;

  /// 중앙에 표시될 퍼센트 텍스트의 글꼴 크기.
  final double labelFont;

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
    // 잘못된 입력을 대비해 퍼센트를 0~1 범위로 제한한다.
    final p = percent.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        // 링을 그리는 커스텀 페인터
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

/// 배경 트랙과 진행 링을 실제로 그려주는 페인터.
class _RingPainter extends CustomPainter {
  /// 0~1 사이의 진행률
  final double percent;

  /// 링 두께
  final double thickness;

  _RingPainter({required this.percent, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    // 위젯 중앙 좌표와 반경을 계산한다.
    final center = Offset(size.width / 2, size.height / 2);
    // 두께만큼 줄여주어 선이 바깥으로 나가지 않게 한다.
    final radius = (math.min(size.width, size.height) - thickness) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // ---------------------- 배경 트랙 ----------------------
    // 진행률과 관계없이 흐린 색으로 원 전체를 그린다.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE9E8FF);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    // ------------------- 진행 링(그라데이션) -------------------
    // 퍼센트가 0보다 클 때만 그린다.
    if (percent > 0) {
      // 전체 각도(360°)에서 진행률만큼 곱해 진행 각도를 구한다.
      final sweep = math.pi * 2 * percent;

      // 12시 방향(-90°)에서 시작하는 스윕 그라데이션 셰이더 생성
      final shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + sweep,
        colors: const [Color(0xFFC8B6FF), Color(0xFF5B2EFF)],
      ).createShader(rect);

      final prog = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..shader = shader; // 그라데이션 적용

      // 배경 트랙 위에 진행 부분만 덮어 그린다.
      canvas.drawArc(rect, -math.pi / 2, sweep, false, prog);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.percent != percent || old.thickness != thickness;
}
