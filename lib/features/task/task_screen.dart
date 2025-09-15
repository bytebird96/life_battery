import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../event/edit_event_screen.dart';
import '../home/battery_controller.dart';
import '../../services/notifications.dart';

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

  /// 실행 중인 일정 정보를 저장소에 기록한다.
  Future<void> _saveRunningTask(Event e, Duration duration) async {
    final prefs = await SharedPreferences.getInstance();
    final battery = ref.read(batteryControllerProvider); // 현재 배터리 값
    await prefs.setDouble('battery', battery); // 배터리 퍼센트 저장
    await prefs.setString('taskId', e.id); // 실행 중 일정 ID 저장
    await prefs.setDouble('ratePerHour', e.ratePerHour ?? 0); // 시간당 변화율
    await prefs.setInt('duration', duration.inSeconds); // 전체 예정 시간(초)
    await prefs.setInt('startTime',
        DateTime.now().millisecondsSinceEpoch); // 시작 시각 기록
  }

  /// 실행 중인 일정 정보를 저장소에서 제거한다.
  Future<void> _clearRunningTask() async {
    final prefs = await SharedPreferences.getInstance();
    final battery = ref.read(batteryControllerProvider); // 현재 배터리 값
    await prefs.setDouble('battery', battery); // 최신 배터리 퍼센트 저장
    await prefs.remove('taskId');
    await prefs.remove('ratePerHour');
    await prefs.remove('duration');
    await prefs.remove('startTime');
  }

  /// 전달받은 일정을 시작한다.
  Future<void> _startEvent(Event e) async {
    // 이미 실행 중인 일정이 있다면 먼저 중지
    if (_runningEvent != null) {
      await _stopEvent();
    }

    final duration = e.endAt.difference(e.startAt); // 전체 예정 시간
    // 배터리 컨트롤러에 작업 시작 요청
    ref.read(batteryControllerProvider.notifier).startTask(
          ratePerHour: e.ratePerHour ?? 0,
          duration: duration,
        );

    // 일정 완료 알림 예약
    final notif = ref.read(notificationProvider);
    try {
      await notif.cancel(e.id.hashCode); // 기존 알림이 있다면 취소
      await notif.scheduleComplete(
        id: e.id.hashCode,
        title: '일정 완료',
        body: '${e.title}이(가) 완료되었습니다',
        after: duration,
      );
    } catch (err) {
      debugPrint('알림 예약 실패: $err');
    }

    // 실행 정보 저장
    await _saveRunningTask(e, duration);

    // 화면 상태 갱신 및 카운트다운 시작
    _timer?.cancel();
    setState(() {
      _runningEvent = e;
      _remain = duration;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remain.inSeconds <= 1) {
        _stopEvent(completed: true); // 시간이 끝나면 자동 종료
      } else {
        setState(() => _remain -= const Duration(seconds: 1));
      }
    });
  }

  /// 실행 중인 일정을 중지한다.
  Future<void> _stopEvent({bool completed = false}) async {
    // 배터리 변화 중지
    ref.read(batteryControllerProvider.notifier).stop();
    _timer?.cancel();

    // 완료 전에 중지하면 예약된 알림 취소
    if (!completed && _runningEvent != null) {
      try {
        await ref
            .read(notificationProvider)
            .cancel(_runningEvent!.id.hashCode);
      } catch (err) {
        debugPrint('알림 취소 실패: $err');
      }
    }

    // 저장된 실행 정보 제거
    await _clearRunningTask();

    // 화면 상태 리셋
    setState(() {
      _runningEvent = null;
      _remain = Duration.zero;
    });
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
      appBar: AppBar(
        title: const Text('Task'),
        actions: const [
          // 상단 오른쪽 더보기 아이콘 (현재 동작 없음)
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.more_vert),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_runningEvent != null) ...[
              // 실행 중인 일정을 크게 보여주는 카드
              GestureDetector(
                onTap: () {
                  // 카드 탭 시 수정 화면으로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditEventScreen(event: _runningEvent!),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D2235), // 시안과 비슷한 진한 배경색
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _format(_remain),
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _runningEvent!.title,
                              style:
                                  const TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      // 중지 버튼 대신 우측에 재생 아이콘 표시
                      GestureDetector(
                        onTap: _stopEvent,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.stop, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            // 오늘의 일정 제목과 전체보기 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Today',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  'See All',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 전체 일정 목록
            Expanded(
              child: ListView.separated(
                itemCount: repo.events.length,
                itemBuilder: (context, index) {
                  final e = repo.events[index];
                  final running = _runningEvent?.id == e.id; // 현재 실행 중인지 여부
                  final remain =
                      running ? _remain : e.endAt.difference(e.startAt); // 남은 시간
                  final rate = _rateFor(e, repo);
                  return _SimpleEventTile(
                    event: e,
                    remain: remain,
                    rate: rate,
                    running: running,
                    onPressed: () {
                      if (running) {
                        _stopEvent();
                      } else {
                        _startEvent(e);
                      }
                    },
                  );
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
  final bool running; // 현재 실행 중인지 여부
  final VoidCallback onPressed; // 버튼 눌렀을 때 동작

  const _SimpleEventTile({
    required this.event,
    required this.remain,
    required this.rate,
    required this.running,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final typeTag =
        event.type.name[0].toUpperCase() + event.type.name.substring(1);

    // 일정 타입별 아이콘과 배경색 정의
    final iconData = _iconFor(event.type);
    final iconBg = _iconBg(event.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 왼쪽 원형 아이콘 영역
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: Colors.white),
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
          // 실행 여부에 따라 아이콘을 바꾸는 시작/중지 버튼
          GestureDetector(
            onTap: onPressed,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFEDEDED),
                shape: BoxShape.circle,
              ),
              child: Icon(
                running ? Icons.stop : Icons.play_arrow,
                color: Colors.black,
              ),
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

  // 일정 타입별 아이콘 결정
  IconData _iconFor(EventType type) {
    switch (type) {
      case EventType.work:
        return Icons.design_services; // 작업
      case EventType.rest:
        return Icons.self_improvement; // 휴식
      case EventType.sleep:
        return Icons.nights_stay; // 수면
      case EventType.neutral:
        return Icons.hourglass_bottom; // 기타
    }
  }

  // 일정 타입별 배경색 결정
  Color _iconBg(EventType type) {
    switch (type) {
      case EventType.work:
        return const Color(0xFF9B51E0); // 보라색
      case EventType.rest:
        return const Color(0xFFFF8748); // 주황색
      case EventType.sleep:
        return const Color(0xFF26C6DA); // 파란색
      case EventType.neutral:
        return const Color(0xFF6FCF97); // 초록색
    }
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
