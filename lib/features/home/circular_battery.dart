import 'package:flutter/material.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:avatar_glow/avatar_glow.dart';

/// --------------------------------------------------------------
/// 원형 배터리 위젯
/// --------------------------------------------------------------
/// [percent]
///   - 0.0~1.0 범위의 배터리 잔량을 전달한다.
/// [charging]
///   - true일 때만 바깥쪽에 AvatarGlow 네온 효과를 보여
///     "충전 중"임을 시각적으로 표현한다.
///
/// 초보자도 쉽게 재사용할 수 있도록 StatelessWidget으로 작성하였다.
class CircularBattery extends StatelessWidget {
  final double percent;   // 0~1 사이의 배터리 잔량
  final bool charging;    // 충전 중 여부

  const CircularBattery({
    super.key,
    required this.percent,
    this.charging = false,
  });

  /// 위젯의 고정 크기(가로/세로 154px)
  static const double size = 154;

  @override
  Widget build(BuildContext context) {
    // 0~1 값을 0~100 범위의 숫자로 변환한다.
    final value = (percent.clamp(0.0, 1.0) * 100);

    // SleekCircularSlider는 기본적으로 사용자가 조작할 수 있는 슬라이더다.
    // IgnorePointer로 감싸 상호작용을 막아 단순 게이지처럼 사용한다.
    final gauge = SizedBox(
      width: size,
      height: size,
      child: IgnorePointer(
        child: SleekCircularSlider(
          min: 0,
          max: 100,
          initialValue: value,
          onChange: null, // 콜백이 필요 없는 읽기 전용 슬라이더
          appearance: CircularSliderAppearance(
            size: size,               // 전체 크기
            startAngle: 270,          // 12시 방향에서 시작
            angleRange: 360,          // 전체 원을 사용
            customWidths: CustomSliderWidths(
              progressBarWidth: 12,   // 진행 링 두께
              trackWidth: 12,         // 트랙(배경) 두께
              handlerSize: 0,         // 손잡이 숨김
            ),
            customColors: CustomSliderColors(
              progressBarColors: const [
                Color(0xFFC8B6FF),    // 진행 링 시작 색(연보라)
                Color(0xFF5B2EFF),    // 진행 링 끝 색(진보라)
              ],
              trackColor: const Color(0xFFE9E8FF), // 트랙 색(연한 보라)
              dotColor: Colors.transparent,        // 손잡이 점을 보이지 않게
            ),
            infoProperties: InfoProperties(
              // 중앙에 현재 퍼센트를 정수%로 표시
              modifier: (double v) => '${v.toStringAsFixed(0)}%',
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

    // charging이 true라면 AvatarGlow로 네온 효과를 준다.
    if (charging) {
      return AvatarGlow(
        glowColor: const Color(0xFFEFFF7A),        // 네온 색상
        endRadius: size * 0.66,                    // 네온의 최대 반경
        duration: const Duration(milliseconds: 1600), // 애니메이션 길이
        repeat: true,                              // 계속 반복
        child: gauge,
      );
    }

    // 충전 중이 아니라면 단순히 게이지만 반환
    return gauge;
  }
}
