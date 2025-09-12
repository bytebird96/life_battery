import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'battery_controller.dart';
import 'widgets/life_tab_bar.dart'; // 하단 탭바 위젯

/// HTML/CSS로 전달된 템플릿을 Flutter로 옮긴 홈 화면
///
/// "Life Battery" 제목, 중앙의 원형 배터리 게이지, 일정 목록,
/// 하단의 커스텀 탭바로 구성되어 있으며 템플릿 레이아웃을 재현했다.
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
              // 1) 화면 제목 "Life Battery"
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
              // 2) 중앙의 원형 배터리 게이지 (220x220 크기)
              Positioned(
                top: 129,
                left: 0,
                right: 0,
                child: Center(
                  child: _CircularBattery(percent: percent),
                ),
              ),
              // 3) 일정 목록 영역
              const Positioned(
                top: 360,
                left: 20,
                right: 20,
                bottom: 100, // 탭바와 겹치지 않도록 하단 여백 확보
                child: _TaskList(),
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

/// 일정 목록을 보여주는 위젯
///
/// 실제 데이터베이스 연동 대신 디자인 확인용 더미 데이터를 사용한다.
/// 한 항목은 "업무"라는 제목과 두 개의 태그, 그리고 진행 시간으로 구성된다.
class _TaskList extends StatelessWidget {
  const _TaskList();

  @override
  Widget build(BuildContext context) {
    // 화면에 보여줄 더미 테스크 목록. 추후 실제 데이터와 교체하면 된다.
    final tasks = [
      _Task(
        title: '업무',
        category: 'Work',
        project: 'Rasion Project',
        duration: '00:42:21',
      ),
    ];

    return ListView.separated(
      itemCount: tasks.length,
      itemBuilder: (context, index) => _TaskTile(task: tasks[index]),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
    );
  }
}

/// 하나의 테스크 정보를 담는 간단한 모델
class _Task {
  final String title; // 테스크 제목 (예: 업무)
  final String category; // 분류 태그 (예: Work)
  final String project; // 프로젝트 태그 (예: Rasion Project)
  final String duration; // 진행 시간 문자열

  _Task({
    required this.title,
    required this.category,
    required this.project,
    required this.duration,
  });
}

/// 디자인 시안과 동일한 형태로 테스크를 보여주는 위젯
class _TaskTile extends StatelessWidget {
  final _Task task;

  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA), // 연한 회색 배경
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 1) 왼쪽 모서리의 보라색 원과 모니터 아이콘
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF9B51E0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.computer, color: Colors.white),
          ),
          const SizedBox(width: 12),
          // 2) 제목과 태그들
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    // 우측 상단에 진행 시간 표시
                    Text(
                      task.duration,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _TagChip(
                      text: task.category,
                      color: const Color(0xFFFFE8EC), // 연한 분홍색 배경
                      textColor: const Color(0xFFF35D6A), // 분홍 글씨
                    ),
                    const SizedBox(width: 4),
                    _TagChip(
                      text: task.project,
                      color: const Color(0xFFF5F0FF), // 연한 보라색 배경
                      textColor: const Color(0xFF9B51E0), // 보라 글씨
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 3) 오른쪽 끝의 재생 아이콘
          const Icon(Icons.play_arrow, color: Colors.black26),
        ],
      ),
    );
  }
}

/// 태그 표시를 위한 작은 말풍선 모양 위젯
class _TagChip extends StatelessWidget {
  final String text; // 태그에 표시할 문자열
  final Color color; // 배경색
  final Color textColor; // 글자색

  const _TagChip({
    required this.text,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 12),
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

