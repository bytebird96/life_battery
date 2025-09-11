import '../data/models.dart';
import 'units.dart';

/// 타입별 기본 우선순위
int defaultPriority(EventType type) {
  switch (type) {
    case EventType.sleep:
      return 3;
    case EventType.rest:
      return 2;
    case EventType.work:
      return 1;
    case EventType.neutral:
      return 0;
  }
}

/// 타입별 기본 rate
double defaultRate(EventType type, UserSettings s) {
  switch (type) {
    case EventType.work:
      return -s.defaultDrainRate;
    case EventType.rest:
      return s.defaultRestRate;
    case EventType.sleep:
      return s.sleepChargeRate;
    case EventType.neutral:
      return 0;
  }
}

/// 이벤트들을 구간으로 분해
List<Interval> resolveIntervals(List<Event> events) {
  final points = <DateTime>{};
  for (var e in events) {
    points.add(e.startAt);
    points.add(e.endAt);
  }
  final sorted = points.toList()..sort();
  final intervals = <Interval>[];
  for (var i = 0; i < sorted.length - 1; i++) {
    final start = sorted[i];
    final end = sorted[i + 1];
    // 활성 이벤트 중 최대 우선순위 선택
    Event? top;
    int pri = -1;
    for (var e in events) {
      if (e.startAt.isBefore(end) && e.endAt.isAfter(start)) {
        final p = e.priority;
        if (p > pri) {
          pri = p;
          top = e;
        }
      }
    }
    intervals.add(Interval(start: start, end: end, top: top));
  }
  return intervals;
}

/// 배터리 타임라인 계산
Map<DateTime, double> simulate(List<Event> events, UserSettings s,
    DateTime start, DateTime end) {
  final intervals = resolveIntervals(events);
  var battery = s.initialBattery;
  final result = <DateTime, double>{};
  DateTime t = start;
  while (t.isBefore(end)) {
    // 해당 시점의 이벤트 찾기
    final interval = intervals.firstWhere(
        (it) => !t.isBefore(it.start) && t.isBefore(it.end),
        orElse: () => Interval(start: t, end: end));
    final e = interval.top;
    double perMin;
    if (e != null) {
      if (e.type == EventType.sleep && s.sleepFullCharge) {
        final remain = e.endAt.difference(t).inMinutes;
        perMin = remain > 0 ? (100 - battery) / remain : 0;
      } else {
        perMin = perHourToPerMinute(e.ratePerHour ?? defaultRate(e.type, s));
      }
    } else {
      perMin = 0;
    }
    result[t] = battery;
    battery += perMin;
    // 오버캡 허용 시 최대 150%, 아니면 100%로 제한
    final double maxCap = s.overcapAllowed ? 150.0 : 100.0;
    if (battery > maxCap) battery = maxCap;
    if (battery < 0) battery = 0;
    t = t.add(const Duration(minutes: 1));
  }
  return result;
}
