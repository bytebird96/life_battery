import 'package:flutter/material.dart';
import 'charging_ring.dart';
import 'mag_safe_aura.dart';

/// MagSafe 스타일의 배터리 링 래퍼.
///
/// 충전 중이면 [MagSafeAura]를 배터리 링 뒤에 겹쳐서 네온/리플/회전
/// 스윕을 보여주고, 그렇지 않으면 [ChargingRing]만 표시한다.
class MagSafeChargingRing extends StatelessWidget {
  /// 0~1 사이의 진행률.
  final double percent;

  /// 충전 여부. `true`일 때만 오라를 보여준다.
  final bool charging;

  /// 링의 지름.
  final double size;

  /// 링의 두께.
  final double thickness;

  /// 퍼센트 텍스트 폰트 크기.
  final double labelFont;

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
      clipBehavior: Clip.none, // 오라가 밖으로 나가도록 잘라내지 않음
      children: [
        if (charging)
          IgnorePointer(
            child: MagSafeAura(
              size: size,
              thickness: thickness,
              glowColor: const Color(0xFFEFFF7A),
              highlight: const Color(0xFF8AE66E),
            ),
          ),
        ChargingRing(
          percent: percent,
          charging: false, // 내부 glow 미사용
          size: size,
          thickness: thickness,
          labelFont: labelFont,
        ),
      ],
    );
  }
}
