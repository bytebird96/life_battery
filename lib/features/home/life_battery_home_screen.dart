import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories.dart'; // 일정 목록을 가져오기 위해 리포지토리 참조
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
/// 리포지토리에 저장된 이벤트 리스트를 불러와
/// 초보자도 이해하기 쉽도록 제목과 시간을 단순 텍스트로 표시한다.
class _TaskList extends ConsumerWidget {
  const _TaskList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 리포지토리에서 현재 저장된 일정 목록을 조회
    final events = ref.watch(repositoryProvider).events;

    // 일정이 하나도 없다면 안내 문구 출력
    if (events.isEmpty) {
      return const Center(child: Text('등록된 일정이 없습니다.'));
    }

    return ListView.separated(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final e = events[index];
        // 시작/종료 시각을 "HH:mm" 형식의 문자열로 변환
        final start =
            '${e.startAt.hour.toString().padLeft(2, '0')}:${e.startAt.minute.toString().padLeft(2, '0')}';
        final end =
            '${e.endAt.hour.toString().padLeft(2, '0')}:${e.endAt.minute.toString().padLeft(2, '0')}';

        return ListTile(
          title: Text(e.title),
          subtitle: Text('$start - $end'),
        );
      },
      // 각 항목 사이를 구분하기 위한 가는 선
      separatorBuilder: (_, __) => const Divider(height: 1),
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

