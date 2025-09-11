import 'package:flutter/material.dart';

/// 직사각형 배터리 게이지
///
/// 기존의 원형 게이지 대신 일반 스마트폰에서 보는
/// 배터리 모양을 그대로 그려주는 위젯입니다.
/// [percent]는 0.0~1.0 범위의 배터리 비율입니다.
class BatteryGauge extends StatelessWidget {
  final double percent; // 0~1 사이 값
  final String? label; // 우측에 붙는 짧은 텍스트 (예: ML, AR)
  final Color labelColor; // 라벨 배경색

  const BatteryGauge({
    super.key,
    required this.percent,
    this.label,
    this.labelColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    // 전체 배터리 너비와 높이
    const double width = 120;
    const double height = 40;
    const double borderWidth = 3;

    // 현재 배터리 충전량에 따라 색상을 결정
    final Color fillColor =
        percent >= 0.5 ? Colors.green : Colors.red;

    // 배터리 내부에 채워질 너비 (테두리 고려)
    final double fillWidth =
        (width - borderWidth * 2) * percent.clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 번개 아이콘으로 배터리 컨셉 표현
        const Icon(Icons.bolt, color: Colors.amber),
        const SizedBox(width: 8),
        // 배터리 본체를 그리기 위해 Stack 사용
        Stack(
          children: [
            // 배터리 외곽 테두리
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: borderWidth),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // 배터리 끝의 작은 돌출부(캡)
            Positioned(
              right: -8,
              top: height / 4,
              bottom: height / 4,
              child: Container(
                width: 8,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 실제 충전량을 나타내는 컬러 박스
            Positioned(
              left: borderWidth,
              top: borderWidth,
              bottom: borderWidth,
              child: Container(
                width: fillWidth,
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        // 배터리 퍼센트 텍스트
        Text(
          '${(percent * 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (label != null) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: labelColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label!,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}
