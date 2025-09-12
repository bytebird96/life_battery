import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'battery_controller.dart';
import '../../data/repositories.dart'; // 일정 더미 데이터를 사용하기 위한 리포지토리
import 'widgets/life_tab_bar.dart'; // 하단 탭바 위젯

/// 원형 배터리 게이지와 일정 목록을 함께 보여주는 홈 화면
///
/// 기존 `HomeScreen`에 있던 일정 목록 기능을 유지하면서도
/// 디자인 시안에 맞게 상단에 원형 게이지를 배치했다.
class LifeBatteryHomeScreen extends ConsumerWidget {
  const LifeBatteryHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 배터리 퍼센트(0~100)를 상태관리에서 읽어온다.
    final percent = ref.watch(batteryControllerProvider) / 100;
    // 리포지토리를 통해 더미 일정 목록에 접근한다.
    final repo = ref.watch(repositoryProvider);

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
      body: Column(
        children: [
          const SizedBox(height: 40),
          // 화면 상단 중앙의 원형 배터리 게이지
          _CircularBattery(percent: percent),
          const SizedBox(height: 24),
          // 아래에는 더미 일정 목록을 간단히 보여준다.
          // 실제 앱에서는 스와이프 삭제, 수정 등 다양한 기능이 있지만
          // 여기서는 제목만 보여주는 간단한 형태로 구현한다.
          Expanded(
            child: ListView.builder(
              itemCount: repo.events.length,
              itemBuilder: (context, index) {
                final e = repo.events[index];
                // ListTile 하나가 한 개의 일정을 나타낸다.
                return ListTile(
                  title: Text(e.title),
                  subtitle: Text('시작: '
                      '${e.startAt.hour.toString().padLeft(2, '0')}:${e.startAt.minute.toString().padLeft(2, '0')}'),
                );
              },
            ),
          ),
        ],
      ),
      // 하단 탭바 영역
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 실제 탭바 디자인을 별도 위젯으로 분리하여 재사용성을 높인다.
          // 가운데 + 버튼을 누르면 일정 추가 화면으로 이동한다.
          Padding(
            padding: const EdgeInsets.only(top: 0),
            child: Center(
              child: LifeTabBar(
                onAdd: () async {
                  await Navigator.pushNamed(context, '/event');
                },
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
    // 게이지 전체 크기를 지정한다. 디자인과 비슷한 200x200 정사각형
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 연한 배경 원 (전체 100%)
          CustomPaint(
            size: const Size(200, 200),
            painter: _CirclePainter(
              progress: 1,
              color: const Color(0xFFEAE6FF), // 옅은 보라색
            ),
          ),
          // 실제 퍼센트만큼 채워지는 보라색 원호
          CustomPaint(
            size: const Size(200, 200),
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
    const strokeWidth = 16.0; // 선의 두께 (디자인에 맞춰 얇게 조정)
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

