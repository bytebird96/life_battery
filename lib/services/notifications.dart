import 'dart:async';
import 'dart:io'; // 플랫폼(OS) 정보를 확인하기 위한 표준 라이브러리

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz; // 타임존 데이터 로드
import 'package:timezone/timezone.dart' as tz; // 일정 시간 계산에 사용

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
    var androidScheduleMode = AndroidScheduleMode.exactAllowWhileIdle;

    if (Platform.isAndroid) {
      // Android 12(API 31) 이상에서는 정확한 알람 권한이 추가되었으므로 확인이 필요하다
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        final sdkInt = await _getAndroidSdkInt();

        if (sdkInt != null && sdkInt >= 31) {
          // 현재 권한 상태를 먼저 조회한다 (이미 허용되어 있다면 추가 요청 불필요)
          var canScheduleExact =
              await androidPlugin.canScheduleExactAlarms() ?? false;

          if (!canScheduleExact) {
            // 권한이 없다면 즉시 권한 요청 다이얼로그를 띄워 사용자에게 한번 더 확인
            canScheduleExact =
                await androidPlugin.requestPermissionToScheduleExactAlarms() ??
                    false;
          }

          if (!canScheduleExact) {
            // 여전히 허용되지 않았다면 설정 앱에서 직접 변경해야 하므로 안내 메시지를 보여준다
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
    if (!Platform.isAndroid) {
      return null; // Android가 아니라면 SDK 버전이 의미가 없으므로 null 처리
    }

    final versionString = Platform.operatingSystemVersion;

    // 대표적인 문자열 예시: "Android 13 (API 33)"
    final apiMatch =
        RegExp('API(?:\\s+Level)?\\s*(\\d+)').firstMatch(versionString);
    if (apiMatch != null) {
      return int.tryParse(apiMatch.group(1)!); // 정규식에서 추출한 숫자를 정수로 변환
    }

    // 제조사에 따라 "SDK 33"과 같은 표현을 쓰기도 하므로 보조 정규식을 한 번 더 확인
    final sdkMatch = RegExp('SDK\\s*(\\d+)').firstMatch(versionString);
    if (sdkMatch != null) {
      return int.tryParse(sdkMatch.group(1)!);
    }

    return null; // 어떤 패턴에도 맞지 않으면 null 반환하여 상위 로직에서 안전하게 처리
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
    const darwin = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: darwin, macOS: darwin);
    await _plugin.show(
      scheduleId.hashCode,
      title,
      body,
      details,
      payload: scheduleId,
    );
  }
}

/// Riverpod에서 사용하기 위한 프로바이더
final notificationProvider =
    Provider<NotificationService>((ref) => throw UnimplementedError());
