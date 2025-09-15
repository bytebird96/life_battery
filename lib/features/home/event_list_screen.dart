import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart'; // Event 모델
import '../../data/repositories.dart'; // 일정 저장소
import '../event/event_icons.dart'; // 일정 아이콘 옵션/헬퍼
import '../event/event_colors.dart'; // 일정 색상 옵션/헬퍼

/// 전체 일정 목록을 보여주는 화면
///
/// 홈 화면의 "See All"을 눌렀을 때 이동하며
/// 저장소에 있는 모든 일정을 한눈에 볼 수 있다.
class EventListScreen extends ConsumerWidget {
  const EventListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider); // 일정 데이터 접근

    return Scaffold(
      appBar: AppBar(
        title: const Text('전체 일정'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: repo.events.length,
        itemBuilder: (context, index) {
          final e = repo.events[index];
          final remain = e.endAt.difference(e.startAt); // 일정 전체 소요 시간
          final rate = _rateFor(e, repo); // 시간당 배터리 변화량 계산

          return _SimpleEventTile(
            event: e,
            remain: remain,
            rate: rate,
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
      ),
    );
  }

  /// 이벤트 종류에 따라 기본 배터리 증감률을 계산하는 헬퍼
  double _rateFor(Event e, AppRepository repo) {
    if (e.ratePerHour != null) {
      return e.ratePerHour!; // 일정에 직접 지정된 값 사용
    }

    switch (e.type) {
      case EventType.work:
        return -repo.settings.defaultDrainRate; // 작업은 배터리 소모
      case EventType.rest:
        return repo.settings.defaultRestRate; // 휴식은 조금 충전
      case EventType.sleep:
        return repo.settings.sleepChargeRate; // 수면은 많이 충전
      case EventType.neutral:
        return 0; // 중립은 변화 없음
    }
  }
}

/// 단순하게 일정을 보여주는 타일 위젯
///
/// 홈 화면의 타일에서 시작/중지 버튼만 제거한 형태로
/// 제목, 태그, 남은 시간, 배터리 변화를 표시한다.
class _SimpleEventTile extends StatelessWidget {
  final Event event; // 보여줄 일정 데이터
  final Duration remain; // 전체 혹은 남은 시간
  final double rate; // 시간당 배터리 변화량

  const _SimpleEventTile({
    required this.event,
    required this.remain,
    required this.rate,
  });

  @override
  Widget build(BuildContext context) {
    // 이벤트 종류를 태그 문자열로 변환
    final typeTag = event.type.name[0].toUpperCase() + event.type.name.substring(1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA), // 연한 배경색
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorFromName(event.colorName), // 사용자가 고른 색상을 배경으로 사용
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconDataFromName(event.iconName),
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    // 오른쪽에 남은 시간과 배터리 변화량 표기
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDuration(remain),
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${_batteryDelta(rate, remain)})',
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _TagChip(
                      text: typeTag,
                      color: const Color(0xFFFFE8EC),
                      textColor: const Color(0xFFF35D6A),
                    ),
                    const SizedBox(width: 4),
                    if (event.content != null && event.content!.isNotEmpty)
                      _TagChip(
                        text: event.content!,
                        color: const Color(0xFFF5F0FF),
                        textColor: const Color(0xFF9B51E0),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "HH:mm:ss" 형태로 Duration을 변환하는 유틸리티
  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// 남은 시간 동안 변화할 배터리 양을 "+1.0%" 형태로 반환
  String _batteryDelta(double rate, Duration remain) {
    final change = rate * remain.inSeconds / 3600; // 초당 변화량을 이용해 계산
    final sign = change > 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)}%';
  }
}

/// 태그 표시용 말풍선 위젯
class _TagChip extends StatelessWidget {
  final String text; // 태그 내용
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

