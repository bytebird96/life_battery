import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories.dart';
import '../../core/time.dart';
import 'battery_gauge.dart';
import 'timeline_view.dart';
import '../../data/models.dart';
import '../../core/compute.dart'; // defaultPriority 사용
import 'dart:math';

/// 홈 화면
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final now = DateTime.now();
    final data = repo.simulateDay(now); // 오늘 배터리 변화 시뮬레이션
    final battery = data[now] ?? repo.settings.initialBattery; // 현재 배터리 퍼센트
    // 오늘 하루에 해당하는 이벤트 목록 구하기
    final start = todayStart(now, repo.settings.dayStart);
    final end = start.add(const Duration(days: 1));
    final todayEvents = repo.eventsInRange(start, end);
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
          // 타임라인에 시뮬레이션 결과와 이벤트 리스트 전달
          Expanded(
              child: TimelineView(
                  data: data,
                  settings: repo.settings,
                  events: todayEvents)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final start = alignMinute(DateTime.now());
          final end = start.add(const Duration(minutes: 30));
          // 현재 시각 기준 30분짜리 작업 이벤트를 즉시 생성
          repo.saveEvent(Event(
              id: Random().nextInt(1 << 32).toString(),
              title: '빠른작업',
              startAt: start,
              endAt: end,
              type: EventType.work,
              ratePerHour: null,
              // 작업 타입의 기본 우선순위 사용
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
