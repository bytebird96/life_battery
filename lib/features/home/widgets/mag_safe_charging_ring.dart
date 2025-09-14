import 'package:flutter/material.dart';
import 'charging_ring.dart';
import 'mag_safe_aura.dart';

class MagSafeChargingRing extends StatelessWidget {
  final double percent;
  final bool charging;
  final double size;
  final double thickness;
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
      clipBehavior: Clip.none,
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
