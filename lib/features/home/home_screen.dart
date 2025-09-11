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
  Duration _remain = Duration.zero; // 남은 시간
  String? _task; // 현재 진행 중인 작업 식별자

  /// 남은 시간을 HH:mm 형식으로 표시
  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 작업 시작 공통 처리
  void _startTask(String id, double rate, Duration duration) {
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
      _task = null;
      _remain = Duration.zero;
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
                        _startTask('sleep', 10, const Duration(hours: 7));
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
                        _startTask('work', -5, const Duration(hours: 8));
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
