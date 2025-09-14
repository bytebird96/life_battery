import 'package:flutter/material.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:avatar_glow/avatar_glow.dart';

/// --------------------------------------------------------------
/// 배터리 잔량을 원형 게이지로 보여주는 위젯
/// --------------------------------------------------------------
/// [percent]
///   - 0.0~1.0 범위의 배터리 잔량 값을 받는다.
/// [charging]
///   - true이면 AvatarGlow 네온 효과를 사용하여 "충전 중"임을 표현한다.
///
/// 초보자도 쉽게 사용할 수 있도록 StatelessWidget으로 작성하였다.
class ChargingRing extends StatelessWidget {
  final double percent; // 0~1 사이의 배터리 잔량
  final bool charging;  // 충전 중 여부

  const ChargingRing({
    super.key,
    required this.percent,
    required this.charging,
  });

  /// 위젯의 고정 크기(가로/세로 154px)
  static const double size = 154;

  @override
  Widget build(BuildContext context) {
    // 0~1 값을 0~100 범위의 숫자로 변환
    final value = (percent.clamp(0.0, 1.0) * 100);

    // SleekCircularSlider는 기본적으로 조작 가능한 슬라이더이므로
    // IgnorePointer로 감싸서 읽기 전용 게이지로 사용한다.
    final ring = SizedBox(
      width: size,
      height: size,
      child: IgnorePointer(
        child: SleekCircularSlider(
          min: 0,
          max: 100,
          initialValue: value,
          appearance: CircularSliderAppearance(
            size: size,
            startAngle: 270, // 12시 방향에서 시작
            angleRange: 360, // 전체 원을 사용
            // 버전에 따라 animationEnabled 옵션이 없을 수도 있다.
            // 있으면 false로 두어 떨림을 방지한다.
            // animationEnabled: false,
            // 패키지에서 const 생성자를 제공하지 않으므로 const 제거
            customWidths: CustomSliderWidths(
              progressBarWidth: 12, // 진행 링 두께
              trackWidth: 12, // 배경 트랙 두께
              handlerSize: 0, // 손잡이 숨김
            ),
            customColors: CustomSliderColors(
              trackColor: const Color(0xFFE9E8FF),
              progressBarColors: const [
                Color(0xFFC8B6FF), // 진행 링 시작 색(연보라)
                Color(0xFF5B2EFF), // 진행 링 끝 색(보라)
              ],
              dotColor: Colors.transparent, // 손잡이 점 제거
            ),
            infoProperties: InfoProperties(
              // 중앙에 현재 퍼센트를 정수로 표시
              modifier: (v) => '${v.round()}%',
              mainLabelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 28,
                letterSpacing: 0.5,
                color: Color(0xFF111118),
              ),
            ),
          ),
        ),
      ),
    );

    // 충전 중이 아니면 단순 링만 반환
    if (!charging) return ring;

    // 충전 중이라면 빛나는 네온 효과를 추가
    return RepaintBoundary(
      child: AvatarGlow(
        glowColor: const Color(0xFFEFFF7A), // 네온 색상
        duration: const Duration(milliseconds: 1600), // 애니메이션 주기
        repeat: true, // 지속 반복
        // 패키지 3.x에서는 endRadius, showTwoGlows 파라미터가 제거되었다.
        // 기본 값으로도 충분한 크기의 글로우가 적용된다.
        child: ring, // 글로우 안에 배터리 링 배치
      ),
    );
  }
}
