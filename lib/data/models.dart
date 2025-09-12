import 'package:drift/drift.dart' show Value;
import '../core/time.dart';

/// 이벤트 종류
enum EventType { work, rest, sleep, neutral }

/// 이벤트 데이터 모델
class Event {
  final String id;
  final String title;
  final String? content; // 일정에 대한 상세 설명 (없을 수도 있음)
  final DateTime startAt;
  final DateTime endAt;
  final EventType type;
  final double? ratePerHour;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  Event({
    required this.id,
    required this.title,
    this.content,
    required this.startAt,
    required this.endAt,
    required this.type,
    this.ratePerHour,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// 사용자 설정 모델
class UserSettings {
  double initialBattery;
  double defaultDrainRate;
  double defaultRestRate;
  bool sleepFullCharge;
  double sleepChargeRate;
  double minBatteryForWork;
  String dayStart;
  bool overcapAllowed;

  UserSettings({
    this.initialBattery = 80,
    this.defaultDrainRate = 5,
    this.defaultRestRate = 3,
    this.sleepFullCharge = true,
    this.sleepChargeRate = 12,
    this.minBatteryForWork = 20,
    this.dayStart = '05:00',
    this.overcapAllowed = false,
  });
}

/// 우선순위 해소 후 구간
class Interval {
  final DateTime start;
  final DateTime end;
  final Event? top; // 적용된 이벤트

  Interval({required this.start, required this.end, this.top});
}
