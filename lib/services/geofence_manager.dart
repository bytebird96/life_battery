import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geofence_service/geofence_service.dart';

import '../data/schedule_models.dart';
import '../data/schedule_repository.dart';
import 'notifications.dart';

/// 지오펜스 등록/해제/이벤트 처리를 담당하는 매니저
class GeofenceManager {
  GeofenceManager({
    required ScheduleRepository repository,
    required NotificationService notificationService,
  })  : _repository = repository,
        _notificationService = notificationService {
    // geofence_service 패키지에서 제공하는 서비스 인스턴스를 설정한다.
    _service = GeofenceService.instance.setup(
      // interval: 5000,
      // accuracy: 100,
      // loiteringDelayMs: 60000,
      // statusChangeSettings: const GeofenceStatusChangeSettings(
      //   interval: 5000,
      //   accuracy: 100,
      // ),
      // useActivityRecognition: false,
      // allowMockLocations: false,
      // printDevLog: false,
      // geofenceRadius: [
      //   GeofenceRadius(id: 'radius_default', length: 150),
      // ],
        interval: 5000,
        accuracy: 100,
        loiteringDelayMs: 60000,
        statusChangeDelayMs: 5000, // 경계 근처 튐 방지용 지연
        useActivityRecognition: false,
        allowMockLocations: false,
        printDevLog: false,
        //geofenceRadiusSortType: GeofenceRadiusSortType.descending,
      geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
    );

    // _service.addGeofenceStatusChangeListener(_onStatusChanged);
    // _service.addGeofenceStatusChangeErrorListener(_onStatusError);
    _service.addGeofenceStatusChangeListener(_onStatusChanged);
    // _service.addLocationServicesStatusChangeListener(_onLocationServiceStatus);
    _service.addLocationServicesStatusChangeListener(_onLocationServiceStatus);
    // _service.addStreamErrorListener(_onStreamError);
    _service.addStreamErrorListener(_onStreamError);
  }

  late final GeofenceService _service;
  final ScheduleRepository _repository;
  final NotificationService _notificationService;
  final Set<String> _registeredIds = <String>{};
  bool _running = false;

  Future<void> init() async {
    try {
      // 위치 권한이 허용된 경우에만 start()가 성공한다.
      await _service.start();
      _running = true;
    } catch (e) {
      debugPrint('지오펜스 시작 실패: $e');
    }
  }

  Future<void> ensureRunning() async {
    if (_running) {
      return;
    }
    await init();
  }

  Future<void> applySchedule(Schedule schedule) async {
    if (!schedule.useLocation || schedule.lat == null || schedule.lng == null) {
      // 위치를 사용하지 않는 일정은 등록되어 있다면 제거한다.
      await removeSchedule(schedule.id);
      return;
    }
    await ensureRunning();
    final radius = (schedule.radiusMeters ?? 150).clamp(50, 300).toDouble();
    final geofence = Geofence(
      id: schedule.id,
      latitude: schedule.lat!,
      longitude: schedule.lng!,
      radius: [GeofenceRadius(id: 'radius_${schedule.id}', length: radius)],
      data: {
        'title': schedule.title,
        'trigger': schedule.triggerType.name,
      },
    );
    try {
      if (_registeredIds.contains(schedule.id)) {
         _service.removeGeofenceById(schedule.id);
      }
      // final added = await _service.addGeofence(geofence);
      // if (added) {
      //   _registeredIds.add(schedule.id);
      // }
       _service.addGeofence(geofence);
       _registeredIds.add(schedule.id);
    } catch (e) {
      debugPrint('지오펜스 등록 실패: $e');
    }
  }

  Future<void> removeSchedule(String id) async {
    try {
      // 등록된 지오펜스가 없어도 remove 호출은 안전하다.
       _service.removeGeofenceById(id);
    } catch (e) {
      debugPrint('지오펜스 제거 실패: $e');
    }
    _registeredIds.remove(id);
  }

  Future<void> syncSchedules(List<Schedule> schedules) async {
    await ensureRunning();
    // 위치를 사용하는 일정만 실제 지오펜스로 등록한다.
    final active = schedules
        .where((s) => s.useLocation && s.lat != null && s.lng != null)
        .toList();
    final targetIds = active.map((e) => e.id).toSet();
    // DB에는 없지만 기기에 남아있는 지오펜스를 정리한다.
    for (final id in _registeredIds.difference(targetIds).toList()) {
      await removeSchedule(id);
    }
    // 최신 정보로 모두 다시 등록
    for (final schedule in active) {
      await applySchedule(schedule);
    }
  }

  Future<void> dispose() async {
    await _service.stop();
    _registeredIds.clear();
    _running = false;
  }

  // void _onStatusChanged(
  //     Geofence geofence, GeofenceStatus status, Location location) {
  //   final message = '상태 변경(${geofence.id}): ${status.name}';
  //   _repository.addLog(message, scheduleId: geofence.id);
  // }
   Future<void> _onStatusChanged(
     Geofence geofence,
     GeofenceRadius radius,
     GeofenceStatus status,
     Location location,
   ) async {
     final message = '상태 변경(${geofence.id}): ${status.name}/${radius.length}m';
     await _repository.addLog(message, scheduleId: geofence.id);
     // 여기서 바로 트리거 처리(아래 D 반영)
     await _handleStatusAsEvent(geofence, status, location);
   }
  // void _onStatusError(dynamic error) {
  //   debugPrint('지오펜스 상태 오류: $error');
  // }

  void _onLocationServiceStatus(bool enabled) {
    if (!enabled) {
      _repository.addLog('위치 서비스가 비활성화되었습니다. 지오펜스 동작 불가.');
    }
  }

  //void _onStreamError(Object error) {
  void _onStreamError(dynamic error) {
    debugPrint('지오펜스 스트림 오류: $error');
  }

  // Future<void> _onGeofenceEvent(
  //     Geofence geofence, GeofenceEvent event, Location location) async {
  //   final schedule = await _repository.findById(geofence.id);
  //   if (schedule == null) {
  //     return;
  //   }
  //   // 사용자가 지정한 트리거 유형이 아니라면 알림을 보내지 않는다.
  //   if (!_shouldTrigger(schedule, event)) {
  //     await _repository.addLog('조건 불일치로 알림 미발송: ${schedule.title}',
  //         scheduleId: schedule.id);
  //     return;
  //   }
  //   if (schedule.executed) {
  //     await _repository.addLog('이미 실행 완료 처리된 일정: ${schedule.title}',
  //         scheduleId: schedule.id);
  //     return;
  //   }
  //   if (!schedule.remindIfNotExecuted) {
  //     await _repository.addLog('미실행 리마인더 끔: ${schedule.title}',
  //         scheduleId: schedule.id);
  //     return;
  //   }
  //   final now = DateTime.now();
  //   if (now.isBefore(schedule.startAt) || now.isAfter(schedule.endAt)) {
  //     await _repository.addLog('시간 범위 외로 알림 생략: ${schedule.title}',
  //         scheduleId: schedule.id);
  //     return;
  //   }
  //   // 요일/공휴일 조건을 검사하여 허용된 날에만 알림 발송
  //   final allow = await _checkDayCondition(schedule, now);
  //   if (!allow) {
  //     await _repository.addLog('요일/공휴일 조건 미충족: ${schedule.title}',
  //         scheduleId: schedule.id);
  //     return;
  //   }
  //   // 모든 조건이 충족되면 사용자에게 알림을 보낸다.
  //   await _notificationService.showScheduleReminder(
  //     scheduleId: schedule.id,
  //     title: schedule.title,
  //     body: schedule.presetMessage,
  //   );
  //   await _repository.addLog('알림 발송: ${schedule.title}',
  //       scheduleId: schedule.id);
  // }
   Future<void> _handleStatusAsEvent(
     Geofence geofence,
     GeofenceStatus status,
     Location location,
   ) async {
     final schedule = await _repository.findById(geofence.id);
     if (schedule == null) return;

     // ENTER/EXIT 매핑
     if (!_shouldTriggerByStatus(schedule, status)) {
       await _repository.addLog('조건 불일치로 알림 미발송: ${schedule.title}', scheduleId: schedule.id);
       return;
     }
     if (schedule.executed) {
       await _repository.addLog('이미 실행 완료 처리된 일정: ${schedule.title}', scheduleId: schedule.id);
       return;
     }
     if (!schedule.remindIfNotExecuted) {
       await _repository.addLog('미실행 리마인더 끔: ${schedule.title}', scheduleId: schedule.id);
       return;
     }
     final now = DateTime.now();
     if (now.isBefore(schedule.startAt) || now.isAfter(schedule.endAt)) {
       await _repository.addLog('시간 범위 외로 알림 생략: ${schedule.title}', scheduleId: schedule.id);
       return;
     }
     final allow = await _checkDayCondition(schedule, now);
     if (!allow) {
       await _repository.addLog('요일/공휴일 조건 미충족: ${schedule.title}', scheduleId: schedule.id);
       return;
     }
     await _notificationService.showScheduleReminder(
       scheduleId: schedule.id,
       title: schedule.title,
       body: schedule.presetMessage,
     );
     await _repository.addLog('알림 발송: ${schedule.title}', scheduleId: schedule.id);
   }

  // bool _shouldTrigger(Schedule schedule, GeofenceEvent event) {
  //   switch (schedule.triggerType) {
  //     case ScheduleTriggerType.arrive:
  //       return event == GeofenceEvent.enter;
  //     case ScheduleTriggerType.exit:
  //       return event == GeofenceEvent.exit;
  //   }
  // }
   bool _shouldTriggerByStatus(Schedule schedule, GeofenceStatus status) {
       switch (schedule.triggerType) {
         case ScheduleTriggerType.arrive:
           //return status == GeofenceStatus.enter;
           return status == GeofenceStatus.ENTER;
         case ScheduleTriggerType.exit:
           //return status == GeofenceStatus.exit;
           return status == GeofenceStatus.EXIT;
       }
     }

  Future<bool> _checkDayCondition(Schedule schedule, DateTime now) async {
    switch (schedule.dayCondition) {
      case ScheduleDayCondition.weekday:
        return now.weekday >= DateTime.monday &&
            now.weekday <= DateTime.friday;
      case ScheduleDayCondition.nonHoliday:
        final weekend =
            now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
        if (weekend) {
          return false;
        }
        final holiday = await _repository.isHoliday(now);
        return !holiday;
      case ScheduleDayCondition.always:
        return true;
    }
  }
}

/// 지오펜스 매니저 주입용 프로바이더
final geofenceManagerProvider =
    Provider<GeofenceManager>((ref) => throw UnimplementedError());
