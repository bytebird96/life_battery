import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories.dart';
import 'battery_gauge.dart';
import 'battery_controller.dart';

/// 배터리 상태를 제공하는 프로바이더
final batteryProvider = StateNotifierProvider<BatteryController, double>((ref) {
  // 리포지토리에서 초기 배터리 값을 가져와 컨트롤러 생성
  final repo = ref.watch(repositoryProvider);
  return BatteryController(repo.settings.initialBattery);
});

/// 홈 화면
/// - 수면/업무 일정을 목록으로 보여주고, 시작 버튼으로 타이머를 실행
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final battery = ref.watch(batteryProvider); // 현재 배터리 퍼센트

    return Scaffold(
      appBar: AppBar(title: const Text('에너지 배터리')),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // 현재 배터리 상태 표시
          BatteryGauge(percent: battery / 100),
          const SizedBox(height: 16),
          // 일정 목록
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  title: const Text('수면 7시간 (시간 당 10%)'),
                  subtitle: const Text('충전 70%'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      // 수면 시작: 7시간 동안 시간당 10% 충전
                      ref
                          .read(batteryProvider.notifier)
                          .startTask(ratePerHour: 10, duration: const Duration(hours: 7));
                    },
                    child: const Text('시작'),
                  ),
                ),
                ListTile(
                  title: const Text('업무 8시간 (시간당 5%)'),
                  subtitle: const Text('배터리 소모 예상 40%'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      // 업무 시작: 8시간 동안 시간당 -5% 소모
                      ref
                          .read(batteryProvider.notifier)
                          .startTask(ratePerHour: -5, duration: const Duration(hours: 8));
                    },
                    child: const Text('시작'),
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
