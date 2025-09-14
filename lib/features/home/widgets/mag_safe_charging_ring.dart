import 'package:flutter/material.dart';
import 'charging_ring.dart';
import 'mag_safe_aura.dart';
import 'ring_geometry.dart';

class MagSafeChargingRing extends StatelessWidget {
  final double percent;    // 0~1
  final bool charging;     // 충전 여부
  final double size;       // 지름
  final double thickness;  // 두께
  final double labelFont;  // 기본 퍼센트 폰트(비충전시)

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
    final p = percent.clamp(0.0, 1.0);
    // 한 번 계산한 링 지오메트리를 두 painter에 공유하여 좌표계를 통일
    final ring = RingGeometry(size, thickness);

    // 중앙 콘텐츠 구성
    final Widget? center = charging
        ? Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.bolt_rounded,
          size: size * 0.24,
          color: const Color(0xFF34C759),
        ),
        SizedBox(height: size * 0.04),
        Text(
          '${(p * 100).round()}%',
          // 충전 중엔 폰트 40%로 축소
          style: TextStyle(
            fontSize: labelFont * 0.4,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0B0C10),
          ),
        ),
      ],
    )
        : null; // 비충전: ChargingRing의 기본 퍼센트 텍스트 사용

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (charging)
          IgnorePointer(
            child: MagSafeAura(
              ring: ring,
              glowColor: const Color(0x9934C759),
              highlight: const Color(0xFF34C759),
              // MagSafeAura에서 번개 아이콘을 숨겨 중복되는 표시를 방지
              showBolt: false,
            ),
          ),
        ChargingRing(
          percent: p,
          ring: ring,
          labelFont: labelFont,
          center: center, // 중앙은 여기서만 그린다 (중복 X)

          // 색상: 비충전(보라 그라데이션) / 충전(녹색 단색)
          trackColor: charging
              ? const Color(0xFFE6E8ED)
              : const Color(0xFFE9E8FF),
          progressStart: charging
              ? const Color(0xFF34C759)
              : const Color(0xFFC8B6FF),
          progressEnd: charging
              ? const Color(0xFF34C759) // start=end → 단색 효과
              : const Color(0xFF5B2EFF),
        ),
      ],
    );
  }
}
