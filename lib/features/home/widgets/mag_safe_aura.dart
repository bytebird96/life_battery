// lib/ui/widgets/mag_safe_aura.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ring_geometry.dart';


// mag_safe_aura.dart
class MagSafeAura extends StatelessWidget {
  /// 링의 위치와 반경 정보를 담은 공통 지오메트리
  final RingGeometry ring;

  /// 글로우의 기본 색상
  final Color glowColor;

  /// 번개 아이콘 표시 여부
  final bool showBolt;      // 번개 아이콘 옵션

  /// 번개 아이콘 크기
  final double boltSize;    // 아이콘 크기

  const MagSafeAura({
    super.key,
    required this.ring,
    this.glowColor = const Color(0xFF32D74B),
    this.showBolt = true,
    this.boltSize = 44, required Color highlight,
  });

  @override
  Widget build(BuildContext context) {
    // 링 두께를 기반으로 글로우의 폭과 블러 강도를 계산
    final glowWidth = ring.thickness * 1.15;  // 글로우 폭
    final sigma = ring.thickness * 0.9;       // 블러 강도
    final size = ring.size;                   // 링의 지름

    // 위젯 전체 크기를 링 지름으로 고정하여
    // 충전 전/중에 위치가 달라지지 않도록 한다.
    return IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none, // 글로우가 바깥으로 퍼져도 잘리지 않도록 함
          children: [
            // ★ 외곽으로만 퍼지는 글로우 스트로크
            CustomPaint(
              // 캔버스 크기를 링 지름으로 유지하여 위치를 통일한다.
              size: Size.square(size),
              painter: _OuterGlowPainter(
                // ring.rect를 그대로 사용하여 ChargingRing과 동일한 좌표계를 공유
                rect: ring.rect,
                strokeWidth: glowWidth,
                color: glowColor.withOpacity(0.85),
                sigma: sigma,
              ),
            ),
            if (showBolt)
              Icon(
                Icons.bolt_rounded,
                size: boltSize,
                color: glowColor.withOpacity(0.9),
              ),
          ],
        ),
      ),
    );
  }
}

class _OuterGlowPainter extends CustomPainter {
  /// drawArc에 사용할 링 사각형
  final Rect rect;

  /// 글로우 스트로크의 두께
  final double strokeWidth;

  /// 블러 강도
  final double sigma;

  /// 글로우 색상
  final Color color;

  const _OuterGlowPainter({
    required this.rect,
    required this.strokeWidth,
    required this.sigma,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      // ★ 바깥으로만 퍼지는 블러
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, sigma)
      ..color = color;
    canvas.drawArc(rect, 0, math.pi * 2, false, p);
  }

  @override
  bool shouldRepaint(covariant _OuterGlowPainter old) =>
      old.rect != rect ||
      old.strokeWidth != strokeWidth ||
      old.sigma != sigma ||
      old.color != color;
}
