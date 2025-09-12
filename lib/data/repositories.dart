import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as dr; // SQL 실행을 위한 Drift 유틸
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

    // DB에 저장된 이벤트 목록을 모두 불러온다.
    final result = await _db.customSelect('SELECT * FROM events').get();
    events = result
        .map((row) => Event(
              id: row.data['id'] as String,
              title: row.data['title'] as String,
              content: null, // DB 구조상 내용 컬럼이 없으므로 null 처리
              startAt: DateTime.fromMillisecondsSinceEpoch(
                  row.data['start_at'] as int),
              endAt:
                  DateTime.fromMillisecondsSinceEpoch(row.data['end_at'] as int),
              type: EventType.values[row.data['type'] as int],
              ratePerHour: row.data['rate_per_hour'] as double?,
              priority: row.data['priority'] as int,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                  row.data['created_at'] as int),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(
                  row.data['updated_at'] as int),
            ))
        .toList();

    // 저장된 이벤트가 하나도 없다면 더미 데이터를 추가하고 DB에도 저장한다.
    if (events.isEmpty) {
      await addDummy(DateTime.now());
      // addDummy에서 생성한 리스트를 복사해 DB에 저장
      final dummy = List<Event>.from(events);
      for (final e in dummy) {
        await saveEvent(e); // DB에 저장
      }
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
    // 동일 ID 이벤트가 있으면 교체
    events.removeWhere((ex) => ex.id == e.id);
    events.add(e);

    // 로컬 데이터베이스에 upsert 수행
    await _db.customInsert(
      'INSERT OR REPLACE INTO events '
      '(id, title, start_at, end_at, type, rate_per_hour, priority, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        dr.Variable<String>(e.id),
        dr.Variable<String>(e.title),
        dr.Variable<int>(e.startAt.millisecondsSinceEpoch),
        dr.Variable<int>(e.endAt.millisecondsSinceEpoch),
        dr.Variable<int>(e.type.index),
        dr.Variable<double?>(e.ratePerHour),
        dr.Variable<int>(e.priority),
        dr.Variable<int>(e.createdAt.millisecondsSinceEpoch),
        dr.Variable<int>(e.updatedAt.millisecondsSinceEpoch),
      ],
    );
  }

  /// 이벤트 삭제
  Future<void> deleteEvent(String id) async {
    // 메모리 상의 리스트에서 제거
    events.removeWhere((e) => e.id == id);

    // 로컬 데이터베이스에서도 삭제
    await _db.customStatement('DELETE FROM events WHERE id = ?', [id]);
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
  }
}
