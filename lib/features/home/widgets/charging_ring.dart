import 'package:flutter/material.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:avatar_glow/avatar_glow.dart' as glow; // 글로우 효과 패키지

/// --------------------------------------------------------------
/// 배터리 잔량을 원형 게이지로 보여주는 위젯
/// --------------------------------------------------------------
/// [percent]
///   - 0.0~1.0 범위의 배터리 잔량 값을 받는다.
/// [charging]
///   - true이면 네온 글로우 효과를 적용하여 "충전 중" 상태를 표현한다.
/// [size]
///   - 외부에서 전달받은 전체 크기. 스케일 헬퍼로 계산된 값을 넣는다.
/// [thickness]
///   - 링의 두께. [size] 비율로 맞춰진 값을 사용하면 된다.
/// [labelFont]
///   - 중앙 퍼센트 텍스트의 글자 크기.
///
/// 초보자도 이해하기 쉽도록 각 매개변수와 동작을 상세히 주석으로 남겼다.
class ChargingRing extends StatelessWidget {
  final double percent; // 0~1 사이의 배터리 잔량
  final bool charging; // 충전 중 여부
  final double size; // 전체 지름
  final double thickness; // 링 두께
  final double labelFont; // 중앙 글자 크기

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
    // 0~1 값을 0~100 범위의 숫자로 변환
    final value = (percent.clamp(0.0, 1.0) * 100);

    // SleekCircularSlider는 기본적으로 조작 가능한 슬라이더이므로
    // IgnorePointer로 감싸서 읽기 전용 게이지로 사용한다.
    final ring = SizedBox(
      width: size,
      height: size,
      child: IgnorePointer(
        // SleekCircularSlider를 사용해 진행률 원형 링 구성
        child: SleekCircularSlider(
          min: 0,
          max: 100,
          initialValue: value,
          appearance: CircularSliderAppearance(
            size: size, // 전체 크기
            startAngle: 270, // 12시 방향에서 시작
            angleRange: 360, // 전체 원 사용
            customWidths: CustomSliderWidths(
              progressBarWidth: thickness, // 진행 링 두께
              trackWidth: thickness, // 배경 링 두께
              handlerSize: 0, // 손잡이 숨김
            ),
            customColors: const CustomSliderColors(
              trackColor: Color(0xFFE9E8FF), // 배경 트랙 색상
              progressBarColors: [
                Color(0xFFC8B6FF), // 진행 시작 색(연보라)
                Color(0xFF5B2EFF), // 진행 끝 색(보라)
              ],
              dotColor: Colors.transparent, // 손잡이 점 제거
            ),
            infoProperties: InfoProperties(
              modifier: (v) => '${v.round()}%', // 중앙 텍스트 포맷
              mainLabelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: labelFont, // 전달받은 글자 크기
                letterSpacing: 0.5,
                color: const Color(0xFF111118),
              ),
            ),
          ),
        ),
      ),
    );

    // 충전 중이 아니면 단순 링만 반환
    if (!charging) return ring;

    // 충전 중이라면 빛나는 네온 효과를 추가
    return glow.AvatarGlow(
      glowColor: const Color(0xFFEFFF7A), // 노란빛 글로우
      radius: size * 0.66, // 3.x 버전부터 endRadius 대신 radius 사용
      duration: const Duration(milliseconds: 1600), // 애니메이션 주기
      repeat: true, // 반복 여부
      child: ring, // 글로우 안에 배터리 링 배치
    );
  }
}
