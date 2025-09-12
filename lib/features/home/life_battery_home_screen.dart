import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'battery_controller.dart';

/// 원형 배터리 게이지를 그리는 홈 화면
///
/// 기존 홈 화면은 일정 목록 등 많은 기능을 담고 있지만,
/// 여기서는 제공된 디자인처럼 단순한 배터리 게이지만 보여준다.
class LifeBatteryHomeScreen extends ConsumerWidget {
  const LifeBatteryHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 배터리 퍼센트(0~100)를 상태관리에서 읽어온다.
    final percent = ref.watch(batteryControllerProvider) / 100;

    return Scaffold(
      // AppBar 대신 상단에 텍스트만 배치하기 위해 투명 처리
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Life Battery',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: Center(
        // 중앙의 원형 게이지
        child: _CircularBattery(percent: percent),
      ),
      // 중앙 하단의 + 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // 하단 탭바 영역
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 왼쪽 시계 아이콘
                  IconButton(
                    icon: const Icon(Icons.access_time_outlined),
                    onPressed: () {},
                  ),
                  // 오른쪽 파이차트 아이콘
                  IconButton(
                    icon: const Icon(Icons.pie_chart_outline),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          // 아이폰 홈 인디케이터처럼 보이는 회색 바
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            width: 135,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ],
      ),
    );
  }
}

/// 배터리 퍼센트를 원형으로 그려주는 위젯
class _CircularBattery extends StatelessWidget {
  final double percent; // 0~1 사이의 값

  const _CircularBattery({required this.percent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 연한 배경 원
          CustomPaint(
            size: const Size(220, 220),
            painter: _CirclePainter(
              progress: 1,
              color: Colors.purple.withOpacity(0.1),
            ),
          ),
          // 실제 퍼센트만큼 칠해지는 원
          CustomPaint(
            size: const Size(220, 220),
            painter: _CirclePainter(
              progress: percent,
              color: Colors.purple,
            ),
          ),
          // 중앙에 퍼센트 텍스트 표시
          Text(
            '${(percent * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 40,
            ),
          ),
        ],
      ),
    );
  }
}

/// 원형 진행률을 그려주는 커스텀 페인터
class _CirclePainter extends CustomPainter {
  final double progress; // 0~1 사이 진행률
  final Color color; // 선 색상

  _CirclePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 20.0; // 선의 두께
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - strokeWidth / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round; // 끝을 둥글게 처리

    // -pi/2 부터 시작해서 progress 비율만큼 그린다 (12시 방향 기준)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CirclePainter oldDelegate) {
    // progress 또는 color가 변경되면 다시 그린다
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

