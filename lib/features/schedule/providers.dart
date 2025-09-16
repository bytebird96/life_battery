import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/schedule_models.dart';
import '../../data/schedule_repository.dart';

/// 전체 일정 스트림
final scheduleStreamProvider =
    StreamProvider<List<Schedule>>((ref) {
  final repo = ref.watch(scheduleRepositoryProvider);
  return repo.watchSchedules();
});

/// 지오펜스 로그 스트림
final scheduleLogStreamProvider =
    StreamProvider<List<ScheduleLogEntry>>((ref) {
  final repo = ref.watch(scheduleRepositoryProvider);
  return repo.watchLogs();
});

/// ID로 개별 일정을 찾아 반환
final scheduleByIdProvider = Provider.family<Schedule?, String>((ref, id) {
  final schedules = ref.watch(scheduleStreamProvider);
  return schedules.maybeWhen(
    data: (items) {
      for (final item in items) {
        if (item.id == id) {
          return item;
        }
      }
      return null;
    },
    orElse: () => null,
  );
});
