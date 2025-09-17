import 'package:flutter/foundation.dart';

/// 지오펜스 트리거 종류 (도착/이탈)
enum ScheduleTriggerType { arrive, exit }

/// 요일/공휴일 조건
/// - WEEKDAY: 월~금
/// - NON_HOLIDAY: 공휴일 제외(기본 구현에서는 주말 제외와 동일하게 처리)
/// - ALWAYS: 제한 없음
enum ScheduleDayCondition { weekday, nonHoliday, always }

/// 미리 정의된 일정 유형(알림 문구 결정)
enum SchedulePresetType { commuteIn, commuteOut, move, workout }

/// 지오펜스가 발동했을 때 자동으로 실행할 동작 종류
///
/// - none: 알림만 보내고 추가 자동 실행은 하지 않는다.
/// - startEvent: 연결된 이벤트를 자동으로 시작한다.
/// - stopEvent: 실행 중인 이벤트를 자동으로 종료(완료 처리)한다.
enum ScheduleAutoAction { none, startEvent, stopEvent }

/// 지오펜스 일정 모델
///
/// DB에는 문자열과 정수로 저장하되, 앱 내부에서는 enum과 DateTime으로 다룬다.
class Schedule {
  final String id;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final bool useLocation;
  final String? placeName;
  final double? lat;
  final double? lng;
  final double? radiusMeters;
  final ScheduleTriggerType triggerType;
  final ScheduleDayCondition dayCondition;
  final SchedulePresetType presetType;
  final bool remindIfNotExecuted;
  final bool executed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ScheduleAutoAction autoAction;

  const Schedule({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.useLocation,
    this.placeName,
    this.lat,
    this.lng,
    this.radiusMeters,
    required this.triggerType,
    required this.dayCondition,
    required this.presetType,
    required this.remindIfNotExecuted,
    required this.executed,
    required this.createdAt,
    required this.updatedAt,
    this.autoAction = ScheduleAutoAction.none,
  });

  /// 신규 일정 생성 시에 사용할 헬퍼.
  Schedule copyWith({
    String? id,
    String? title,
    DateTime? startAt,
    DateTime? endAt,
    bool? useLocation,
    String? placeName,
    double? lat,
    double? lng,
    double? radiusMeters,
    ScheduleTriggerType? triggerType,
    ScheduleDayCondition? dayCondition,
    SchedulePresetType? presetType,
    bool? remindIfNotExecuted,
    bool? executed,
    DateTime? createdAt,
    DateTime? updatedAt,
    ScheduleAutoAction? autoAction,
  }) {
    return Schedule(
      id: id ?? this.id,
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      useLocation: useLocation ?? this.useLocation,
      placeName: placeName ?? this.placeName,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      triggerType: triggerType ?? this.triggerType,
      dayCondition: dayCondition ?? this.dayCondition,
      presetType: presetType ?? this.presetType,
      remindIfNotExecuted: remindIfNotExecuted ?? this.remindIfNotExecuted,
      executed: executed ?? this.executed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      autoAction: autoAction ?? this.autoAction,
    );
  }

  /// DB에 저장하기 위한 Map 변환
  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'title': title,
      'start_at': startAt.millisecondsSinceEpoch,
      'end_at': endAt.millisecondsSinceEpoch,
      'use_location': useLocation ? 1 : 0,
      'place_name': placeName,
      'lat': lat,
      'lng': lng,
      'radius_meters': radiusMeters,
      'trigger_type': _triggerToDb(triggerType),
      'day_condition': _dayConditionToDb(dayCondition),
      'preset_type': _presetToDb(presetType),
      'remind_if_not_executed': remindIfNotExecuted ? 1 : 0,
      'executed': executed ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'auto_action': _autoActionToDb(autoAction),
    };
  }

  /// DB에서 읽어온 값을 Schedule 인스턴스로 변환
  factory Schedule.fromDbMap(Map<String, Object?> json) {
    return Schedule(
      id: json['id'] as String,
      title: json['title'] as String,
      startAt: DateTime.fromMillisecondsSinceEpoch(json['start_at'] as int),
      endAt: DateTime.fromMillisecondsSinceEpoch(json['end_at'] as int),
      useLocation: (json['use_location'] as int) == 1,
      placeName: json['place_name'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      radiusMeters: (json['radius_meters'] as num?)?.toDouble(),
      triggerType: _triggerFromDb(json['trigger_type'] as String),
      dayCondition: _dayConditionFromDb(json['day_condition'] as String),
      presetType: _presetFromDb(json['preset_type'] as String),
      remindIfNotExecuted: (json['remind_if_not_executed'] as int) == 1,
      executed: (json['executed'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
      autoAction: _autoActionFromDb(json['auto_action'] as String?),
    );
  }

  /// 프리셋에 따른 기본 알림 문구
  String get presetMessage {
    switch (presetType) {
      case SchedulePresetType.commuteIn:
        return '출근 중이신가요?';
      case SchedulePresetType.commuteOut:
        return '퇴근 중이신가요?';
      case SchedulePresetType.move:
        return '이동 중이신가요?';
      case SchedulePresetType.workout:
        return '운동 중이신가요?';
    }
  }
}

/// 지오펜스 이벤트 로그 모델
class ScheduleLogEntry {
  final int id;
  final String? scheduleId;
  final String message;
  final DateTime createdAt;

  const ScheduleLogEntry({
    required this.id,
    this.scheduleId,
    required this.message,
    required this.createdAt,
  });

  factory ScheduleLogEntry.fromDbMap(Map<String, Object?> json) {
    return ScheduleLogEntry(
      id: json['id'] as int,
      scheduleId: json['schedule_id'] as String?,
      message: json['message'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
    );
  }
}

String _triggerToDb(ScheduleTriggerType type) {
  switch (type) {
    case ScheduleTriggerType.arrive:
      return 'ARRIVE';
    case ScheduleTriggerType.exit:
      return 'EXIT';
  }
}

ScheduleTriggerType _triggerFromDb(String raw) {
  switch (raw) {
    case 'EXIT':
      return ScheduleTriggerType.exit;
    case 'ARRIVE':
    default:
      return ScheduleTriggerType.arrive;
  }
}

String _dayConditionToDb(ScheduleDayCondition condition) {
  switch (condition) {
    case ScheduleDayCondition.weekday:
      return 'WEEKDAY';
    case ScheduleDayCondition.nonHoliday:
      return 'NON_HOLIDAY';
    case ScheduleDayCondition.always:
      return 'ALWAYS';
  }
}

ScheduleDayCondition _dayConditionFromDb(String raw) {
  switch (raw) {
    case 'WEEKDAY':
      return ScheduleDayCondition.weekday;
    case 'NON_HOLIDAY':
      return ScheduleDayCondition.nonHoliday;
    case 'ALWAYS':
    default:
      return ScheduleDayCondition.always;
  }
}

String _presetToDb(SchedulePresetType preset) {
  switch (preset) {
    case SchedulePresetType.commuteIn:
      return 'COMMUTE_IN';
    case SchedulePresetType.commuteOut:
      return 'COMMUTE_OUT';
    case SchedulePresetType.move:
      return 'MOVE';
    case SchedulePresetType.workout:
      return 'WORKOUT';
  }
}

SchedulePresetType _presetFromDb(String raw) {
  switch (raw) {
    case 'COMMUTE_IN':
      return SchedulePresetType.commuteIn;
    case 'COMMUTE_OUT':
      return SchedulePresetType.commuteOut;
    case 'MOVE':
      return SchedulePresetType.move;
    case 'WORKOUT':
    default:
      return SchedulePresetType.workout;
  }
}

String _autoActionToDb(ScheduleAutoAction action) {
  switch (action) {
    case ScheduleAutoAction.startEvent:
      return 'START_EVENT';
    case ScheduleAutoAction.stopEvent:
      return 'STOP_EVENT';
    case ScheduleAutoAction.none:
    default:
      return 'NONE';
  }
}

ScheduleAutoAction _autoActionFromDb(String? raw) {
  switch (raw) {
    case 'START_EVENT':
      return ScheduleAutoAction.startEvent;
    case 'STOP_EVENT':
      return ScheduleAutoAction.stopEvent;
    case 'NONE':
    default:
      return ScheduleAutoAction.none;
  }
}

/// enum을 보기 좋은 한글 라벨로 변환하는 간단한 확장
extension ScheduleEnumLabel on Enum {
  String get koLabel {
    switch (this) {
      case ScheduleTriggerType.arrive:
        return '도착 시';
      case ScheduleTriggerType.exit:
        return '이탈 시';
      case ScheduleDayCondition.weekday:
        return '평일만';
      case ScheduleDayCondition.nonHoliday:
        return '비휴일만';
      case ScheduleDayCondition.always:
        return '상시';
      case SchedulePresetType.commuteIn:
        return '출근';
      case SchedulePresetType.commuteOut:
        return '퇴근';
      case SchedulePresetType.move:
        return '이동';
      case SchedulePresetType.workout:
        return '운동';
      case ScheduleAutoAction.none:
        return '자동 실행 안 함';
      case ScheduleAutoAction.startEvent:
        return '연결된 이벤트 자동 시작';
      case ScheduleAutoAction.stopEvent:
        return '연결된 이벤트 자동 종료';
      default:
        return name;
    }
  }
}
