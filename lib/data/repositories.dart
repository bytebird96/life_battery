import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/time.dart';
import '../core/compute.dart';
import 'models.dart';
import 'app_db.dart' as db; // Drift에서 생성된 클래스와 이름 충돌 방지

/// 리포지토리 프로바이더
final repositoryProvider = Provider<AppRepository>((ref) => throw UnimplementedError());

/// 간단한 리포지토리 구현
class AppRepository {
  late final db.AppDb _db; // 실제 DB 접근 객체
  UserSettings settings = UserSettings();
  List<Event> events = [];

  Future<void> init() async {
    _db = db.AppDb(); // 로컬 데이터베이스 초기화
    // 설정 존재 확인 후 없으면 기본값 삽입
    settings = UserSettings();
  }

  /// 오늘 윈도우 이벤트 조회
  List<Event> eventsInRange(DateTime start, DateTime end) {
    // 주어진 기간과 겹치는 이벤트만 필터링
    return events
        .where((e) => e.startAt.isBefore(end) && e.endAt.isAfter(start))
        .toList();
  }

  /// 이벤트 저장
  Future<void> saveEvent(Event e) async {
    // 동일 ID 이벤트가 있으면 교체
    events.removeWhere((ex) => ex.id == e.id);
    events.add(e);
  }

  /// 이벤트 삭제
  Future<void> deleteEvent(String id) async {
    // ID 일치 이벤트 제거
    events.removeWhere((e) => e.id == id);
  }

  /// 시뮬레이션 실행
  Map<DateTime, double> simulateDay(DateTime day) {
    // 하루 시작~끝 시각 계산 후 시뮬레이션 실행
    final start = todayStart(day, settings.dayStart);
    final end = start.add(const Duration(days: 1));
    final es = eventsInRange(start, end);
    return simulate(es, settings, start, end);
  }

  /// 더미 데이터 추가
  Future<void> addDummy(DateTime day) async {
    // 예시 데이터 3개 생성
    events = [
      Event(
          id: '1',
          title: '작업',
          startAt: DateTime(day.year, day.month, day.day, 9, 0),
          endAt: DateTime(day.year, day.month, day.day, 15, 0),
          type: EventType.work,
          ratePerHour: -6,
          priority: defaultPriority(EventType.work),
          createdAt: day,
          updatedAt: day),
      Event(
          id: '2',
          title: '휴식',
          startAt: DateTime(day.year, day.month, day.day, 15, 0),
          endAt: DateTime(day.year, day.month, day.day, 15, 30),
          type: EventType.rest,
          ratePerHour: null,
          priority: defaultPriority(EventType.rest),
          createdAt: day,
          updatedAt: day),
      Event(
          id: '3',
          title: '수면',
          startAt: DateTime(day.year, day.month, day.day, 23, 30),
          endAt: DateTime(day.year, day.month, day.day + 1, 7, 30),
          type: EventType.sleep,
          ratePerHour: null,
          priority: defaultPriority(EventType.sleep),
          createdAt: day,
          updatedAt: day),
    ];
  }
}
