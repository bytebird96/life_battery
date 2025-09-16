import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/schedule_models.dart';
import '../../data/schedule_repository.dart';
import '../../services/geofence_manager.dart';
import 'providers.dart';

/// 일정 상세 화면
class ScheduleDetailScreen extends ConsumerWidget {
  const ScheduleDetailScreen({super.key, required this.scheduleId});

  final String scheduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(scheduleByIdProvider(scheduleId));
    if (schedule == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('일정 상세')),
        body: const Center(child: Text('일정을 찾을 수 없습니다.')),
      );
    }
    final timeFormat = DateFormat('yyyy-MM-dd HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: Text(schedule.title),
        actions: [
          IconButton(
            // 상세 화면에서 편집 화면으로 이동할 때는 push를 사용해 되돌아올 수 있도록 한다.
            onPressed: () => context.push('/schedule/${schedule.id}/edit'),
            icon: const Icon(Icons.edit),
            tooltip: '수정',
          ),
          IconButton(
            onPressed: () => _confirmDelete(context, ref, schedule),
            icon: const Icon(Icons.delete_outline),
            tooltip: '삭제',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _detailTile('시간',
              '${timeFormat.format(schedule.startAt)} ~ ${timeFormat.format(schedule.endAt)}'),
          _detailTile('트리거', schedule.triggerType.koLabel),
          _detailTile('요일/공휴일 조건', schedule.dayCondition.koLabel),
          _detailTile('프리셋', schedule.presetType.koLabel),
          _detailTile('미실행 시 알림', schedule.remindIfNotExecuted ? '사용' : '사용 안 함'),
          _detailTile('상태', schedule.executed ? '실행 완료' : '대기 중'),
          if (schedule.useLocation)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Text('위치 정보',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('장소명: ${schedule.placeName ?? '미입력'}'),
                Text('좌표: ${schedule.lat?.toStringAsFixed(6)}, ${schedule.lng?.toStringAsFixed(6)}'),
                Text('반경: ${(schedule.radiusMeters ?? 150).toStringAsFixed(0)}m'),
              ],
            ),
        ],
      ),
      bottomNavigationBar: schedule.executed
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => _markExecuted(ref, schedule),
                icon: const Icon(Icons.check),
                label: const Text('실행 완료'),
              ),
            ),
    );
  }

  Widget _detailTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _markExecuted(WidgetRef ref, Schedule schedule) async {
    // 실행 완료 버튼을 누르면 즉시 DB에 반영하고 로그를 남긴다.
    final repo = ref.read(scheduleRepositoryProvider);
    await repo.setExecuted(schedule.id, true);
    await repo.addLog('사용자가 실행 완료 처리: ${schedule.title}',
        scheduleId: schedule.id);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Schedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text('정말로 "${schedule.title}" 일정을 삭제하시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(scheduleRepositoryProvider);
    final manager = ref.read(geofenceManagerProvider);
    await repo.deleteSchedule(schedule.id);
    await repo.addLog('일정 삭제: ${schedule.title}', scheduleId: schedule.id);
    await manager.removeSchedule(schedule.id);
    if (context.mounted) {
      context.pop();
    }
  }
}
