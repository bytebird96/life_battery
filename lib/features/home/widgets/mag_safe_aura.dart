// lib/ui/widgets/mag_safe_aura.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class MagSafeAura extends StatefulWidget {
  final double size;
  final double thickness;
  final Color glowColor;   // 네온 컬러
  final Color highlight;   // 회전 스윕 컬러

  const MagSafeAura({
    super.key,
    required this.size,
    required this.thickness,
    this.glowColor = const Color(0xFFEFFF7A),
    this.highlight = const Color(0xFF8AE66E),
  });

  @override
  State<MagSafeAura> createState() => _MagSafeAuraState();
}

class _MagSafeAuraState extends State<MagSafeAura>
    with TickerProviderStateMixin {
  late final AnimationController _rot;   // 2.6s 회전
  late final AnimationController _pulse; // 1.6s 펄스

  @override
  void initState() {
    super.initState();
    _rot = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rot.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outer = widget.size * 0.5 + widget.thickness * 0.9;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rot, _pulse]),
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              _SoftGlow(
                size: widget.size,
                maxRadius: outer,
                color: widget.glowColor.withOpacity(0.55 + _pulse.value * 0.15),
              ),
              _Ripples(
                size: widget.size,
                baseRadius: widget.size * 0.5 + widget.thickness * 0.2,
                spread: widget.thickness * 1.8,
                color: widget.glowColor,
                t: _pulse.value,
              ),
              Transform.rotate(
                angle: _rot.value * 2 * math.pi,
                child: CustomPaint(
                  size: Size.square(widget.size + widget.thickness),
                  painter: _SweepHighlightPainter(
                    ringRadius: widget.size * 0.5,
                    ringThickness: widget.thickness,
                    color: widget.highlight,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SoftGlow extends StatelessWidget {
  final double size, maxRadius;
  final Color color;
  const _SoftGlow({
    required this.size,
    required this.maxRadius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final blur = maxRadius * 0.35;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // 색 없이도 BoxDecoration은 그림자를 렌더링합니다.
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.45),
            blurRadius: blur,
            spreadRadius: blur * 0.25,
          ),
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: blur * 1.5,
            spreadRadius: blur * 0.5,
          ),
        ],
      ),
    );
  }
}

class _Ripples extends StatelessWidget {
  final double size, baseRadius, spread, t;
  final Color color;
  const _Ripples({
    required this.size,
    required this.baseRadius,
    required this.spread,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size + spread * 2),
    painter: _RipplePainter(
      baseRadius: baseRadius,
      spread: spread,
      color: color,
      t: t,
    ),
  );
}

class _RipplePainter extends CustomPainter {
  final double baseRadius, spread, t;
  final Color color;
  _RipplePainter({
    required this.baseRadius,
    required this.spread,
    required this.color,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final r = baseRadius + spread * phase;
      final opacity = (1.0 - phase) * 0.35;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withOpacity(opacity.clamp(0.0, 1.0));
      canvas.drawCircle(c, r, p);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter o) =>
      o.t != t || o.baseRadius != baseRadius || o.spread != spread || o.color != color;
}

class _SweepHighlightPainter extends CustomPainter {
  final double ringRadius, ringThickness;
  final Color color;
  _SweepHighlightPainter({
    required this.ringRadius,
    required this.ringThickness,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const sweep = 2 * math.pi * 0.18; // 약 18%
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: ringRadius,
    );
    final shader = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + sweep,
      colors: [Colors.transparent, color.withOpacity(0.9), Colors.transparent],
      stops: const [0.0, 0.4, 1.0],
    ).createShader(rect);

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = ringThickness
      ..shader = shader;

    canvas.drawArc(rect, -math.pi / 2, sweep, false, p);
  }

  @override
  bool shouldRepaint(covariant _SweepHighlightPainter o) =>
      o.ringRadius != ringRadius || o.ringThickness != ringThickness || o.color != color;
}
