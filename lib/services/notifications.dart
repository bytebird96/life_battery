import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz; // 타임존 데이터 로드
import 'package:timezone/timezone.dart' as tz; // 일정 시간 계산에 사용

/// 로컬 알림을 처리하는 서비스
class NotificationService {
  /// 플러그인 인스턴스. 각 플랫폼에서 공통으로 사용한다.
  final _plugin = FlutterLocalNotificationsPlugin();

  /// 초기화 메서드
  ///
  /// macOS에서 실행될 때는 반드시 macOS 설정을 포함해야 하므로
  /// `DarwinInitializationSettings`를 함께 전달한다.
  Future<void> init() async {
    // 안드로이드용 기본 아이콘 설정
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS와 macOS가 공통으로 사용하는 초기화 설정
    const darwin = DarwinInitializationSettings();
    // 플랫폼별 설정을 하나로 묶어서 전달
    const init = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    // 타임존 정보를 초기화하여 정확한 예약 알림 시간을 계산
    tz.initializeTimeZones();
    // 플러그인 실제 초기화 수행
    await _plugin.initialize(init);
  }

  /// 배터리가 부족할 때 보여주는 간단한 알림
  Future<void> showLowBattery() async {
    // 플랫폼별 알림 상세 설정
    const android = AndroidNotificationDetails('low', '낮은 배터리');
    const darwin = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    // 실제 알림 표시
    await _plugin.show(0, '배터리 부족', '작업 시작 전에 충전 필요', details);
  }

  /// 일정 완료 시점에 맞춰 알림을 예약
  /// - [id]        알림 식별자 (일정 ID의 hashCode 사용)
  /// - [title]     알림 제목
  /// - [body]      알림 본문
  /// - [after]     얼마나 뒤에 알림을 표시할지
  Future<void> scheduleComplete({
    required int id,
    required String title,
    required String body,
    required Duration after,
  }) async {
    final scheduled = tz.TZDateTime.now(tz.local).add(after); // 현재 시각 기준 예약
    const android = AndroidNotificationDetails('done', '일정 완료');
    const darwin = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      androidAllowWhileIdle: true,
    );
  }

  /// 예약된 알림 취소
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }
}

/// Riverpod에서 사용하기 위한 프로바이더
final notificationProvider =
    Provider<NotificationService>((ref) => throw UnimplementedError());
