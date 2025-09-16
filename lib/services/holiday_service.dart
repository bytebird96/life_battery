import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 공휴일 여부를 판정하는 간단한 서비스
///
/// - assets/holidays.json 파일이 존재하면 해당 데이터를 읽어 추가 공휴일을 반영한다.
/// - 파일이 없거나 로드에 실패하면 주말만 공휴일로 취급한다.
class HolidayService {
  Map<String, bool>? _holidayMap;

  /// 앱 시작 시 한 번 호출하여 공휴일 데이터를 메모리에 적재
  Future<void> load() async {
    try {
      final json = await rootBundle.loadString('assets/holidays.json');
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      _holidayMap = decoded.map((key, value) => MapEntry(key, value as bool));
    } catch (_) {
      // 파일이 없거나 포맷이 잘못된 경우에는 단순 주말 판정으로 동작
      _holidayMap = null;
    }
  }

  /// 주어진 날짜가 공휴일인지 여부
  Future<bool> isHoliday(DateTime date) async {
    // 주말(토/일)은 기본적으로 휴일 처리
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return true;
    }
    final map = _holidayMap;
    if (map == null) {
      return false;
    }
    final key = _dateKey(date);
    return map[key] ?? false;
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Riverpod에서 의존성을 주입하기 위한 프로바이더
final holidayServiceProvider =
    Provider<HolidayService>((ref) => throw UnimplementedError());
