import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz; // 타임존 데이터 로드
import 'package:timezone/timezone.dart' as tz; // 일정 시간 계산에 사용

import 'platform/platform_helper.dart'; // 플랫폼 분기 처리를 위한 헬퍼

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationService._onBackgroundNotificationResponse(response);
}

/// 로컬 알림을 처리하는 서비스
class NotificationService {
  NotificationService() {
    _instance = this;
  }

  /// 플러그인 인스턴스. 각 플랫폼에서 공통으로 사용한다.
  final _plugin = FlutterLocalNotificationsPlugin();
  final _payloadController = StreamController<String>.broadcast();

  static NotificationService? _instance;

  Stream<String> get payloadStream => _payloadController.stream;

  /// 초기화 메서드
  ///
  /// macOS에서 실행될 때는 반드시 macOS 설정을 포함해야 하므로
  /// `DarwinInitializationSettings`를 함께 전달한다.
  Future<void> init() async {
    // 안드로이드용 기본 아이콘 설정
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS와 macOS가 공통으로 사용하는 초기화 설정
    const darwin = DarwinInitializationSettings(
      // iOS/macOS는 처음 실행 시 사용자에게 알림 권한을 요청해야 함
      // 아래 옵션들을 true로 지정하면 앱 시작과 동시에 권한 창이 뜬다
      requestAlertPermission: true, // 화면에 알림 배너를 띄울 수 있는지
      requestBadgePermission: true, // 앱 아이콘에 숫자 뱃지를 표시할 수 있는지
      requestSoundPermission: true, // 알림 시 소리를 재생할 수 있는지
    );
    // 플랫폼별 설정을 하나로 묶어서 전달
    const init = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    // 타임존 정보를 초기화하여 정확한 예약 알림 시간을 계산
    tz.initializeTimeZones();
    // 플러그인 실제 초기화 수행
    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // 안드로이드 13(API 33) 이상에서는 알림 권한이 기본적으로 꺼져 있으므로
    // 명시적으로 사용자에게 권한 허용을 요청한다
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        // 플러그인 17 버전 이상에서는 메서드명이 requestNotificationsPermission으로 변경됨
        // 알림 권한을 요청하여 사용자에게 허용 여부를 묻는다
        ?.requestNotificationsPermission();

    // iOS와 macOS에서도 알림, 뱃지, 소리 권한을 각각 요청해야 함
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true, badge: true);
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      _payloadController.add(payload);
    }
  }

  static void _onBackgroundNotificationResponse(
      NotificationResponse response) {
    _instance?._handleNotificationResponse(response);
  }

  /// 배터리가 부족할 때 보여주는 간단한 알림
  Future<void> showLowBattery() async {
    // 플랫폼별 알림 상세 설정
    const android = AndroidNotificationDetails('low', '낮은 배터리');
    // iOS/macOS에서 포그라운드 상태여도 배너/소리/뱃지가 표시되도록 명시적으로 true 지정
    const darwin = DarwinNotificationDetails(
      presentAlert: true, // 화면 상단에 배너 표시 허용
      presentSound: true, // 알림 사운드 재생 허용
      presentBadge: true, // 앱 아이콘 뱃지 갱신 허용
    );
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
    // iOS/macOS에서도 예약 알림이 포그라운드에서 정상적으로 울리도록 옵션 명시
    const darwin = DarwinNotificationDetails(
      presentAlert: true, // 배너를 반드시 노출
      presentSound: true, // 사운드를 재생하여 사용자가 인지하기 쉽게 함
      presentBadge: true, // 완료 알림 시 아이콘 뱃지를 갱신할 수 있게 허용
    );
    const details = NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    var androidScheduleMode = AndroidScheduleMode.exactAllowWhileIdle;

    if (platformHelper.isAndroid) {
      // Android 단말에서만 정확한 알람 권한을 확인하면 되므로 우선 안드로이드용 플러그인 인스턴스를 가져온다
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // 아래 헬퍼가 실제로 권한을 요청하고 결과를 true/false로 반환한다
        final hasExactPermission =
            await _ensureExactAlarmPermission(androidPlugin);

        if (!hasExactPermission) {
          // 권한이 허용되지 않은 경우에는 정확한 알람을 사용할 수 없으므로
          // 시스템이 허용하는 범위 내(대략적인 시간)에서 알람을 울리는 모드로 폴백한다
          androidScheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;

          const guideAndroidDetails = AndroidNotificationDetails(
            'exact_alarm_permission',
            '정확한 알람 권한 안내',
            channelDescription: '정확한 알람 권한이 비활성화된 경우 안내용 알림',
            importance: Importance.max,
            priority: Priority.high,
          );
          const guideDetails =
              NotificationDetails(android: guideAndroidDetails);

          await _plugin.show(
            id + 1000000, // 예약 알림과 겹치지 않도록 충분히 큰 오프셋을 더한다
            '정확한 알람 권한 필요',
            '정확한 시간에 알림을 받으려면 설정 앱에서 정확한 알람 권한을 허용해 주세요.',
            guideDetails,
          );
        }
      }
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // 대기 모드에서도 정확한 시간에 알림을 울리도록 설정
      androidScheduleMode: androidScheduleMode,
    );
  }

  /// 현재 단말의 안드로이드 SDK 버전을 반환한다. (다른 플랫폼은 null)
  Future<int?> _getAndroidSdkInt() async {
    // 플랫폼 헬퍼가 알아서 안드로이드 여부와 SDK 버전을 판단한다.
    // 웹이나 다른 플랫폼에서는 null이 반환되므로 호출부에서 안전하게 처리 가능하다.
    return platformHelper.getAndroidSdkInt();
  }

  /// 예약된 알림 취소
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// 지오펜스 트리거로 즉시 노출하는 알림
  Future<void> showScheduleReminder({
    required String scheduleId,
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      'geofence',
      '위치 알림',
      importance: Importance.max,
      priority: Priority.high,
    );
    // 위치 기반 즉시 알림도 포그라운드에서 배너/사운드가 나오도록 동일하게 설정
    const darwin = DarwinNotificationDetails(
      presentAlert: true, // 배너를 표시하여 사용자가 즉시 확인할 수 있도록 함
      presentSound: true, // 사운드를 통해 인지를 돕는다
      presentBadge: true, // 아이콘 뱃지 업데이트 허용
    );
    const details = NotificationDetails(android: android, iOS: darwin, macOS: darwin);
    await _plugin.show(
      scheduleId.hashCode,
      title,
      body,
      details,
      payload: scheduleId,
    );
  }

  /// Android 12(API 31) 이상에서 정확한 알람을 사용할 수 있도록 권한을 확인/요청한다.
  ///
  /// - [androidPlugin] : 안드로이드 전용 알림 플러그인 인스턴스
  /// - return          : 정확한 알람 사용이 가능한 경우 true, 그렇지 않으면 false
  Future<bool> _ensureExactAlarmPermission(
    AndroidFlutterLocalNotificationsPlugin androidPlugin,
  ) async {
    // API 31 미만에서는 별도의 권한이 존재하지 않으므로 그대로 true를 반환한다
    final sdkInt = await _getAndroidSdkInt();
    if (sdkInt != null && sdkInt < 31) {
      return true;
    }

    try {
      // 플러그인의 일부 버전에서는 canScheduleExactAlarms / requestPermissionToScheduleExactAlarms
      // 메서드가 없을 수도 있으므로, dynamic으로 호출하고 예외를 안전하게 처리한다
      final dynamic dynamicPlugin = androidPlugin;

      final canScheduleExact =
          await dynamicPlugin.canScheduleExactAlarms() as bool? ?? false;
      if (canScheduleExact) {
        return true; // 이미 권한이 허용된 상태이므로 추가 조치 없음
      }

      final granted = await dynamicPlugin
              .requestPermissionToScheduleExactAlarms() as bool? ??
          false;
      return granted;
    } catch (_) {
      // 메서드가 존재하지 않거나 호출 시 오류가 발생하면 (주로 구버전 안드로이드나 플러그인 버전 차이)
      // 정확한 알람을 신뢰할 수 없으므로 false를 반환하여 상위 로직에서 폴백하도록 한다
      return false;
    }
  }
}

/// Riverpod에서 사용하기 위한 프로바이더
final notificationProvider =
    Provider<NotificationService>((ref) => throw UnimplementedError());
