import 'dart:math' as math;
import 'package:flutter/material.dart';

/// MagSafe 스타일의 충전 오라 위젯
///
/// - 링 주변에 은은한 네온, 회전하는 스윕 하이라이트,
///   바깥으로 퍼지는 리플 효과를 동시에 표현한다.
/// - ChargingRing 위젯의 바깥쪽에 겹쳐서 사용한다.
class MagSafeAura extends StatefulWidget {
  final double size;       // 링 지름과 동일하게 사용
  final double thickness;  // 링 두께와 동일하게 사용
  final Color glowColor;   // 기본 네온 컬러 (연초록)
  final Color highlight;   // 회전 스윕 하이라이트 컬러

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

/// 애니메이션을 관리하는 State 클래스
class _MagSafeAuraState extends State<MagSafeAura>
    with TickerProviderStateMixin {
  late final AnimationController _rot;   // 회전 스윕 애니메이션
  late final AnimationController _pulse; // 네온/리플 펄스 애니메이션

  @override
  void initState() {
    super.initState();
    // 2.6초마다 한 바퀴 도는 회전 컨트롤러
    _rot = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    // 1.6초 주기로 밝기와 리플 크기를 변경
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    // 컨트롤러는 반드시 dispose 해준다
    _rot.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 오라 영역의 최대 반경 (링보다 살짝 크게)
    final outer = widget.size * 0.5 + widget.thickness * 0.9;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        // 두 애니메이션 값을 함께 감시하기 위해 AnimatedBuilder 사용
        child: AnimatedBuilder(
          animation: Listenable.merge([_rot, _pulse]),
          builder: (context, _) {
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 1) 부드러운 바깥 네온
                _SoftGlow(
                  size: widget.size,
                  maxRadius: outer,
                  color: widget.glowColor
                      .withOpacity(0.55 + _pulse.value * 0.15),
                ),
                // 2) 바깥으로 퍼지는 리플 3개
                _Ripples(
                  size: widget.size,
                  baseRadius: widget.size * 0.5 + widget.thickness * 0.2,
                  spread: widget.thickness * 1.8,
                  color: widget.glowColor,
                  t: _pulse.value,
                ),
                // 3) 회전하는 하이라이트 스윕
                Transform.rotate(
                  angle: _rot.value * 2 * math.pi, // 컨트롤러 값을 각도로 변환
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
      ),
    );
  }
}

// ------------------- 내부에서 사용하는 보조 위젯들 -------------------

/// 부드러운 바깥 네온 효과를 그리는 위젯
class _SoftGlow extends StatelessWidget {
  final double size;      // 중앙 원 크기
  final double maxRadius; // 네온이 퍼질 최대 반경
  final Color color;      // 네온 색상

  const _SoftGlow({
    required this.size,
    required this.maxRadius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final blur = maxRadius * 0.35; // 퍼짐 정도에 비례한 블러 값
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // BoxShadow를 여러 번 겹쳐 더 자연스러운 네온을 만든다
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

/// 바깥으로 퍼지는 리플 3개를 그리는 위젯
class _Ripples extends StatelessWidget {
  final double size;       // 기본 크기
  final double baseRadius; // 리플이 시작되는 반경
  final double spread;     // 리플이 퍼져나가는 거리
  final Color color;       // 리플 색상
  final double t;          // 애니메이션 진행도(0~1)

  const _Ripples({
    required this.size,
    required this.baseRadius,
    required this.spread,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size + spread * 2),
      painter: _RipplePainter(
        baseRadius: baseRadius,
        spread: spread,
        color: color,
        t: t,
      ),
    );
  }
}

/// 실제 리플 원형을 그리는 Painter
class _RipplePainter extends CustomPainter {
  final double baseRadius; // 리플 시작 반경
  final double spread;     // 리플이 퍼지는 최대 거리
  final Color color;       // 리플 색상
  final double t;          // 애니메이션 진행도(0~1)

  _RipplePainter({
    required this.baseRadius,
    required this.spread,
    required this.color,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2); // 중심점
    // 3개의 리플을 서로 다른 위상으로 그림
    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0; // 각 리플의 위상 차이
      final r = baseRadius + spread * phase; // 현재 반지름
      final opacity = (1.0 - phase) * 0.35; // 멀어질수록 점점 투명해짐
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withOpacity(opacity.clamp(0.0, 1.0));
      canvas.drawCircle(c, r, p); // 원 그리기
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) =>
      old.t != t ||
      old.baseRadius != baseRadius ||
      old.spread != spread ||
      old.color != color;
}

/// 회전하는 하이라이트 스윕(짧은 그라데이션 원호)을 그리는 Painter
class _SweepHighlightPainter extends CustomPainter {
  final double ringRadius;    // 링의 반지름
  final double ringThickness; // 링의 두께
  final Color color;          // 하이라이트 색상

  _SweepHighlightPainter({
    required this.ringRadius,
    required this.ringThickness,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: ringRadius,
    );
    // 스윕 길이 (원둘레의 약 18%)
    const sweep = 2 * math.pi * 0.18;
    final shader = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + sweep,
      colors: [
        Colors.transparent, // 시작은 투명
        color.withOpacity(0.90), // 중간은 가장 밝게
        color.withOpacity(0.00), // 끝에서 다시 투명
      ],
      stops: const [0.0, 0.4, 1.0],
    ).createShader(rect);

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round // 끝을 둥글게
      ..strokeWidth = ringThickness
      ..shader = shader;

    // -pi/2 위치(12시 방향)에서 시작해 sweep 만큼 아크를 그림
    canvas.drawArc(rect, -math.pi / 2, sweep, false, p);
  }

  @override
  bool shouldRepaint(covariant _SweepHighlightPainter old) =>
      old.ringRadius != ringRadius ||
      old.ringThickness != ringThickness ||
      old.color != color;
}
