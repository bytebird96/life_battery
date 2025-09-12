import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'battery_gauge.dart';
import 'battery_controller.dart';
import '../../data/repositories.dart';

/// 홈 화면
/// - 등록된 일정 목록을 보여주고 스와이프로 삭제 가능
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider); // 저장된 일정 목록을 제공
    final battery = ref.watch(batteryControllerProvider); // 현재 배터리 퍼센트

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
                final duration = e.endAt.difference(e.startAt); // 소요 시간 계산
                final total =
                    (e.ratePerHour ?? 0) * (duration.inMinutes / 60); // 전체 배터리 변화
                return Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    // 일정 삭제 후 화면 갱신
                    setState(() {
                      repo.deleteEvent(e.id);
                    });
                  },
                  child: ListTile(
                    title: Text(e.title), // 일정 제목
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.content != null && e.content!.isNotEmpty)
                          Text(e.content!), // 일정 상세 내용
                        Text('소요 시간: ${duration.inMinutes}분'),
                        Text('배터리 변화: ${total.toStringAsFixed(1)}%'),
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
