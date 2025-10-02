import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/repositories.dart';
import '../data/schedule_db.dart';
import '../data/schedule_models.dart';
import '../data/schedule_repository.dart';
import '../services/geofence_manager.dart';
import '../services/holiday_service.dart';
import '../services/notifications.dart';

/// iOS가 백그라운드에서 앱을 깨웠을 때 실행할 전용 엔트리 포인트
///
/// * `@pragma('vm:entry-point')`을 지정해야 트리밍 과정에서 제거되지 않는다.
/// * UI가 없는 헤드리스 엔진에서도 `WidgetsFlutterBinding`을 초기화해야
///   플러그인이 안전하게 동작할 수 있다.
@pragma('vm:entry-point')
Future<void> geofenceBackgroundMain() async {
  // ▼ UI를 띄우지 않더라도 플러그인 채널을 사용할 수 있도록 바인딩을 초기화한다.
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ▼ 지오펜스 이벤트 발생 시 즉시 알림을 보낼 수 있도록 로컬 알림 플러그인을 준비한다.
    final notificationService = NotificationService();
    await notificationService.init();

    // ▼ 지오펜스 판단에 필요한 공휴일 정보와 DB를 열어 레포지토리를 구성한다.
    final holidayService = HolidayService();
    final scheduleDb = ScheduleDb();
    final scheduleRepository =
        ScheduleRepository(db: scheduleDb, holidayService: holidayService);
    await scheduleRepository.init();

    // ▼ DB에서 일정을 불러와 지오펜스를 다시 등록하고, 알림을 처리할 매니저를 구성한다.
    final manager = GeofenceManager(
      repository: scheduleRepository,
      notificationService: notificationService,
    )
      ..eventIdResolver = (schedule) {
        // ▼ 통근용 프리셋은 기존 출근 이벤트와 연결해 자동 실행을 이어 간다.
        switch (schedule.presetType) {
          case SchedulePresetType.commuteIn:
          case SchedulePresetType.commuteOut:
            return AppRepository.commuteEventId;
          case SchedulePresetType.move:
          case SchedulePresetType.workout:
            // ▼ 아직 연결할 기본 이벤트가 없으면 null을 반환해 자동 실행을 생략한다.
            return null;
        }
      };

    await manager.init();
    await manager.syncSchedules(scheduleRepository.currentSchedules);

    // ▼ 로컬 변수가 가비지 컬렉션으로 정리되지 않도록 싱글턴에 보관해 둔다.
    GeofenceBackgroundRuntime.instance.attach(manager);
  } catch (error, stackTrace) {
    // ▼ 초기화 중 문제가 생기더라도 앱이 즉시 종료되지 않도록 로그만 남긴다.
    debugPrint('지오펜스 백그라운드 초기화 실패: $error\n$stackTrace');
  }

  // ▼ iOS가 별도 종료 신호를 보내기 전까지 엔진을 유지해 이벤트를 수신한다.
  await GeofenceBackgroundRuntime.instance.waitUntilTerminate();
}

/// 헤드리스 엔진이 살아 있는 동안 필수 객체를 붙잡아 두기 위한 헬퍼 싱글턴
class GeofenceBackgroundRuntime {
  GeofenceBackgroundRuntime._();

  static final GeofenceBackgroundRuntime instance =
      GeofenceBackgroundRuntime._();

  GeofenceManager? manager;
  final Completer<void> _terminateCompleter = Completer<void>();

  /// 백그라운드 엔진에서 생성한 매니저를 저장해 참조가 끊어지지 않도록 한다.
  void attach(GeofenceManager manager) {
    // ▼ 초보자도 이해할 수 있도록: 이후에 필요할 수도 있으니 필드에 담아 둔다.
    this.manager = manager;
  }

  /// 아직 종료 요청이 없으므로 Future를 완료하지 않고 대기 상태로 유지한다.
  Future<void> waitUntilTerminate() => _terminateCompleter.future;
}
