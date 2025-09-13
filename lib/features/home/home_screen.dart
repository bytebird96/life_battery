import 'dart:async';
import 'dart:convert'; // 맵을 JSON 문자열로 변환하기 위해 사용
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 간단한 로컬 저장소
import 'circular_battery.dart';
import 'battery_controller.dart';
import '../../data/repositories.dart';
import '../../data/models.dart'; // Event 모델 사용을 위해 추가
import '../../services/notifications.dart'; // 알림 서비스
import '../event/edit_event_screen.dart'; // 일정 수정 화면

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

  /// ----------------------------------------------
  /// 로컬 저장소에 남은 시간 정보를 저장하는 유틸리티
  /// - _remainMap에 저장된 Duration을 초 단위 정수로 변환해
  ///   JSON 문자열 형태로 보관한다.
  /// ----------------------------------------------
  Future<void> _saveRemainMap() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _remainMap.map((key, value) => MapEntry(key, value.inSeconds));
    await prefs.setString('remainMap', jsonEncode(map));
  }

  /// ----------------------------------------------
  /// 실행 중인 작업 정보를 저장한다.
  /// - [id]        현재 실행 중인 일정 ID
  /// - [rate]      시간당 배터리 변화율
  /// - [duration]  전체 혹은 남은 수행 시간
  /// ----------------------------------------------
  Future<void> _saveRunningTask(
      {required String id,
      required double rate,
      required Duration duration}) async {
    final prefs = await SharedPreferences.getInstance();
    final battery = ref.read(batteryControllerProvider); // 현재 배터리 퍼센트

    await prefs.setDouble('battery', battery); // 현재 배터리 저장
    await prefs.setString('taskId', id);
    await prefs.setDouble('ratePerHour', rate);
    await prefs.setInt('duration', duration.inSeconds);
    await prefs.setInt('startTime', DateTime.now().millisecondsSinceEpoch);

    await _saveRemainMap(); // 남은 시간 정보도 함께 저장
  }

  /// ----------------------------------------------
  /// 실행 중인 작업 정보를 모두 제거한다.
  /// - 작업이 정상 종료되었거나 앱이 다시 시작될 때 호출
  /// ----------------------------------------------
  Future<void> _clearRunningTask() async {
    final prefs = await SharedPreferences.getInstance();
    final battery = ref.read(batteryControllerProvider);
    await prefs.setDouble('battery', battery); // 마지막 배터리 퍼센트 저장
    await prefs.remove('taskId');
    await prefs.remove('ratePerHour');
    await prefs.remove('duration');
    await prefs.remove('startTime');
  }

  /// ----------------------------------------------
  /// 앱 시작 시 저장된 배터리 및 일정 진행 상태를 복원한다.
  /// ----------------------------------------------
  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();

    // 1) 이전에 저장된 남은 시간 맵 복원
    final remainStr = prefs.getString('remainMap');
    if (remainStr != null) {
      final decoded = Map<String, dynamic>.from(jsonDecode(remainStr));
      decoded.forEach((key, value) {
        _remainMap[key] = Duration(seconds: value as int);
      });
    }

    // 2) 저장된 배터리 퍼센트 복원
    final savedBattery = prefs.getDouble('battery');
    if (savedBattery != null) {
      ref.read(batteryControllerProvider.notifier).state = savedBattery;
    }

    // 3) 실행 중이던 작업이 있는지 확인
    final runningId = prefs.getString('taskId');
    if (runningId != null) {
      final rate = prefs.getDouble('ratePerHour') ?? 0; // 시간당 배터리 변화율
      final durationSec = prefs.getInt('duration') ?? 0; // 전체 혹은 남은 시간(초)
      final startMillis = prefs.getInt('startTime') ?? 0; // 작업이 시작된 시각(ms)

      // 현재 시각과 시작 시각의 차이를 초 단위로 계산
      final elapsedSec =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 - startMillis ~/ 1000;

      // 실제로 소모된 시간은 전체 duration을 넘지 않도록 제한
      final usedSec = elapsedSec > durationSec ? durationSec : elapsedSec;

      // -------- 배터리 보정 로직 --------
      // 강제 종료 동안 경과한 시간을 반영하여 배터리 값을 보정한다.
      final perSecond = rate / 3600; // 초당 배터리 변화량
      var battery = ref.read(batteryControllerProvider); // 현재 배터리 값
      battery += perSecond * usedSec; // 경과 시간만큼 변화 적용
      if (battery > 100) battery = 100; // 최대 100%
      if (battery < 0) battery = 0; // 최소 0%
      // 계산된 배터리 값을 상태에 반영
      ref.read(batteryControllerProvider.notifier).state = battery;
      // 혹시 남아 있을지 모를 타이머를 정지하여
      // 일정이 끝난 뒤에도 배터리가 계속 변하는 문제를 차단한다.
      ref.read(batteryControllerProvider.notifier).stop();

      final remainSec = durationSec - usedSec; // 남은 수행 시간(초)
      if (remainSec > 0) {
        // 작업이 아직 남아 있다면 남은 시간을 기록하고 이어서 실행
        _remainMap[runningId] = Duration(seconds: remainSec);
        await _clearRunningTask(); // 기존 저장 정보 제거

        // 실제 일정 데이터를 찾아 재시작
        final repo = ref.read(repositoryProvider);
        try {
          final e = repo.events.firstWhere((ev) => ev.id == runningId);
          await _startEvent(e); // 남은 시간을 이용해 재시작
        } catch (_) {
          // 일정이 삭제되었으면 남은 시간 정보만 초기화
          _remainMap.remove(runningId);
          await _saveRemainMap();
        }
      } else {
        // 이미 종료된 경우: 남은 시간을 0으로 저장하고 모든 실행 정보 제거
        _remainMap[runningId] = Duration.zero;
        await _clearRunningTask();
        await _saveRemainMap();
      }
    } else {
      // 실행 중인 작업이 없다면 저장된 남은 시간만 적용하면 된다.
      await _saveRemainMap();
    }

    if (!mounted) return; // 위 과정에서 위젯이 dispose되었을 경우 대비
    setState(() {}); // 복원된 정보로 화면 갱신
  }

  @override
  void initState() {
    super.initState();
    // 최초 실행 시 저장소의 일정 목록으로 남은 시간 초기화
    final repo = ref.read(repositoryProvider);
    for (final e in repo.events) {
      _remainMap[e.id] = e.endAt.difference(e.startAt);
    }

    // 비동기적으로 저장된 상태 복원
    Future.microtask(_loadState);
  }

  /// Duration을 "HH:mm:ss" 형식의 문자열로 변환
  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// 일정 시작 처리
  /// - [e] 실행할 일정
  Future<void> _startEvent(Event e) async {
    var duration = _remainMap[e.id] ?? e.endAt.difference(e.startAt);
    if (duration == Duration.zero) {
      // 남은 시간이 0이면 처음부터 다시 시작
      duration = e.endAt.difference(e.startAt);
    }

    // 남은 시간이 0 이하라면 실행할 필요가 없으므로 바로 종료
    if (duration <= Duration.zero) {
      _remainMap[e.id] = Duration.zero; // 남은 시간을 0으로 명시
      await _saveRemainMap();
      return;
    }

    // 배터리 컨트롤러에 작업 시작 요청
    // 배터리 컨트롤러에 작업 시작 요청
    ref
        .read(batteryControllerProvider.notifier)
        .startTask(ratePerHour: e.ratePerHour ?? 0, duration: duration);

    // 기존에 예약된 알림이 있다면 취소 후 새로 예약
    final notif = ref.read(notificationProvider);
    await notif.cancel(e.id.hashCode);
    await notif.scheduleComplete(
      id: e.id.hashCode,
      title: '일정 완료',
      body: '${e.title}이(가) 완료되었습니다',
      after: duration,
    );

    // 시작한 작업 정보를 로컬 저장소에 기록
    _remainMap[e.id] = duration;
    await _saveRunningTask(
        id: e.id, rate: e.ratePerHour ?? 0, duration: duration);

    // 남은 시간 카운트다운 시작
    _countdown?.cancel();
    setState(() {
      _taskId = e.id;
      _remain = duration;
    });
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remain.inSeconds <= 1) {
        _stopEvent(completed: true); // 시간이 끝나면 작업 종료
      } else {
        setState(() {
          _remain -= const Duration(seconds: 1);
        });
      }
    });
  }

  /// 일정 중지 처리
  /// - [completed] true이면 정상 완료, false이면 사용자가 중지
  Future<void> _stopEvent({bool completed = false}) async {
    ref.read(batteryControllerProvider.notifier).stop();
    _countdown?.cancel();

    // 사용자가 중지한 경우 예약된 알림 취소
    if (!completed && _taskId != null) {
      await ref.read(notificationProvider).cancel(_taskId!.hashCode);
    }

    setState(() {
      if (_taskId != null) {
        // 중지 시점의 남은 시간을 저장해 다음 시작에 활용
        // 1초 이하로 남아있다면 0으로 처리하여 완료 상태로 만든다.
        _remainMap[_taskId!] =
            _remain.inSeconds <= 1 ? Duration.zero : _remain;
      }
      _taskId = null;
    });

    // 중지 시점의 정보와 배터리를 저장소에 반영
    await _saveRemainMap();
    await _clearRunningTask();
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
          // 원형 배터리 게이지 표시 (일정 실행 중이면 번개 애니메이션)
          CircularBattery(percent: battery / 100, charging: _taskId != null),
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
                    final wasRunning = _taskId == e.id; // 삭제된 일정이 실행 중이었는지 확인
                    setState(() {
                      _remainMap.remove(e.id); // 남은 시간 정보도 제거
                    });
                    if (wasRunning) {
                      await _stopEvent(); // 실행 중인 일정이 삭제되면 중지
                    } else {
                      await _saveRemainMap(); // 변경된 남은 시간 맵 저장
                    }
                  },
                  child: ListTile(
                    title: Text(e.title), // 일정 제목
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.content != null && e.content!.isNotEmpty)
                          Text(e.content!), // 일정 상세 내용
                        Text('소요 시간: ${_format(base)}'),
                        Text('배터리 변화: ${total.toStringAsFixed(1)}%'),
                        if (running)
                          Text(
                            _format(_remain),
                            style: Theme.of(context).textTheme.bodySmall,
                          ), // 실행 중이면 남은 시간 표시
                      ],
                    ),
                    // 시작/중지 버튼과 수정 버튼을 나란히 배치
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 수정 버튼
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            // 수정 화면으로 이동 후 돌아오면 목록 갱신
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditEventScreen(event: e),
                              ),
                            );
                            // 수정된 일정의 기본 시간으로 남은 시간을 재설정
                            setState(() {
                              final updated = repo.events
                                  .firstWhere((ev) => ev.id == e.id);
                              _remainMap[e.id] =
                                  updated.endAt.difference(updated.startAt);
                            });
                            await _saveRemainMap(); // 변경 사항 저장
                          },
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (running) {
                              await _stopEvent();
                            } else {
                              await _startEvent(e);
                            }
                          },
                          child: Text(running ? '중지' : '시작'),
                        ),
                      ],
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
