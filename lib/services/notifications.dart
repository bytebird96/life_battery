import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    // 플러그인 실제 초기화 수행
    await _plugin.initialize(init);

    // 안드로이드 13(API 33) 이상에서는 알림 권한이 기본적으로 꺼져 있으므로
    // 명시적으로 사용자에게 권한 허용을 요청한다
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestPermission();

    // iOS와 macOS에서도 알림, 뱃지, 소리 권한을 각각 요청해야 함
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true, badge: true);
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
}

/// Riverpod에서 사용하기 위한 프로바이더
final notificationProvider =
    Provider<NotificationService>((ref) => throw UnimplementedError());
