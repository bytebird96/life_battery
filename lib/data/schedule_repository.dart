import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../services/holiday_service.dart';
import 'schedule_db.dart';
import 'schedule_models.dart';

/// 지오펜스 일정을 관리하는 리포지토리
class ScheduleRepository {
  ScheduleRepository({
    required ScheduleDb db,
    required HolidayService holidayService,
  })  : _db = db,
        _holidayService = holidayService;

  final ScheduleDb _db;
  final HolidayService _holidayService;
  final _uuid = const Uuid();

  final _scheduleController = StreamController<List<Schedule>>.broadcast();
  final _logController = StreamController<List<ScheduleLogEntry>>.broadcast();

  List<Schedule> _schedules = [];
  List<ScheduleLogEntry> _logs = [];

  /// 앱 시작 시 초기 데이터 로드
  Future<void> init() async {
    await _db.init();
    await _holidayService.load();
    await _refreshSchedules();
    await _refreshLogs();
  }

  Future<void> dispose() async {
    await _db.close();
    await _scheduleController.close();
    await _logController.close();
  }

  List<Schedule> get currentSchedules => List.unmodifiable(_schedules);

  Stream<List<Schedule>> watchSchedules() => _scheduleController.stream;

  Stream<List<ScheduleLogEntry>> watchLogs() => _logController.stream;

  Future<List<Schedule>> fetchSchedules() async => List.unmodifiable(_schedules);

  Future<Schedule?> findById(String id) async {
    try {
      return _schedules.firstWhere((element) => element.id == id);
    } catch (_) {
      final raw = await _db.fetchScheduleById(id);
      return raw == null ? null : Schedule.fromDbMap(raw);
    }
  }

  String newId() => _uuid.v4();

  /// 신규/기존 일정을 저장하고 스트림으로 변경 사항을 흘려보낸다.
  Future<void> saveSchedule(Schedule schedule) async {
    await _db.upsertSchedule(schedule.toDbMap());
    final index = _schedules.indexWhere((element) => element.id == schedule.id);
    if (index >= 0) {
      _schedules[index] = schedule;
    } else {
      _schedules.add(schedule);
    }
    _schedules.sort((a, b) => a.startAt.compareTo(b.startAt));
    _emitSchedules();
  }

  /// 일정 삭제 후 목록을 최신화한다.
  Future<void> deleteSchedule(String id) async {
    await _db.deleteSchedule(id);
    _schedules.removeWhere((element) => element.id == id);
    _emitSchedules();
  }

  /// 실행 완료 여부를 갱신하고 스트림으로 반영
  Future<void> setExecuted(String id, bool executed) async {
    await _db.updateExecuted(id, executed);
    final index = _schedules.indexWhere((element) => element.id == id);
    if (index >= 0) {
      final updated = _schedules[index].copyWith(
        executed: executed,
        updatedAt: DateTime.now(),
      );
      _schedules[index] = updated;
      _emitSchedules();
    }
  }

  /// 사용자에게 보여줄 로그를 DB와 메모리에 함께 추가
  Future<void> addLog(String message, {String? scheduleId}) async {
    final now = DateTime.now();
    await _db.insertLog({
      'schedule_id': scheduleId,
      'message': message,
      'created_at': now.millisecondsSinceEpoch,
    });
    await _db.trimLogs(50);
    await _refreshLogs();
  }

  /// 특정 날짜가 공휴일인지 여부를 HolidayService에 위임
  Future<bool> isHoliday(DateTime date) => _holidayService.isHoliday(date);

  Future<void> _refreshSchedules() async {
    final rows = await _db.fetchSchedules();
    _schedules = rows.map(Schedule.fromDbMap).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    _emitSchedules();
  }

  Future<void> _refreshLogs() async {
    final rows = await _db.fetchLogs(limit: 50);
    _logs = rows.map(ScheduleLogEntry.fromDbMap).toList();
    _logController.add(List.unmodifiable(_logs));
  }

  void _emitSchedules() {
    _scheduleController.add(List.unmodifiable(_schedules));
  }
}

/// 의존성 주입용 프로바이더
final scheduleRepositoryProvider =
    Provider<ScheduleRepository>((ref) => throw UnimplementedError());
