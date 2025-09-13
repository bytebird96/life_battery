import 'dart:math'; // 수학 관련 함수와 상수를 사용하기 위해 불러옴
import 'package:flutter/material.dart';

/// --------------------------------------------------------------
/// 원형 배터리 위젯
/// --------------------------------------------------------------
/// [percent]
///   - 배터리 잔량(0.0~1.0)을 의미합니다.
/// [charging]
///   - true이면 번쩍이는 네온과 회전 애니메이션으로
///     "충전 중" 상태를 표현합니다.
class CircularBattery extends StatefulWidget {
  final double percent; // 0~1 범위의 배터리 잔량
  final bool charging; // 충전 중인지 여부

  const CircularBattery({
    Key? key,
    required this.percent,
    this.charging = false,
  }) : super(key: key);

  /// 게이지의 고정 크기
  static const double _gaugeSize = 154;

  @override
  State<CircularBattery> createState() => _CircularBatteryState();
}

/// 실제 애니메이션과 그리기 로직을 담당하는 State 클래스
class _CircularBatteryState extends State<CircularBattery>
    with TickerProviderStateMixin {
  late final AnimationController _glowController; // 바깥 네온 효과용 컨트롤러
  late final AnimationController _rotationController; // 회전 애니메이션용 컨트롤러

  @override
  void initState() {
    super.initState();
    // 애니메이션 컨트롤러 초기화
    _glowController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _rotationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 6));

    // 처음부터 charging이 true라면 애니메이션 시작
    if (widget.charging) {
      _glowController.repeat(reverse: true); // 밝아졌다 어두워지기 반복
      _rotationController.repeat(); // 계속 회전
    }
  }

  @override
  void didUpdateWidget(covariant CircularBattery old) {
    super.didUpdateWidget(old);
    // 외부에서 charging 값이 바뀔 때 애니메이션을 켜거나 끔
    if (widget.charging && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
      _rotationController.repeat();
    } else if (!widget.charging && _glowController.isAnimating) {
      _glowController.stop();
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 네온 효과의 투명도. _glowController의 값(0~1)에 따라 0.22~0.50 사이로 변화
    final glowOpacity = 0.22 + _glowController.value * 0.28;

    // 게이지 관련 기본 값 설정
    final size = CircularBattery._gaugeSize;
    const stroke = 12.0; // 트랙/프로그레스 두께
    final progress = widget.percent.clamp(0.0, 1.0); // 0~1 범위를 벗어나지 않도록 보정

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1) 바깥 네온 글로우 (충전 중일 때만 표시)
          if (widget.charging)
            CustomPaint(
              size: Size(size, size),
              painter: _GlowRingPainter(
                strokeWidth: stroke + 6, // 테두리 근처에서 퍼지게
                color: const Color(0xFFEFFF7A), // 연한 라임/옐로우
                sigma: 28, // 번짐 정도
                opacity: glowOpacity,
              ),
            ),

          // 2) 트랙(배경색)
          CustomPaint(
            size: Size(size, size),
            painter: _TrackRingPainter(
              color: const Color(0xFFE9E8FF), // 매우 연한 보라색
              strokeWidth: stroke,
            ),
          ),

          // 3) 진행 링(배터리 잔량을 나타내는 부분)
          CustomPaint(
            size: Size(size, size),
            painter: _ProgressRingPainter(
              progress: progress,
              strokeWidth: stroke,
              startColor: const Color(0xFFC8B6FF), // 시작 색(연한 보라)
              endColor: const Color(0xFF5B2EFF), // 끝 색(진한 보라)
            ),
          ),

          // 4) 진행 끝부분의 둥근 캡. 진행 링 끝을 자연스럽게 보이게 함
          if (progress > 0)
            CustomPaint(
              size: Size(size, size),
              painter: _HeadCapPainter(
                progress: progress,
                radius: stroke * 0.55,
                color: const Color(0xFF5B2EFF),
              ),
            ),

          // 5) 중앙의 퍼센트 라벨
          widget.charging
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 28)),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        letterSpacing: 0.5,
                        color: Color(0xFF111118),
                      ),
                    ),
                  ],
                )
              : Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                    letterSpacing: 0.5,
                    color: Color(0xFF111118),
                  ),
                ),
        ],
      ),
    );
  }
}

// ======================= Painter 클래스들 =======================

/// 바깥 네온 효과를 그리는 페인터
/// stroke + MaskFilter.blur를 활용하여 바깥쪽으로 퍼지는 빛을 표현
class _GlowRingPainter extends CustomPainter {
  final double strokeWidth; // 선의 두께
  final Color color; // 네온 색상
  final double sigma; // blur 강도
  final double opacity; // 투명도(애니메이션으로 조절)

  _GlowRingPainter({
    required this.strokeWidth,
    required this.color,
    required this.sigma,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 원의 중심과 반지름 계산
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - strokeWidth / 2;

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withOpacity(opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 24);

    canvas.drawCircle(c, r, p); // 원 그리기
  }

  @override
  bool shouldRepaint(_GlowRingPainter o) =>
      o.opacity != opacity || o.strokeWidth != strokeWidth || o.color != color;
}

/// 트랙(배경 링)을 그리는 페인터
class _TrackRingPainter extends CustomPainter {
  final Color color; // 트랙 색상
  final double strokeWidth; // 트랙 두께

  _TrackRingPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - strokeWidth / 2;

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(c, r, p);
  }

  @override
  bool shouldRepaint(_TrackRingPainter o) =>
      o.color != color || o.strokeWidth != strokeWidth;
}

/// 진행 링을 그리는 페인터: SweepGradient와 투명 마스킹 사용
class _ProgressRingPainter extends CustomPainter {
  final double progress; // 0~1 범위의 진행률
  final double strokeWidth; // 선 두께
  final Color startColor; // 시작 색상
  final Color endColor; // 끝 색상

  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.startColor,
    required this.endColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    // progress 이후는 투명하게 처리해 잘라낸 듯한 효과 연출
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + 2 * pi,
        tileMode: TileMode.decal, // 영역 밖은 그리지 않음
        stops: [
          0.0,
          progress.clamp(0.0001, 0.9999),
          progress.clamp(0.0001, 0.9999) + 0.0001, // 절단선 부드럽게 만들기
        ],
        colors: [
          startColor,
          endColor,
          Colors.transparent,
        ],
      ).createShader(rect);

    // 원 전체를 그리되 shader에서 투명하게 잘라내므로
    // 실제 화면에서는 진행률만큼의 호(arc)만 보이게 된다.
    canvas.drawArc(rect, -pi / 2, 2 * pi, false, p);
  }

  @override
  bool shouldRepaint(_ProgressRingPainter o) =>
      o.progress != progress ||
      o.strokeWidth != strokeWidth ||
      o.startColor != startColor ||
      o.endColor != endColor;
}

/// 진행 끝의 작은 동그라미(캡)를 그려 더 매끈하게 보이도록 하는 페인터
class _HeadCapPainter extends CustomPainter {
  final double progress; // 0~1 진행률
  final double radius; // 점의 반지름
  final Color color; // 점 색상

  _HeadCapPainter({
    required this.progress,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = radius * 2;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - strokeWidth / 2;

    // 진행률에 따른 각도를 계산하여 원 위의 위치를 구함
    final angle = -pi / 2 + 2 * pi * progress;
    final pos = Offset(c.dx + r * cos(angle), c.dy + r * sin(angle));

    final p = Paint()..color = color;
    canvas.drawCircle(pos, radius, p); // 작은 원을 그려 캡 표현
  }

  @override
  bool shouldRepaint(_HeadCapPainter o) =>
      o.progress != progress || o.radius != radius || o.color != color;
}
