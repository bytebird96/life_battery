import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories.dart';

/// 설정 화면
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final s = repo.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('초기 배터리: ${s.initialBattery}'),
          Text('작업 기본 소모: ${s.defaultDrainRate}/h'),
          Text('휴식 기본 회복: ${s.defaultRestRate}/h'),
          SwitchListTile(
              title: const Text('수면 풀충전'),
              value: s.sleepFullCharge,
              onChanged: (v) => s.sleepFullCharge = v),
          ElevatedButton(
              onPressed: () {
                // 재계산: setState 대신 Navigator.pop
                Navigator.pop(context);
              },
              child: const Text('시뮬레이션 재계산'))
        ],
      ),
    );
  }
}
