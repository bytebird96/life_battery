import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'battery_controller.dart';
import 'widgets/life_tab_bar.dart'; // 하단 탭바 위젯

/// HTML/CSS로 전달된 템플릿을 Flutter로 옮긴 홈 화면
///
/// 상단의 시스템 상태바, "Life Battery" 제목, 중앙의 원형 배터리 게이지,
/// 하단의 커스텀 탭바로 구성되어 있다. 일정 목록 등 추가 기능은 제외하고
/// 템플릿 레이아웃을 그대로 재현하는 데 초점을 맞췄다.
class LifeBatteryHomeScreen extends ConsumerWidget {
  const LifeBatteryHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 배터리 퍼센트(0~100)를 상태관리에서 읽어와 0~1 범위로 변환
    final percent = ref.watch(batteryControllerProvider) / 100;

    return Scaffold(
      backgroundColor: Colors.white,
      // Scaffold의 기본 여백을 제거하여 전체 화면을 완전히 사용한다.
      body: Center(
        // 디자인 시안이 375x812 크기를 기준으로 하므로 SizedBox로 감싼다.
        child: SizedBox(
          width: 375,
          height: 812,
          child: Stack(
            children: [
              // 1) 상단 시스템 상태바
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _SystemStatusBar(),
              ),
              // 2) 화면 제목 "Life Battery"
              const Positioned(
                top: 64,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Life Battery',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              // 3) 중앙의 원형 배터리 게이지 (220x220 크기)
              Positioned(
                top: 129,
                left: 0,
                right: 0,
                child: Center(
                  child: _CircularBattery(percent: percent),
                ),
              ),
              // 4) 하단 탭바 위치 (좌우 여백 40, 하단 8)
              Positioned(
                left: 40,
                right: 40,
                bottom: 8,
                child: LifeTabBar(
                  onAdd: () async {
                    // + 버튼을 누르면 일정 추가 화면으로 이동한다.
                    await Navigator.pushNamed(context, '/event');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 상단 상태바 영역을 그리는 위젯
///
/// 시간, 위치 아이콘, 통신/와이파이/배터리 아이콘을 배치하여
/// 실제 모바일 기기의 상태바처럼 보이도록 구현하였다.
class _SystemStatusBar extends StatelessWidget {
  const _SystemStatusBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        // 좌우 여백은 21px, 상단 여백은 13px 정도로 시안을 맞춘다.
        padding: const EdgeInsets.fromLTRB(21, 13, 21, 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 왼쪽: 시간 텍스트와 위치 아이콘
            Row(
              children: const [
                Text(
                  '12:22',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: Color(0xFF070417),
                    letterSpacing: -0.24,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.location_on_outlined,
                    size: 16, color: Color(0xFF070417)),
              ],
            ),
            // 오른쪽: 통신, 와이파이, 배터리 아이콘 순서대로 배치
            Row(
              children: const [
                Icon(Icons.signal_cellular_alt, size: 20),
                SizedBox(width: 4),
                Icon(Icons.wifi, size: 20),
                SizedBox(width: 4),
                Icon(Icons.battery_full, size: 20),
              ],
            ),
          ],
        ),
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
    // 디자인 시안과 동일하게 220x220 크기의 원형 게이지를 사용한다.
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 연한 배경 원 (전체 100%)
          CustomPaint(
            size: const Size(220, 220),
            painter: _CirclePainter(
              progress: 1,
              color: const Color(0xFFEAE6FF), // 옅은 보라색
            ),
          ),
          // 실제 퍼센트만큼 채워지는 보라색 원호
          CustomPaint(
            size: const Size(220, 220),
            painter: _CirclePainter(
              progress: percent,
              color: const Color(0xFF9B51E0), // 진한 보라색
            ),
          ),
          // 중앙에 퍼센트 텍스트 표시
          Text(
            '${(percent * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 40,
              letterSpacing: 2, // 디자인에서 사용된 자간
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
    const strokeWidth = 16.0; // 선의 두께 (디자인 시안과 동일)
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

