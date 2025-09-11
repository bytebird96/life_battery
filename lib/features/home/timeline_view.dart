import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../../core/time.dart';

/// 하루 타임라인 뷰
class TimelineView extends StatelessWidget {
  final Map<DateTime, double> data;
  final UserSettings settings;
  const TimelineView({super.key, required this.data, required this.settings});

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
    final minutes = end.difference(start).inMinutes;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: Row(
              children: List.generate(minutes, (i) {
                final t = start.add(Duration(minutes: i));
                // 이벤트 색상 찾기
                return Expanded(
                  child: Container(color: Colors.grey.shade300),
                );
              }),
            ),
          ),
        )
      ],
    );
  }
}
