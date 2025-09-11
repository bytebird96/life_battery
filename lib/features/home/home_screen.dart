import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories.dart';
import '../../core/time.dart';
import 'battery_gauge.dart';
import 'timeline_view.dart';
import '../../data/models.dart';
import 'dart:math';

/// 홈 화면
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final now = DateTime.now();
    final data = repo.simulateDay(now);
    final battery = data[now] ?? repo.settings.initialBattery;
    return Scaffold(
      appBar: AppBar(
        title: const Text('에너지 배터리'),
        actions: [
          IconButton(
              onPressed: () => Navigator.pushNamed(context, '/report'),
              icon: const Icon(Icons.assessment)),
          IconButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              icon: const Icon(Icons.settings)),
          IconButton(
              onPressed: () async {
                await repo.addDummy(now);
                (context as Element).markNeedsBuild();
              },
              icon: const Icon(Icons.bolt))
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          BatteryGauge(percent: battery / 100),
          const SizedBox(height: 16),
          Expanded(child: TimelineView(data: data, settings: repo.settings)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final start = alignMinute(DateTime.now());
          final end = start.add(const Duration(minutes: 30));
          repo.saveEvent(Event(
              id: Random().nextInt(1 << 32).toString(),
              title: '빠른작업',
              startAt: start,
              endAt: end,
              type: EventType.work,
              ratePerHour: null,
              priority: defaultPriority(EventType.work),
              createdAt: start,
              updatedAt: start));
          (context as Element).markNeedsBuild();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
