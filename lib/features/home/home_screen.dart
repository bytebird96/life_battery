import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'battery_gauge.dart';
import 'battery_controller.dart';

/// 홈 화면
/// - 시작/중지 버튼으로 작업을 실행하고 남은 시간을 표시
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _countdown; // 남은 시간을 표시하는 타이머
  Duration _remain = Duration.zero; // 현재 실행 중인 작업의 남은 시간
  String? _task; // 현재 진행 중인 작업 식별자

  /// 각 작업별 기본 지속 시간
  /// - 사용자가 중지했다가 다시 시작할 때 남은 시간을 기억하기 위해 사용
  final Map<String, Duration> _baseDurations = {
    'sleep': const Duration(hours: 7),
    'work': const Duration(hours: 8),
  };

  /// 작업별로 남아 있는 시간 저장소
  /// - 처음에는 기본 지속 시간으로 채워짐
  late Map<String, Duration> _remainMap;

  @override
  void initState() {
    super.initState();
    // 모든 작업의 남은 시간을 기본값으로 초기화
    _remainMap = Map.from(_baseDurations);
  }

  /// 남은 시간을 HH:mm 형식으로 표시
  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 작업 시작 공통 처리
  /// [id] 작업 식별자, [rate] 시간당 증감 퍼센트
  /// - 기존에 중지한 적이 있다면 그때의 남은 시간부터 다시 시작
  void _startTask(String id, double rate) {
    // 직전에 저장된 남은 시간이 0이면 처음부터 시작
    var duration = _remainMap[id] ?? _baseDurations[id]!;
    if (duration == Duration.zero) duration = _baseDurations[id]!;

    // 배터리 타이머 시작
    ref
        .read(batteryControllerProvider.notifier)
        .startTask(ratePerHour: rate, duration: duration);

    // 카운트다운 타이머 시작
    _countdown?.cancel();
    setState(() {
      _task = id;
      _remain = duration;
    });
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remain.inSeconds <= 1) {
          _stopTask();
        } else {
          _remain -= const Duration(seconds: 1);
        }
      });
    });
  }

  /// 작업 중지
  void _stopTask() {
    ref.read(batteryControllerProvider.notifier).stop();
    _countdown?.cancel();
    setState(() {
      // 현재 작업이 있다면 남은 시간을 저장해 재시작에 활용
      if (_task != null) {
        _remainMap[_task!] = _remain;
      }
      _task = null;
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final battery = ref.watch(batteryControllerProvider); // 현재 배터리 퍼센트

    return Scaffold(
      appBar: AppBar(title: const Text('에너지 배터리')),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // 배터리 게이지
          BatteryGauge(percent: battery / 100),
          const SizedBox(height: 16),
          // 일정 목록
          Expanded(
            child: ListView(
              children: [
                // 수면 7시간 예시
                ListTile(
                  title: const Text('수면 7시간 (시간당 10%)'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('충전 70%'),
                      if (_task == 'sleep')
                        Text(_format(_remain),
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      if (_task == 'sleep') {
                        _stopTask();
                      } else {
                        // 저장된 남은 시간부터 다시 시작
                        _startTask('sleep', 10);
                      }
                    },
                    child: Text(_task == 'sleep' ? '중지' : '시작'),
                  ),
                ),
                // 업무 8시간 예시
                ListTile(
                  title: const Text('업무 8시간 (시간당 5%)'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('배터리 소모 예상 40%'),
                      if (_task == 'work')
                        Text(_format(_remain),
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      if (_task == 'work') {
                        _stopTask();
                      } else {
                        // 저장된 남은 시간부터 다시 시작
                        _startTask('work', -5);
                      }
                    },
                    child: Text(_task == 'work' ? '중지' : '시작'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
