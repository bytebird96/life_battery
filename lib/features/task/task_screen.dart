import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../event/edit_event_screen.dart';

/// 실행 중인 일정과 전체 일정을 보여주는 화면
///
/// - 하단 탭바의 왼쪽 시계 아이콘을 누르면 진입한다.
/// - 상단에는 현재 진행 중인 일정이 노출되며, 탭하면 수정 화면으로 이동한다.
/// - 하단에는 저장소에 있는 모든 일정 목록을 단순하게 표시한다.
class TaskScreen extends ConsumerStatefulWidget {
  const TaskScreen({super.key});

  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  Event? _runningEvent; // 현재 실행 중인 일정
  Duration _remain = Duration.zero; // 실행 중 일정의 남은 시간
  Timer? _timer; // 1초마다 남은 시간을 갱신할 타이머

  @override
  void initState() {
    super.initState();
    _loadRunning(); // 화면이 생성될 때 실행 중인 일정 정보를 불러온다.
  }

  @override
  void dispose() {
    _timer?.cancel(); // 타이머 해제
    super.dispose();
  }

  /// SharedPreferences에 저장된 실행 중인 일정 정보를 불러온다.
  Future<void> _loadRunning() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('taskId'); // 실행 중인 일정의 ID
    if (id == null) return; // 실행 중인 일정이 없다면 바로 종료

    final repo = ref.read(repositoryProvider); // 일정 저장소 접근
    try {
      _runningEvent = repo.events.firstWhere((e) => e.id == id);
    } catch (_) {
      return; // ID에 해당하는 일정이 없다면 아무 것도 하지 않음
    }

    final durationSec = prefs.getInt('duration') ?? 0; // 전체 예정 시간(초)
    final startMillis = prefs.getInt('startTime') ?? 0; // 시작 시각
    final elapsed =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - startMillis ~/ 1000;
    final remainSec = durationSec - elapsed; // 남은 초 계산

    if (remainSec > 0) {
      _remain = Duration(seconds: remainSec);
      // 1초마다 남은 시간을 줄여 화면을 갱신한다.
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remain.inSeconds <= 1) {
          setState(() => _remain = Duration.zero);
          _timer?.cancel();
        } else {
          setState(() => _remain -= const Duration(seconds: 1));
        }
      });
    }
    setState(() {}); // 초기 화면 갱신
  }

  /// 이벤트 종류에 따라 시간당 배터리 증감률을 반환한다.
  double _rateFor(Event e, AppRepository repo) {
    if (e.ratePerHour != null) return e.ratePerHour!;
    switch (e.type) {
      case EventType.work:
        return -repo.settings.defaultDrainRate;
      case EventType.rest:
        return repo.settings.defaultRestRate;
      case EventType.sleep:
        return repo.settings.sleepChargeRate;
      case EventType.neutral:
        return 0;
    }
  }

  /// "HH:mm:ss" 형태로 시간을 문자열로 변환한다.
  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider); // 일정 데이터 접근

    return Scaffold(
      appBar: AppBar(title: const Text('Task')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_runningEvent != null) ...[
              // 실행 중인 일정 표시 영역
              GestureDetector(
                onTap: () {
                  // 일정 영역을 탭하면 수정 화면으로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditEventScreen(event: _runningEvent!),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_arrow, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _runningEvent!.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _format(_remain),
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            // 전체 일정 목록
            Expanded(
              child: ListView.separated(
                itemCount: repo.events.length,
                itemBuilder: (context, index) {
                  final e = repo.events[index];
                  final remain = e.endAt.difference(e.startAt);
                  final rate = _rateFor(e, repo);
                  return _SimpleEventTile(event: e, remain: remain, rate: rate);
                },
                separatorBuilder: (_, __) => const SizedBox(height: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 간단한 일정 타일
///
/// - 제목, 태그, 남은 시간, 배터리 변화를 표시한다.
class _SimpleEventTile extends StatelessWidget {
  final Event event; // 보여줄 일정
  final Duration remain; // 전체 혹은 남은 시간
  final double rate; // 시간당 배터리 변화량

  const _SimpleEventTile(
      {required this.event, required this.remain, required this.rate});

  @override
  Widget build(BuildContext context) {
    final typeTag = event.type.name[0].toUpperCase() + event.type.name.substring(1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
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
                          style:
                              const TextStyle(color: Colors.black54, fontSize: 12),
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

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _batteryDelta(double rate, Duration remain) {
    final change = rate * remain.inSeconds / 3600;
    final sign = change > 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)}%';
  }
}

/// 태그를 예쁘게 보여주는 말풍선 위젯
class _TagChip extends StatelessWidget {
  final String text; // 태그 내용
  final Color color; // 배경색
  final Color textColor; // 글자색

  const _TagChip(
      {required this.text, required this.color, required this.textColor});

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
