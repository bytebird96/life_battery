import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/time.dart';
import '../core/compute.dart';
import 'models.dart';
import 'app_db.dart' as db; // Drift에서 생성된 클래스와 이름 충돌 방지
import 'package:drift/drift.dart' show Value; // DB Companion 생성을 위한 Value

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
    // ===============================
    // DB에서 기존 이벤트 불러오기
    // ===============================
    final rows = await _db.select(_db.events).get();
    events = rows.map(_fromDb).toList(); // 변환 후 리스트에 저장
    // DB가 비어 있으면 초깃값으로 더미 데이터 추가
    if (events.isEmpty) {
      await addDummy(DateTime.now());
    }
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
    // ===============================
    // DB에 이벤트 저장 (있으면 갱신)
    // ===============================
    final companion = _toCompanion(e);
    await _db.into(_db.events).insertOnConflictUpdate(companion);
    // =========================================
    // 메모리상 리스트에서도 동일 ID를 제거 후 추가
    // =========================================
    events.removeWhere((ex) => ex.id == e.id); // 기존 항목 제거
    events.add(e); // 새 항목 추가
  }

  /// 이벤트 삭제
  Future<void> deleteEvent(String id) async {
    // ===============================
    // DB에서 해당 ID 이벤트 삭제
    // ===============================
    await (_db.delete(_db.events)..where((tbl) => tbl.id.equals(id))).go();
    // ===============================
    // 메모리상 리스트에서도 제거
    // ===============================
    events.removeWhere((e) => e.id == id); // ID 일치 이벤트 제거
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
    final dummyEvents = [
      Event(
          id: '1',
          title: '작업',
          content: '프로젝트 진행',
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
          content: '가벼운 산책',
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
          content: '밤사이 휴식',
          startAt: DateTime(day.year, day.month, day.day, 23, 30),
          endAt: DateTime(day.year, day.month, day.day + 1, 7, 30),
          type: EventType.sleep,
          ratePerHour: null,
          priority: defaultPriority(EventType.sleep),
          createdAt: day,
          updatedAt: day),
    ];
    // 생성한 이벤트들을 실제 DB 및 리스트에 저장
    for (final e in dummyEvents) {
      await saveEvent(e); // DB와 메모리 리스트에 동시 반영
    }
  }

  // ==========================================================
  // 아래는 Event <-> DB 모델 간 변환을 담당하는 헬퍼 메소드들
  // ==========================================================

  /// DB에서 읽은 EventsData를 Event 객체로 변환
  Event _fromDb(db.Event data) {
    return Event(
      id: data.id,
      title: data.title,
      content: null, // 현재 DB 스키마에는 content 컬럼이 없어 임시로 null 처리
      startAt: DateTime.fromMillisecondsSinceEpoch(data.startAt),
      endAt: DateTime.fromMillisecondsSinceEpoch(data.endAt),
      type: EventType.values[data.type],
      ratePerHour: data.ratePerHour,
      priority: data.priority,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data.updatedAt),
    );
  }

  /// Event 객체를 DB에 저장하기 위한 Companion으로 변환
  db.EventsCompanion _toCompanion(Event e) {
    return db.EventsCompanion(
      id: Value(e.id),
      title: Value(e.title),
      startAt: Value(e.startAt.millisecondsSinceEpoch),
      endAt: Value(e.endAt.millisecondsSinceEpoch),
      type: Value(e.type.index),
      ratePerHour: Value(e.ratePerHour),
      priority: Value(e.priority),
      createdAt: Value(e.createdAt.millisecondsSinceEpoch),
      updatedAt: Value(e.updatedAt.millisecondsSinceEpoch),
    );
  }
}
