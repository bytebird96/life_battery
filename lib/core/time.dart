import 'package:intl/intl.dart';

/// HH:mm 형식의 문자열을 DateTime의 당일 시각으로 변환
DateTime parseDayStart(DateTime day, String hhmm) {
  final parts = hhmm.split(':');
  return DateTime(day.year, day.month, day.day,
      int.parse(parts[0]), int.parse(parts[1]));
}

/// dayStart 기준 오늘 시작 시각 계산
DateTime todayStart(DateTime now, String dayStart) {
  final start = parseDayStart(now, dayStart);
  if (now.isBefore(start)) {
    // 시작 이전이면 전날로 이동
    final yesterday = now.subtract(const Duration(days: 1));
    return parseDayStart(yesterday, dayStart);
  }
  return start;
}

/// 분 단위 정렬
DateTime alignMinute(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);

/// HH:mm 포맷 출력
String formatTime(DateTime dt) => DateFormat('HH:mm').format(dt);
