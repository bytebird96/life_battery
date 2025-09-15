import 'dart:convert'; // Map을 JSON 문자열로 저장하기 위한 패키지

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as dr; // SQL 실행을 위한 Drift 유틸
import 'package:shared_preferences/shared_preferences.dart'; // 로컬 저장소 접근
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
  Map<String, String> eventIcons = {}; // 이벤트 ID별 아이콘 이름을 따로 저장

  Future<void> init() async {
    _db = db.AppDb(); // 로컬 데이터베이스 초기화

    // ------------------------------
    // 앱 재시작 시 마지막 배터리 퍼센트를 복원하기 위해
    // SharedPreferences에서 저장된 값을 읽어온다.
    // 값이 없으면 기본값(설정값)을 그대로 사용한다.
    // ------------------------------
    final prefs = await SharedPreferences.getInstance();
    settings.initialBattery =
        prefs.getDouble('battery') ?? settings.initialBattery;

    // SharedPreferences에 저장된 일정 아이콘 정보를 불러온다.
    final iconJson = prefs.getString('eventIcons');
    if (iconJson != null) {
      try {
        final decoded = jsonDecode(iconJson) as Map<String, dynamic>;
        eventIcons = decoded.map((key, value) => MapEntry(key, value as String));
      } catch (e) {
        // 파싱 실패 시 안전하게 초기화한다.
        eventIcons = {};
      }
    }

    // DB에 저장된 이벤트 목록을 모두 불러온다.
    final result =
        await _db.customSelect('SELECT * FROM events').get(); // 모든 일정 조회
    events = result.map((row) {
      final id = row.data['id'] as String;
      return Event(
        id: id,
        title: row.data['title'] as String,
        content: null, // DB 구조상 내용 컬럼이 없으므로 null 처리
        startAt:
            DateTime.fromMillisecondsSinceEpoch(row.data['start_at'] as int),
        endAt: DateTime.fromMillisecondsSinceEpoch(row.data['end_at'] as int),
        type: EventType.values[row.data['type'] as int],
        ratePerHour: row.data['rate_per_hour'] as double?,
        priority: row.data['priority'] as int,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row.data['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row.data['updated_at'] as int),
        iconName: eventIcons[id] ?? defaultEventIconName,
      );
    }).toList();

    // 시작 시각 기준으로 일정들을 정렬하여 화면에 일정이 섞여 보이지 않도록 한다.
    events.sort((a, b) => a.startAt.compareTo(b.startAt));

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
    // 동일 ID를 가진 일정이 이미 존재하면 제거 후
    // 새 일정으로 대체하여 메모리 목록을 최신 상태로 유지
    events.removeWhere((ex) => ex.id == e.id);
    events.add(e);
    // 새 일정 추가 후 시작 시각 기준으로 다시 정렬
    events.sort((a, b) => a.startAt.compareTo(b.startAt));
    // 아이콘 정보도 별도로 관리하여 다시 앱을 실행해도 복원될 수 있도록 한다.
    eventIcons[e.id] = e.iconName;
    await _saveEventIcons();

    // customInsert는 null 값을 허용하지 않으므로
    // null 이 될 수 있는 ratePerHour를 다루기 위해 customStatement로 변경한다.
    // customStatement의 arguments는 List<Object?> 타입이라 null 전달이 가능하다.
    await _db.customStatement(
      'INSERT OR REPLACE INTO events '
      '(id, title, start_at, end_at, type, rate_per_hour, priority, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        e.id, // 1. 일정 ID (문자열)
        e.title, // 2. 일정 제목
        e.startAt.millisecondsSinceEpoch, // 3. 시작 시각을 밀리초 단위로
        e.endAt.millisecondsSinceEpoch, // 4. 종료 시각을 밀리초 단위로
        e.type.index, // 5. 이벤트 유형(enum)을 인덱스로 저장
        e.ratePerHour, // 6. 시간당 배터리 변화량 (null 허용)
        e.priority, // 7. 우선순위
        e.createdAt.millisecondsSinceEpoch, // 8. 생성 시각(ms)
        e.updatedAt.millisecondsSinceEpoch, // 9. 수정 시각(ms)
      ],
    );
  }

  /// 이벤트 삭제
  Future<void> deleteEvent(String id) async {
    // 1. 메모리 상의 일정 목록에서 해당 ID 삭제
    events.removeWhere((e) => e.id == id);
    eventIcons.remove(id); // 아이콘 정보도 함께 제거
    await _saveEventIcons();

    // 2. 로컬 데이터베이스에서도 같은 ID의 행을 제거
    await _db.customStatement('DELETE FROM events WHERE id = ?', [id]);
  }

  /// 아이콘 정보를 SharedPreferences에 저장하는 헬퍼
  Future<void> _saveEventIcons() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eventIcons', jsonEncode(eventIcons));
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
          updatedAt: day,
          iconName: 'work'),
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
          updatedAt: day,
          iconName: 'rest'),
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
          updatedAt: day,
          iconName: 'sleep'),
    ];
  }
}
