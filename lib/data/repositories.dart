import 'dart:convert'; // Map을 JSON 문자열로 저장하기 위한 패키지

import 'package:flutter/foundation.dart'; // ChangeNotifier 사용을 위해 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as dr; // SQL 실행을 위한 Drift 유틸
import 'package:shared_preferences/shared_preferences.dart'; // 로컬 저장소 접근
import '../core/time.dart';
import '../core/compute.dart';
import 'models.dart';
import 'app_db.dart' as db; // Drift에서 생성된 클래스와 이름 충돌 방지

/// 리포지토리 프로바이더
///
/// - ChangeNotifierProvider로 선언해 `notifyListeners()` 호출 시 UI가 자동 갱신되도록 한다.
final repositoryProvider =
    ChangeNotifierProvider<AppRepository>((ref) => throw UnimplementedError());

/// 간단한 리포지토리 구현
class AppRepository extends ChangeNotifier {
  // 기본 제공 일정의 ID를 상수로 관리하여 어디서든 동일한 값을 사용할 수 있게 한다.
  static const String commuteEventId = 'default-commute';
  static const String sleepEventId = 'default-sleep';

  /// Settings 테이블은 단 하나의 레코드만 사용하므로 고정 ID를 부여한다.
  static const int _settingsRowId = 1;

  // 삭제가 금지된 일정 ID를 모아 둔 집합. 새로운 기본 일정이 생기면 여기에만 추가하면 된다.
  static const Set<String> _protectedEventIds = {
    commuteEventId,
    sleepEventId,
  };

  late final db.AppDb _db; // 실제 DB 접근 객체
  UserSettings settings = UserSettings();
  List<Event> events = [];
  Map<String, String> eventIcons = {}; // 이벤트 ID별 아이콘 이름을 따로 저장
  Map<String, String> eventColors = {}; // 이벤트 ID별 색상 이름을 따로 저장

  /// ID를 이용해 특정 이벤트를 찾아주는 헬퍼 메서드
  ///
  /// - 일정 상세 화면 등에서 전달받은 ID로 기존 데이터를 불러올 때 사용한다.
  /// - 일치하는 일정이 없다면 null을 반환해 "신규 등록" 플로우가 자연스럽게 이어지도록 한다.
  Event? findEventById(String id) {
    try {
      return events.firstWhere((event) => event.id == id);
    } catch (_) {
      return null; // 목록에 없으면 null을 반환해 호출측에서 후속 처리를 하도록 위임한다.
    }
  }

  // 특정 ID가 기본 제공 일정인지 확인하는 헬퍼. UI나 삭제 로직에서 재사용된다.
  bool isProtectedEvent(String id) => _protectedEventIds.contains(id);

  Future<void> init() async {
    _db = db.AppDb(); // 로컬 데이터베이스 초기화

    // ------------------------------
    // Settings 테이블에 저장된 사용자 설정을 가장 먼저 읽어와 기본값을 반영한다.
    // 값이 없다면 현재 메모리의 기본 설정을 저장해 최초 레코드를 만든다.
    // ------------------------------
    await _loadSettingsFromDb();

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

    // SharedPreferences에 저장된 일정 색상 정보를 불러온다.
    final colorJson = prefs.getString('eventColors');
    if (colorJson != null) {
      try {
        final decoded = jsonDecode(colorJson) as Map<String, dynamic>;
        eventColors = decoded.map((key, value) => MapEntry(key, value as String));
      } catch (e) {
        eventColors = {}; // 색상 정보 파싱에 실패하면 안전하게 초기화
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
        colorName: eventColors[id] ?? defaultEventColorName,
      );
    }).toList();

    // 시작 시각 기준으로 일정들을 정렬하여 화면에 일정이 섞여 보이지 않도록 한다.
    events.sort((a, b) => a.startAt.compareTo(b.startAt));

    // 기본 제공 일정(출근/수면)이 없으면 자동으로 생성하여 초기 데이터가 항상 유지되도록 한다.
    await _ensureInitialEvents(DateTime.now());
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
    eventColors[e.id] = e.colorName; // 색상 정보도 함께 저장
    await _saveEventIcons();
    await _saveEventColors();

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

    // 일정이 추가/수정되면 구독 중인 위젯이 즉시 갱신될 수 있도록 알린다.
    notifyListeners();
  }

  /// 이벤트 삭제
  Future<void> deleteEvent(String id) async {
    // 기본 제공 일정은 삭제 요청이 들어와도 무시하여 사용자가 실수로 지우지 못하게 한다.
    if (isProtectedEvent(id)) {
      return;
    }
    // 1. 메모리 상의 일정 목록에서 해당 ID 삭제
    events.removeWhere((e) => e.id == id);
    eventIcons.remove(id); // 아이콘 정보도 함께 제거
    eventColors.remove(id); // 색상 정보도 함께 제거
    await _saveEventIcons();
    await _saveEventColors();

    // 2. 로컬 데이터베이스에서도 같은 ID의 행을 제거
    await _db.customStatement('DELETE FROM events WHERE id = ?', [id]);

    // 일정이 삭제되었음을 위젯에 알린다.
    notifyListeners();
  }

  /// 아이콘 정보를 SharedPreferences에 저장하는 헬퍼
  Future<void> _saveEventIcons() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eventIcons', jsonEncode(eventIcons));
  }

  /// 색상 정보를 SharedPreferences에 저장하는 헬퍼
  Future<void> _saveEventColors() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eventColors', jsonEncode(eventColors));
  }

  /// 시뮬레이션 실행
  Map<DateTime, double> simulateDay(DateTime day) {
    // 하루 시작~끝 시각 계산 후 시뮬레이션 실행
    final start = todayStart(day, settings.dayStart);
    final end = start.add(const Duration(days: 1));
    final es = eventsInRange(start, end);
    return simulate(es, settings, start, end);
  }

  /// 사용자 설정을 DB에 저장하고 UI에 알리는 함수
  ///
  /// - settings 필드를 새 값으로 교체한 뒤, Settings 테이블에 upsert한다.
  Future<void> updateUserSettings(UserSettings updated) async {
    settings = updated;
    await _saveSettingsToDb(settings);
    notifyListeners();
  }

  /// 작업/휴식/수면 기본 변화량만 간편하게 갱신할 때 사용할 헬퍼
  Future<void> updateDefaultRates({
    required double defaultDrainRate,
    required double defaultRestRate,
    required double sleepChargeRate,
  }) async {
    settings
      ..defaultDrainRate = defaultDrainRate
      ..defaultRestRate = defaultRestRate
      ..sleepChargeRate = sleepChargeRate;
    await _saveSettingsToDb(settings);
    notifyListeners();
  }

  /// DB에서 사용자 설정을 불러와 [settings] 필드를 최신화한다.
  Future<void> _loadSettingsFromDb() async {
    try {
      final query = await (_db.select(_db.settings)
            ..where((tbl) => tbl.id.equals(_settingsRowId)))
          .getSingleOrNull();
      if (query != null) {
        settings = UserSettings(
          initialBattery: query.initialBattery,
          defaultDrainRate: query.defaultDrainRate,
          defaultRestRate: query.defaultRestRate,
          sleepFullCharge: query.sleepFullCharge,
          sleepChargeRate: query.sleepChargeRate,
          minBatteryForWork: query.minBatteryForWork,
          dayStart: query.dayStart,
          overcapAllowed: query.overcapAllowed,
        );
      } else {
        // 최초 실행이라면 현재 메모리 값을 그대로 저장해 테이블을 초기화한다.
        await _saveSettingsToDb(settings);
      }
    } catch (e) {
      debugPrint('설정 로딩 실패: $e');
    }
  }

  /// Settings 테이블에 현재 설정을 upsert한다.
  Future<void> _saveSettingsToDb(UserSettings source) async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(db.SettingsCompanion.insert(
          id: dr.Value(_settingsRowId),
          initialBattery: source.initialBattery,
          defaultDrainRate: source.defaultDrainRate,
          defaultRestRate: source.defaultRestRate,
          sleepFullCharge: source.sleepFullCharge,
          sleepChargeRate: source.sleepChargeRate,
          minBatteryForWork: source.minBatteryForWork,
          dayStart: source.dayStart,
          overcapAllowed: source.overcapAllowed,
        ));
  }

  // 출근/수면 기본 일정을 DB와 메모리에 보장하는 헬퍼. 여러 번 호출되어도 중복 저장되지 않는다.
  Future<void> _ensureInitialEvents(DateTime day) async {
    final initialEvents = _buildInitialEvents(day); // 기준 날짜를 바탕으로 기본 일정 생성

    for (final event in initialEvents) {
      final exists = events.any((e) => e.id == event.id); // 이미 저장되어 있는지 확인
      if (!exists) {
        await saveEvent(event); // 없으면 새로 저장하여 DB와 메모리에 반영
      }
    }
  }

  // 기준 날짜를 이용해 "출근"과 "수면" 일정 두 개를 만들어 반환한다.
  List<Event> _buildInitialEvents(DateTime day) {
    final now = DateTime.now(); // 생성/수정 시각은 호출 시점 기준으로 기록한다.

    // 출근 일정은 오전 9시부터 오후 6시까지로 기본 설정한다.
    final commuteStart = DateTime(day.year, day.month, day.day, 9, 0);
    final commuteEnd = DateTime(day.year, day.month, day.day, 18, 0);

    // 수면 일정은 밤 11시부터 다음 날 아침 7시까지로 기본 설정한다.
    final sleepStart = DateTime(day.year, day.month, day.day, 23, 0);
    final sleepEnd = sleepStart.add(const Duration(hours: 8));

    return [
      Event(
        id: commuteEventId,
        title: '출근',
        content: '아침 출근 시간',
        startAt: commuteStart,
        endAt: commuteEnd,
        type: EventType.work,
        ratePerHour: null,
        priority: defaultPriority(EventType.work),
        createdAt: now,
        updatedAt: now,
        iconName: 'work',
        colorName: 'purple',
      ),
      Event(
        id: sleepEventId,
        title: '수면',
        content: '숙면 시간',
        startAt: sleepStart,
        endAt: sleepEnd,
        type: EventType.sleep,
        ratePerHour: null,
        priority: defaultPriority(EventType.sleep),
        createdAt: now,
        updatedAt: now,
        iconName: 'sleep',
        colorName: 'blue',
      ),
    ];
  }
}
