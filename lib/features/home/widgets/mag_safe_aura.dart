import 'dart:math' as math;
import 'package:flutter/material.dart';

/// MagSafe 충전 애니메이션.
///
/// 배터리 링 주변에 네온이 퍼지며 회전하는 하이라이트와
/// 바깥으로 확산되는 리플을 동시에 표현한다.
class MagSafeAura extends StatefulWidget {
  /// [size] : 안쪽 배터리 링의 지름.
  final double size;

  /// [thickness] : 배터리 링의 두께. 오라 계산에 사용된다.
  final double thickness;

  /// 네온의 기본 색상.
  final Color glowColor;

  /// 회전 스윕 하이라이트 색상.
  final Color highlight;

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

/// 두 개의 애니메이션 컨트롤러를 사용한다:
/// - [_rot]   : 2600ms 주기로 회전하는 스윕 하이라이트
/// - [_pulse] : 1600ms 왕복하며 네온 밝기와 리플 크기를 조절
class _MagSafeAuraState extends State<MagSafeAura>
    with TickerProviderStateMixin {
  late final AnimationController _rot;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _rot = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(); // 계속 회전

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true); // 앞뒤로 왕복
  }

  @override
  void dispose() {
    _rot.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 네온이 퍼질 최대 반경 (링 외곽에서 조금 더 넓게)
    final outer = widget.size * 0.5 + widget.thickness * 0.9;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rot, _pulse]),
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none, // 오라가 잘리지 않도록
            children: [
              // -------- 부드러운 바깥 네온 --------
              _SoftGlow(
                size: widget.size,
                maxRadius: outer,
                color:
                    widget.glowColor.withOpacity(0.55 + _pulse.value * 0.15),
              ),
              // -------- 리플 세 개 --------
              _Ripples(
                size: widget.size,
                baseRadius: widget.size * 0.5 + widget.thickness * 0.2,
                spread: widget.thickness * 1.8,
                color: widget.glowColor,
                t: _pulse.value,
              ),
              // -------- 회전하는 스윕 하이라이트 --------
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

/// 바깥으로 퍼지는 부드러운 네온 효과
class _SoftGlow extends StatelessWidget {
  final double size;
  final double maxRadius;
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
        boxShadow: [
          // 안쪽에서부터 점점 흐려지도록 두 겹의 그림자 사용
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

/// 링 바깥으로 확산되는 동심원 리플
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

/// 실제 리플 원을 그리는 페인터
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
    final center = Offset(size.width / 2, size.height / 2);
    // 서로 다른 위상으로 3개의 원을 그린다.
    for (int i = 0; i < 3; i++) {
      final ph = (t + i / 3) % 1.0; // 0~1 사이 진행도
      final radius = baseRadius + spread * ph;
      final opacity = (1.0 - ph) * 0.35;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withOpacity(opacity.clamp(0, 1));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter o) =>
      o.t != t ||
      o.baseRadius != baseRadius ||
      o.spread != spread ||
      o.color != color;
}

/// 회전하면서 지나가는 짧은 하이라이트
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
    // 전체 링의 약 18% 길이만큼만 밝게 표현
    const sweep = 2 * math.pi * 0.18;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: ringRadius,
    );
    // 양 끝이 투명하고 가운데가 가장 밝은 그라데이션
    final shader = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + sweep,
      colors: [
        Colors.transparent,
        color.withOpacity(0.9),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 1.0],
    ).createShader(rect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = ringThickness
      ..shader = shader;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SweepHighlightPainter o) =>
      o.ringRadius != ringRadius ||
      o.ringThickness != ringThickness ||
      o.color != color;
}
