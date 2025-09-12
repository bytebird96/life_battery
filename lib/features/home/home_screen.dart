import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'battery_gauge.dart';
import 'battery_controller.dart';
import '../../data/repositories.dart';
import '../../data/models.dart'; // Event 모델 사용을 위해 추가

/// 홈 화면
/// - 등록된 일정 목록을 보여주고 스와이프로 삭제 가능
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _countdown; // 남은 시간을 표시하는 타이머
  String? _taskId; // 현재 실행 중인 일정의 ID
  Duration _remain = Duration.zero; // 현재 실행 중인 일정의 남은 시간

  // 각 일정별로 남은 시간을 저장하는 맵
  final Map<String, Duration> _remainMap = {};

  @override
  void initState() {
    super.initState();
    // 최초 실행 시 저장소의 일정 목록으로 남은 시간 초기화
    final repo = ref.read(repositoryProvider);
    for (final e in repo.events) {
      _remainMap[e.id] = e.endAt.difference(e.startAt);
    }
  }

  /// Duration을 "HH:mm" 형식의 문자열로 변환
  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 일정 시작 처리
  /// - [e] 실행할 일정
  void _startEvent(Event e) {
    var duration = _remainMap[e.id] ?? e.endAt.difference(e.startAt);
    if (duration == Duration.zero) {
      // 남은 시간이 0이면 처음부터 다시 시작
      duration = e.endAt.difference(e.startAt);
    }

    // 배터리 컨트롤러에 작업 시작 요청
    ref
        .read(batteryControllerProvider.notifier)
        .startTask(ratePerHour: e.ratePerHour ?? 0, duration: duration);

    // 남은 시간 카운트다운 시작
    _countdown?.cancel();
    setState(() {
      _taskId = e.id;
      _remain = duration;
    });
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remain.inSeconds <= 1) {
          _stopEvent();
        } else {
          _remain -= const Duration(seconds: 1);
        }
      });
    });
  }

  /// 일정 중지 처리
  void _stopEvent() {
    ref.read(batteryControllerProvider.notifier).stop();
    _countdown?.cancel();
    setState(() {
      if (_taskId != null) {
        // 중지 시점의 남은 시간을 저장해 다음 시작에 활용
        _remainMap[_taskId!] = _remain;
      }
      _taskId = null;
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider); // 저장된 일정 목록을 제공
    final battery = ref.watch(batteryControllerProvider); // 현재 배터리 퍼센트

    // 새로 추가된 일정이 있으면 기본 남은 시간을 설정
    for (final e in repo.events) {
      _remainMap.putIfAbsent(e.id, () => e.endAt.difference(e.startAt));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('에너지 배터리')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 일정 추가 화면으로 이동 후 돌아오면 목록 갱신
          await Navigator.pushNamed(context, '/event');
          setState(() {}); // 리빌드하여 새 일정 표시
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // 배터리 게이지 표시
          BatteryGauge(percent: battery / 100),
          const SizedBox(height: 16),
          // 일정 목록 영역
          Expanded(
            child: ListView.builder(
              itemCount: repo.events.length,
              itemBuilder: (context, index) {
                final e = repo.events[index]; // 현재 일정
                final base = e.endAt.difference(e.startAt); // 일정의 전체 소요 시간
                final total =
                    (e.ratePerHour ?? 0) * (base.inMinutes / 60); // 전체 배터리 변화
                final running = _taskId == e.id; // 현재 실행 중인지 여부

                return Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    // Dismissible이 제거된 뒤에도 위젯 트리에 남아있는 오류를 방지하기 위해
                    // 먼저 저장소에서 일정을 삭제한 뒤 setState로 화면을 갱신합니다.
                    await repo.deleteEvent(e.id); // 로컬 DB에서 일정 삭제
                    setState(() {
                      _remainMap.remove(e.id); // 남은 시간 정보도 제거
                      if (_taskId == e.id) {
                        _stopEvent(); // 실행 중인 일정이 삭제되면 중지
                      }
                    });
                  },
                  child: ListTile(
                    title: Text(e.title), // 일정 제목
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.content != null && e.content!.isNotEmpty)
                          Text(e.content!), // 일정 상세 내용
                        Text('소요 시간: ${base.inMinutes}분'),
                        Text('배터리 변화: ${total.toStringAsFixed(1)}%'),
                        if (running)
                          Text(
                            _format(_remain),
                            style: Theme.of(context).textTheme.bodySmall,
                          ), // 실행 중이면 남은 시간 표시
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        if (running) {
                          _stopEvent();
                        } else {
                          _startEvent(e);
                        }
                      },
                      child: Text(running ? '중지' : '시작'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
