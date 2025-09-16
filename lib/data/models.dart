import 'package:drift/drift.dart' show Value;
import '../core/time.dart';

/// 이벤트 종류
enum EventType { work, rest, sleep, neutral }

/// 이벤트 기본 아이콘 키
///
/// - DB 또는 설정에 저장된 아이콘 정보가 없을 때 사용한다.
/// - 실제 아이콘 매핑은 features/event/event_icons.dart에서 관리한다.
const String defaultEventIconName = 'work';

/// 이벤트 기본 색상 키
///
/// - 사용자가 별도의 색을 지정하지 않았을 때 사용할 기본값이다.
/// - 실제 색상 매핑은 features/event/event_colors.dart에서 관리한다.
const String defaultEventColorName = 'purple';

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
  final String iconName; // UI에서 사용할 아이콘 식별자(문자열로 관리)
  final String colorName; // UI에서 사용할 색상 식별자(문자열로 관리)

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
    this.iconName = defaultEventIconName, // 별도 지정이 없으면 기본 아이콘 사용
    this.colorName = defaultEventColorName, // 별도 지정이 없으면 기본 색상 사용
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
    this.initialBattery = 70, // 디자인과 동일하게 기본 배터리를 70%로 설정
    this.defaultDrainRate = 5,
    this.defaultRestRate = 3,
    this.sleepFullCharge = true,
    this.sleepChargeRate = 12,
    this.minBatteryForWork = 20,
    this.dayStart = '05:00',
    this.overcapAllowed = false,
  });

  /// copyWith를 제공해 UI나 저장소에서 일부 값만 변경할 수 있도록 한다.
  ///
  /// - 초보자도 직관적으로 이해할 수 있게, 필요한 값만 전달하면 나머지는 기존 값이 유지된다.
  UserSettings copyWith({
    double? initialBattery,
    double? defaultDrainRate,
    double? defaultRestRate,
    bool? sleepFullCharge,
    double? sleepChargeRate,
    double? minBatteryForWork,
    String? dayStart,
    bool? overcapAllowed,
  }) {
    return UserSettings(
      initialBattery: initialBattery ?? this.initialBattery,
      defaultDrainRate: defaultDrainRate ?? this.defaultDrainRate,
      defaultRestRate: defaultRestRate ?? this.defaultRestRate,
      sleepFullCharge: sleepFullCharge ?? this.sleepFullCharge,
      sleepChargeRate: sleepChargeRate ?? this.sleepChargeRate,
      minBatteryForWork: minBatteryForWork ?? this.minBatteryForWork,
      dayStart: dayStart ?? this.dayStart,
      overcapAllowed: overcapAllowed ?? this.overcapAllowed,
    );
  }
}

/// 우선순위 해소 후 구간
class Interval {
  final DateTime start;
  final DateTime end;
  final Event? top; // 적용된 이벤트

  Interval({required this.start, required this.end, this.top});
}
