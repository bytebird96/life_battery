// lib/ui/widgets/mag_safe_aura.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';


// mag_safe_aura.dart
class MagSafeAura extends StatelessWidget {
  final double size;
  final double thickness;
  final Color glowColor;
  final bool showBolt;      // 번개 아이콘 옵션
  final double boltSize;    // 아이콘 크기

  const MagSafeAura({
    super.key,
    required this.size,
    required this.thickness,
    this.glowColor = const Color(0xFF32D74B),
    this.showBolt = true,
    this.boltSize = 44, required Color highlight,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    final glowWidth = thickness * 1.15;       // 글로우 폭
    final sigma = thickness * 0.9;            // 블러 강도

    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // ★ 외곽에만 퍼지는 글로우 스트로크 (안쪽은 절대 채우지 않음)
          CustomPaint(
            size: Size.square(size + glowWidth * 2),
            painter: _OuterGlowPainter(
              radius: radius,
              strokeWidth: glowWidth,
              color: glowColor.withOpacity(0.85),
              sigma: sigma,
            ),
          ),
          if (showBolt)
            Icon(Icons.bolt_rounded,
                size: boltSize,
                color: glowColor.withOpacity(0.9)),
        ],
      ),
    );
  }
}

class _OuterGlowPainter extends CustomPainter {
  final double radius;
  final double strokeWidth;
  final double sigma;
  final Color color;
  const _OuterGlowPainter({
    required this.radius,
    required this.strokeWidth,
    required this.sigma,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: c, radius: radius);
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
      old.radius != radius ||
          old.strokeWidth != strokeWidth ||
          old.sigma != sigma ||
          old.color != color;
}
