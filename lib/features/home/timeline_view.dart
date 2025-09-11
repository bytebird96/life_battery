import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../../core/time.dart';
import '../../core/compute.dart'; // resolveIntervals 사용

/// 하루 타임라인 뷰
class TimelineView extends StatelessWidget {
  final Map<DateTime, double> data; // 시뮬레이션 결과
  final UserSettings settings; // 사용자 설정
  final List<Event> events; // 오늘 이벤트 목록
  const TimelineView(
      {super.key, required this.data, required this.settings, required this.events});

  Color colorFor(EventType? t) {
    switch (t) {
      case EventType.sleep:
        return Colors.blue;
      case EventType.rest:
        return Colors.green;
      case EventType.work:
        return Colors.red;
      case EventType.neutral:
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = todayStart(DateTime.now(), settings.dayStart);
    final end = start.add(const Duration(days: 1));
    final minutes = end.difference(start).inMinutes; // 하루 총 분수
    // 이벤트들을 우선순위 기준으로 구간 분해
    final intervals = resolveIntervals(events);

    return LayoutBuilder(builder: (context, constraints) {
      final widthPerMin = constraints.maxWidth / minutes;
      final nowIndex = DateTime.now().difference(start).inMinutes;

      return Stack(
        children: [
          Row(
            children: List.generate(minutes, (i) {
              final t = start.add(Duration(minutes: i));
              // 해당 분에 적용되는 이벤트 찾기
              final interval = intervals.firstWhere(
                  (it) => !t.isBefore(it.start) && t.isBefore(it.end),
                  orElse: () => Interval(start: t, end: t));
              final color = colorFor(interval.top?.type);
              return Container(width: widthPerMin, color: color);
            }),
          ),
          // 현재 시각 위치 표시
          Positioned(
              left: widthPerMin * nowIndex,
              top: 0,
              bottom: 0,
              child: Container(width: 2, color: Colors.black)),
        ],
      );
    });
  }
}
