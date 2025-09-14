import 'package:flutter/material.dart';

import 'charging_ring.dart'; // 기존 배터리 링
import 'mag_safe_aura.dart'; // 방금 만든 오라 위젯

/// ChargingRing 위에 MagSafe 스타일 오라를 겹쳐주는 래퍼 위젯
///
/// - [charging]이 true일 때만 오라 효과를 보여준다.
/// - 기존 ChargingRing의 `charging` 옵션은 false로 두어
///   AvatarGlow와 중복되지 않도록 한다.
class MagSafeChargingRing extends StatelessWidget {
  final double percent;    // 배터리 퍼센트(0~1)
  final bool charging;     // 충전 중 여부
  final double size;       // 링 지름
  final double thickness;  // 링 두께
  final double labelFont;  // 중앙 글자 크기

  const MagSafeChargingRing({
    super.key,
    required this.percent,
    required this.charging,
    required this.size,
    required this.thickness,
    required this.labelFont,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // 충전 중일 때만 오라를 뒤에 깔아준다
        if (charging)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: MagSafeAura(
                  size: size,
                  thickness: thickness,
                  glowColor: const Color(0xFFEFFF7A),
                  highlight: const Color(0xFF8AE66E),
                ),
              ),
            ),
          ),
        // 실제 배터리 링은 항상 표시
        ChargingRing(
          percent: percent,
          charging: false, // 자체 glow는 비활성화
          size: size,
          thickness: thickness,
          labelFont: labelFont,
        ),
      ],
    );
  }
}
