import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 알림 서비스
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: android);
    await _plugin.initialize(init);
  }

  Future<void> showLowBattery() async {
    const details = NotificationDetails(
        android: AndroidNotificationDetails('low', '낮은 배터리'));
    await _plugin.show(0, '배터리 부족', '작업 시작 전에 충전 필요', details);
  }
}

final notificationProvider = Provider<NotificationService>((ref) => throw UnimplementedError());
