import 'package:flutter/material.dart';

/// 원형 배터리 게이지
class BatteryGauge extends StatelessWidget {
  final double percent; // 0~1
  const BatteryGauge({super.key, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: percent,
                strokeWidth: 12,
              ),
              Text('${(percent * 100).toStringAsFixed(1)}%'),
            ],
          ),
        ),
      ],
    );
  }
}
