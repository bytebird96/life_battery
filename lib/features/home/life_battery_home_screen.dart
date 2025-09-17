import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:energy_battery/features/home/widgets/life_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/scale.dart'; // 디자인 시안의 px 값을 기기 해상도에 맞게 변환하는 헬퍼
import '../../data/models.dart'; // 기존 시간표(Event) 모델
import '../../data/repositories.dart'; // 기존 이벤트/설정 저장소
import '../../data/schedule_repository.dart'; // 위치 기반 일정 레포지토리 프로바이더
import '../../services/geofence_manager.dart'; // 지오펜스 매니저 (동기화 담당)
import '../../services/notifications.dart'; // 로컬 알림 서비스
import 'battery_controller.dart'; // 배터리 퍼센트 관리 컨트롤러
import '../event/event_colors.dart'; // 일정 카드 색상
import '../event/event_icons.dart'; // 일정 카드 아이콘
import 'event_detail_screen.dart'; // 일정 상세 화면
import 'widgets/mag_safe_charging_ring.dart'; // 배터리 링 위젯

/// HTML/CSS 시안을 Flutter로 이식한 홈 화면
/// 여기에 위치 기반 일정(지오펜스) 관련 UI와 권한 요청 로직을 이식했다.
class LifeBatteryHomeScreen extends ConsumerStatefulWidget {
  const LifeBatteryHomeScreen({super.key});

  @override
  ConsumerState<LifeBatteryHomeScreen> createState() =>
      _LifeBatteryHomeScreenState();
}

class _LifeBatteryHomeScreenState extends ConsumerState<LifeBatteryHomeScreen> {
  // ======================== 기존 배터리/타이머 상태 ========================
  String? _runningId; // 현재 실행 중인 이벤트 ID
  Duration _remain = Duration.zero; // 실행 중 이벤트의 남은 시간
  double _runningRate = 0; // 실행 중 이벤트의 시간당 배터리 증감율
  final Map<String, Duration> _remainMap = {}; // 각 이벤트별 남은 시간 기록
  Timer? _countdown; // 1초마다 남은 시간을 갱신하는 타이머
  bool _loadingState = false; // SharedPreferences로부터 상태를 불러오는 중인지 여부

  // ======================== 신규: 권한/지오펜스 준비 상태 ========================
  bool _requesting = false; // 권한 요청이 중복 실행되는 것을 막기 위한 플래그

  /// 지오펜스 매니저가 전달하는 자동 실행 이벤트를 수신하기 위한 구독자
  ProviderSubscription<AsyncValue<GeofenceTriggeredEvent>>? _geofenceSub;

  // ------------------------------ 생명주기 ------------------------------
  @override
  void initState() {
    super.initState();

    // 1) 앱 시작 시 기존 이벤트 목록을 불러와 남은 시간을 초기화한다.
    final repo = ref.read(repositoryProvider);
    for (final e in repo.events) {
      _remainMap[e.id] = e.endAt.difference(e.startAt);
    }

    // 2) SharedPreferences에 저장된 진행 중인 작업 정보를 비동기로 불러온다.
    Future.microtask(_loadState);

    // 2-1) 지오펜스에서 자동 실행 요청이 들어오면 처리하도록 스트림을 구독한다.
    _geofenceSub = ref.listenManual<AsyncValue<GeofenceTriggeredEvent>>(
      geofenceTriggerStreamProvider,
      (prev, next) {
        next.whenData((payload) {
          if (!mounted) return;
          // 비동기 처리를 기다릴 필요가 없으므로 unawaited 사용
          unawaited(_handleAutoStartFromGeofence(payload));
        });
      },
    );
    // 이미 대기 중인 값이 있다면 즉시 처리하여 놓치지 않도록 한다.
    ref.read(geofenceTriggerStreamProvider).whenData((payload) {
      if (!mounted) return;
      unawaited(_handleAutoStartFromGeofence(payload));
    });

    // 3) 첫 프레임이 그려진 직후 위치 권한을 요청하고 지오펜스를 동기화한다.
    //    (빌드 전에 실행하면 로딩이 길어져 UI가 멈춘 것처럼 느껴질 수 있다.)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepareLocationSchedules();
    });
  }

  @override
  void dispose() {
    // 화면이 사라질 때 타이머를 반드시 정리하여 메모리 누수를 막는다.
    _countdown?.cancel();
    _geofenceSub?.close();
    super.dispose();
  }

  // ------------------ 신규: 위치 권한 요청 + 지오펜스 동기화 ------------------
  Future<void> _prepareLocationSchedules() async {
    if (!mounted) return; // 위젯이 이미 dispose 되었다면 아무것도 하지 않는다.

    await _requestPermissions(); // 위치 관련 권한을 먼저 요청
    if (!mounted) return;

    // 위치 기반 일정 동기화: 일정 목록과 지오펜스 매니저를 가져온다.
    final scheduleRepo = ref.read(scheduleRepositoryProvider);
    final geo = ref.read(geofenceManagerProvider);
    try {
      await geo.init(); // 이미 초기화되어 있다면 내부에서 무시하도록 구현되어 있다고 가정
      await geo.syncSchedules(scheduleRepo.currentSchedules);
    } catch (e) {
      // 지오펜스 준비는 필수는 아니므로, 실패하더라도 앱이 죽지 않도록 로그만 남긴다.
      debugPrint('지오펜스 준비 실패: $e');
    }
  }

  /// 상단 우측에 배치할 동그란 버튼을 재사용 가능한 형태로 생성한다.
  Widget _headerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: s(context, 16)),
      label: Text(
        label,
        style: TextStyle(
          fontSize: s(context, 12),
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: s(context, 12),
          vertical: s(context, 6),
        ),
        backgroundColor: Colors.white.withOpacity(0.9),
        foregroundColor: const Color(0xFF111118),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(s(context, 18)),
        ),
      ),
    );
  }

  /// 위치/알림 관련 권한을 순차적으로 요청한다.
  /// 초보자도 이해할 수 있도록 어떤 플랫폼에서 어떤 권한을 요구하는지 주석을 덧붙였다.
  Future<void> _requestPermissions() async {
    if (_requesting) return; // 이미 요청 중이라면 중복 호출 방지
    _requesting = true;
    try {
      // iOS/Android 공통: 기본 위치 권한(앱 사용 중)을 먼저 요청한다.
      await Permission.location.request();

      if (Platform.isAndroid) {
        // Android: 항상 허용 권한, 알림 권한, 배터리 최적화 무시 권한까지 요청
        await Permission.locationAlways.request();
        await Permission.notification.request();
        await Permission.ignoreBatteryOptimizations.request();
      } else {
        // iOS: 항상 허용 권한만 추가로 요청하면 된다.
        await Permission.locationAlways.request();
      }
    } finally {
      _requesting = false;
    }
  }

  // ------------------------------ 상태 복원/저장 ------------------------------
  Future<void> _saveRemainMap() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _remainMap.map((k, v) => MapEntry(k, v.inSeconds));
    await prefs.setString('remainMap', jsonEncode(map));
  }

  Future<void> _saveRunningTask({
    required String id,
    required double rate,
    required Duration duration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final battery = ref.read(batteryControllerProvider);
    await prefs.setDouble('battery', battery);
    await prefs.setString('taskId', id);
    await prefs.setDouble('ratePerHour', rate);
    await prefs.setInt('duration', duration.inSeconds);
    await prefs.setInt('startTime', DateTime.now().millisecondsSinceEpoch);
    await _saveRemainMap();
  }

  Future<void> _clearRunningTask() async {
    final prefs = await SharedPreferences.getInstance();
    final battery = ref.read(batteryControllerProvider);
    await prefs.setDouble('battery', battery);
    await prefs.remove('taskId');
    await prefs.remove('ratePerHour');
    await prefs.remove('duration');
    await prefs.remove('startTime');
  }

  Future<void> _loadState() async {
    // 동시에 여러 번 불러와 상태가 꼬이지 않도록 가드 처리
    if (_loadingState) return;
    _loadingState = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // -------------------- 남은 시간 맵 복원 --------------------
      final remainStr = prefs.getString('remainMap');
      if (remainStr != null) {
        final decoded = Map<String, dynamic>.from(jsonDecode(remainStr));
        decoded.forEach((key, value) {
          // SharedPreferences에는 초 단위의 정수가 저장되어 있으므로
          // Duration으로 다시 감싸 홈 화면에서 즉시 사용할 수 있게 만든다.
          _remainMap[key] = Duration(seconds: value as int);
        });
      }

      // -------------------- 배터리 퍼센트 복원 --------------------
      final savedBattery = prefs.getDouble('battery');
      if (savedBattery != null) {
        // Task 화면에서 작업을 시작/중지했다면 배터리 값이 저장되어 있으므로
        // 홈에서도 동일한 값으로 맞춰 사용자에게 일관된 숫자를 보여준다.
        ref.read(batteryControllerProvider.notifier).state = savedBattery;
      }

      // -------------------- 실행 중 작업 복원 --------------------
      final runningId = prefs.getString('taskId');
      if (runningId == null) {
        // 저장된 실행 중 작업이 없다면 홈 화면에서도 즉시 상태를 초기화한다.
        _countdown?.cancel();
        if (mounted) {
          setState(() {
            _runningId = null;
            _runningRate = 0;
            _remain = Duration.zero;
          });
        }
        await _saveRemainMap();
        return;
      }

      final rate = prefs.getDouble('ratePerHour') ?? 0;
      final durationSec = prefs.getInt('duration') ?? 0;
      final startMillis = prefs.getInt('startTime') ?? 0;

      // Task 화면에서 작업을 시작한 시각과 현재 시각의 차이를 계산해
      // 홈 화면에 돌아왔을 때 이어서 진행할 수 있도록 남은 시간을 구한다.
      final elapsed = DateTime.now().millisecondsSinceEpoch ~/ 1000 -
          startMillis ~/ 1000;
      final usedSec = elapsed > durationSec ? durationSec : elapsed;

      // elapsed 동안 배터리가 얼마나 변했는지 다시 계산한 뒤 저장한다.
      final perSecond = rate / 3600;
      var battery = ref.read(batteryControllerProvider);
      battery += perSecond * usedSec;
      battery = battery.clamp(0, 100);
      ref.read(batteryControllerProvider.notifier).state = battery;
      ref.read(batteryControllerProvider.notifier).stop();

      final remainSec = durationSec - usedSec;
      if (remainSec > 0) {
        _remainMap[runningId] = Duration(seconds: remainSec);
        await _clearRunningTask();
        final repo = ref.read(repositoryProvider);
        try {
          final e = repo.events.firstWhere((ev) => ev.id == runningId);
          await _startEvent(e); // 홈 화면이 주도권을 가져와 계속 진행한다.
        } catch (_) {
          _remainMap.remove(runningId);
          await _saveRemainMap();
        }
      } else {
        // 남은 시간이 모두 소진된 상태라면 UI만 초기화하고 정보는 제거한다.
        _remainMap[runningId] = Duration.zero;
        await _clearRunningTask();
        await _saveRemainMap();
        if (mounted) {
          setState(() {
            _runningId = null;
            _runningRate = 0;
            _remain = Duration.zero;
          });
        }
      }

      if (!mounted) return;
      setState(() {});
    } finally {
      _loadingState = false;
    }
  }

  // ------------------------------ 일정 제어 ------------------------------
  Future<void> _startEvent(Event e) async {
    var duration = _remainMap[e.id] ?? e.endAt.difference(e.startAt);
    if (duration == Duration.zero) {
      duration = e.endAt.difference(e.startAt);
    }
    if (duration <= Duration.zero) {
      _remainMap[e.id] = Duration.zero;
      await _saveRemainMap();
      return;
    }

    ref.read(batteryControllerProvider.notifier).startTask(
      ratePerHour: e.ratePerHour ?? 0,
      duration: duration,
    );

    final notif = ref.read(notificationProvider);
    try {
      await notif.cancel(e.id.hashCode);
      await notif.scheduleComplete(
        id: e.id.hashCode,
        title: '일정 완료',
        body: '${e.title}이(가) 완료되었습니다',
        after: duration,
      );
    } catch (e) {
      debugPrint('알림 예약 실패: $e');
    }

    _remainMap[e.id] = duration;
    await _saveRunningTask(
        id: e.id, rate: e.ratePerHour ?? 0, duration: duration);

    _countdown?.cancel();
    setState(() {
      _runningId = e.id;
      _remain = duration;
      _runningRate = e.ratePerHour ?? 0;
    });
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remain.inSeconds <= 1) {
        _stopEvent(completed: true);
      } else {
        setState(() => _remain -= const Duration(seconds: 1));
      }
    });
  }

  Future<void> _stopEvent({bool completed = false}) async {
    ref.read(batteryControllerProvider.notifier).stop();
    _countdown?.cancel();

    if (!completed && _runningId != null) {
      try {
        await ref.read(notificationProvider).cancel(_runningId!.hashCode);
      } catch (e) {
        debugPrint('알림 취소 실패: $e');
      }
    }

    setState(() {
      if (_runningId != null) {
        _remainMap[_runningId!] =
            _remain.inSeconds <= 1 ? Duration.zero : _remain;
      }
      _runningId = null;
      _runningRate = 0;
    });

    await _saveRemainMap();
    await _clearRunningTask();
  }

  /// 지오펜스 매니저가 자동 실행을 요청했을 때 실제 이벤트를 시작하는 헬퍼
  Future<void> _handleAutoStartFromGeofence(
      GeofenceTriggeredEvent payload) async {
    if (!mounted) return; // 위젯이 이미 파괴되었다면 더 진행하지 않는다.

    final scheduleRepo = ref.read(scheduleRepositoryProvider);
    final repo = ref.read(repositoryProvider);

    // 전달받은 이벤트 ID와 일치하는 Event를 찾아온다.
    Event? target;
    try {
      target = repo.events.firstWhere((e) => e.id == payload.eventId);
    } catch (_) {
      target = null;
    }

    if (target == null) {
      // 이벤트가 삭제되었거나 매핑이 잘못된 경우 사용자 로그로 남긴다.
      await scheduleRepo.addLog(
        '자동 실행 대상 이벤트(${payload.eventId})를 찾지 못했습니다.',
        scheduleId: payload.schedule.id,
      );
      debugPrint('자동 실행할 이벤트 없음: ${payload.eventId}');
      return;
    }

    if (_runningId == target.id) {
      // 동일 이벤트가 이미 실행 중이면 중복 실행을 방지한다.
      await scheduleRepo.addLog(
        '이미 실행 중인 이벤트라 자동 실행을 건너뜁니다: ${target.title}',
        scheduleId: payload.schedule.id,
      );
      return;
    }

    if (_runningId != null && _runningId != target.id) {
      // 다른 이벤트가 진행 중이면 충돌을 피하기 위해 자동 실행을 취소한다.
      await scheduleRepo.addLog(
        '다른 이벤트($_runningId)가 진행 중이라 자동 실행을 생략했습니다.',
        scheduleId: payload.schedule.id,
      );
      debugPrint('자동 실행이 충돌로 인해 취소됨: 현재 $_runningId, 요청 ${target.id}');
      return;
    }

    final baseDuration = target.endAt.difference(target.startAt);
    final remain = _remainMap[target.id] ?? baseDuration;
    if (remain <= Duration.zero) {
      await scheduleRepo.addLog(
        '남은 시간이 없어 자동 실행을 건너뜁니다: ${target.title}',
        scheduleId: payload.schedule.id,
      );
      return;
    }

    await _startEvent(target);

    // 자동 실행이 성공했음을 로그로 남기고, 해당 위치 일정은 완료 상태로 표시한다.
    await scheduleRepo.setExecuted(payload.schedule.id, true);
    await scheduleRepo.addLog(
      '지오펜스 자동 실행 완료: ${payload.schedule.title} → ${target.title}',
      scheduleId: payload.schedule.id,
    );
    debugPrint(
        '지오펜스 자동 실행 성공: ${payload.schedule.id} → ${target.id} (${payload.status.name})');
  }

  /// 남은 시간을 모두 적용하여 즉시 일정을 완료하는 함수
  Future<void> _instantComplete(Event e) async {
    final repo = ref.read(repositoryProvider); // 일정 저장소 접근
    final base = e.endAt.difference(e.startAt); // 전체 일정 시간
    // 실행 중인 일정이면 현재 남은 시간을 사용, 아니면 저장된 남은 시간 사용
    final remain = _runningId == e.id ? _remain : (_remainMap[e.id] ?? base);

    // 진행 중이었다면 타이머를 중지하고 상태를 정리
    if (_runningId == e.id) {
      await _stopEvent(completed: true);
    }

    // 남은 시간만큼의 배터리 변화량 계산 및 적용
    final delta = _rateFor(e, repo) * remain.inSeconds / 3600;
    var battery = ref.read(batteryControllerProvider);
    battery += delta;
    battery = battery.clamp(0, 100); // 0~100 범위로 제한
    ref.read(batteryControllerProvider.notifier).state = battery;

    // 일정은 완료 상태로 표시
    _remainMap[e.id] = Duration.zero;
    try {
      await ref.read(notificationProvider).cancel(e.id.hashCode);
    } catch (_) {}
    await _saveRemainMap();
    await _clearRunningTask();
    setState(() {});
  }

  /// 일정을 중지하고 처음 상태(전체 시간)으로 되돌리는 함수
  Future<void> _resetEvent(Event e) async {
    final base = e.endAt.difference(e.startAt); // 초기 설정 시간
    if (_runningId == e.id) {
      // 실행 중이면 중지하고 배터리를 시작 당시 값으로 복구
      await _stopEvent();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble('battery');
      if (saved != null) {
        ref.read(batteryControllerProvider.notifier).state = saved;
      }
      await _clearRunningTask();
    }
    _remainMap[e.id] = base; // 남은 시간을 초기값으로 설정
    await _saveRemainMap();
    setState(() {});
  }

  /// 일정 타일을 눌렀을 때 상세 화면으로 이동하는 함수
  Future<void> _openDetail(Event e) async {
    final base = e.endAt.difference(e.startAt);
    final running = _runningId == e.id;
    final remain = running ? _remain : (_remainMap[e.id] ?? base);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          event: e,
          running: running,
          remain: remain,
          onInstantComplete: () => _instantComplete(e),
          onReset: () => _resetEvent(e),
        ),
      ),
    );
  }

  double _rateFor(Event e, AppRepository repo) {
    if (e.ratePerHour != null) return e.ratePerHour!;
    switch (e.type) {
      case EventType.work:
        return -repo.settings.defaultDrainRate;
      case EventType.rest:
        return repo.settings.defaultRestRate;
      case EventType.sleep:
        return repo.settings.sleepChargeRate;
      case EventType.neutral:
        return 0;
    }
  }

  // ------------------------------ 빌드 ------------------------------
  @override
  Widget build(BuildContext context) {
    final percent = ref.watch(batteryControllerProvider) / 100;
    final repo = ref.watch(repositoryProvider);

    for (final e in repo.events) {
      _remainMap.putIfAbsent(e.id, () => e.endAt.difference(e.startAt));
    }

    // ====== 시안 비율(가로 기준) ======
    final w = MediaQuery.of(context).size.width;

    // 링: 화면 폭의 46%, 두께: 링의 8.5%, 폰트: 링의 18%
    final ringSize = w * 0.46;
    final ringThick = ringSize * 0.085;
    final labelFont = ringSize * 0.18;

    // 제목 폰트: 폭의 ~7.4%
    final titleFs = w * 0.074;

    // 하단 탭바 스케일 및 위치 계산
    final tabH = s(context, 85);
    final tabScale = 0.99;

    // 주요 레이아웃 위치/여백 계산
    final titleTop = s(context, 35);
    final ringTop = s(context, 96);
    final sectionTop = ringTop + ringSize + s(context, 0);
    final pageSide = s(context, 20);
    final listBottom = tabH + s(context, 8);
    final actionTop = s(context, 20); // 상단 버튼과 제목 사이 여백 계산

    // 리스트 카드 스케일
    final iconBg = w * 0.12;
    final iconSize = iconBg * 0.46;
    final cardPadding = w * 0.035;
    final titleInCard = w * 0.038;
    final chipFs = w * 0.028;
    final timeFs = w * 0.03;
    final cardRadius = w * 0.047;
    final cardGap = w * 0.025;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        clipBehavior: Clip.none, // 배터리 링의 광채가 잘리면 안 되므로 none 유지
        children: [
          // ------------------ 상단 설정 버튼 ------------------
          Positioned(
            top: actionTop,
            right: pageSide,
            child: SafeArea(
              bottom: false, // 하단 여백은 필요 없으므로 false
              child: _headerActionButton(
                // 가이드 버튼을 제거하고 설정 버튼만 노출하여 상단 액션을 간결하게 유지한다.
                icon: Icons.settings,
                label: '설정',
                onTap: () => context.push('/settings'),
              ),
            ),
          ),

          // ------------------ 제목 ------------------
          Positioned(
            top: titleTop,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Life Battery',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111118),
                  fontSize: titleFs,
                  height: 2.5,
                ),
              ),
            ),
          ),

          // ------------------ 배터리 링 (MagSafe 스타일) ------------------
          Positioned(
            top: ringTop,
            left: 0,
            right: 0,
            child: Center(
              child: MagSafeChargingRing(
                percent: percent,
                charging: _runningRate > 0, // 충전 중일 때만 오라 출력
                size: ringSize,
                thickness: ringThick,
                labelFont: labelFont,
              ),
            ),
          ),

          // ------------------ 리스트 섹션 ------------------
          Positioned(
            top: sectionTop,
            left: pageSide,
            right: pageSide,
            bottom: listBottom,
            child: ListView(
              // 위치 기반 일정 리스트를 제거했더라도 스크롤이 갑자기 멈추지 않도록
              // 항상 스크롤 가능한 물리 엔진(AlwaysScrollableScrollPhysics)을 유지한다.
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _todaySectionHeader(w),
                SizedBox(height: s(context, 8)),
                _todayList(
                  repo,
                  iconBg,
                  iconSize,
                  cardPadding,
                  titleInCard,
                  chipFs,
                  timeFs,
                  cardRadius,
                  cardGap,
                ),
                SizedBox(height: s(context, 16)),
                // 위치 기반 일정 카드 대신 배치할 수 있는 여백을 따로 확보한다.
                // 지금은 단순한 공간이지만, 추후 다른 정보를 채우고 싶다면
                // 아래 SizedBox 부분에 새 위젯을 추가하면 된다.
                SizedBox(height: s(context, 24)),
              ],
            ),
          ),

          // ------------------ 하단 탭바 ------------------
          Positioned(
            left: s(context, 50),
            right: s(context, 50),
            bottom: s(context, 1),
            child: SizedBox(
              height: tabH,
              child: Transform.scale(
                scale: tabScale,
                alignment: Alignment.bottomCenter,
                child: LifeTabBar(
                  onAdd: () async {
                    // 홈에서 리스트는 숨겼지만, + 버튼으로는 여전히 위치 기반 일정 생성 화면에 접근한다.
                    // 위치 기반 자동 실행 기능은 유지해야 하므로 진입 경로를 없애지 않는다.
                    context.push('/schedule/new');
                  },
                  onClock: () async {
                    // 작업/기록 화면 등 기존 네비게이션은 유지하면서도
                    // Navigator 대신 GoRouter의 context.push를 사용해
                    // '/tasks' 라우트를 부른다. (뒤로가기도 동일하게 동작)
                    await context.push('/tasks');
                    if (!mounted) return;
                    // Task 화면에서 작업을 시작/중지했을 수 있으므로
                    // 다시 홈으로 돌아오면 SharedPreferences에 저장된 정보를
                    // 재확인해 "실행 중" 배지가 올바르게 표시되도록 한다.
                    await _loadState();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Today 섹션 헤더 ----------
  Widget _todaySectionHeader(double w) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today',
          style: TextStyle(
            fontSize: w * 0.032, // 디자인 비율에 맞춘 폰트 크기
            color: const Color(0xFFB0B2C0),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: s(context, 8)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '일정',
              style: TextStyle(
                fontSize: w * 0.048,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111118),
              ),
            ),
            GestureDetector(
              onTap: () =>
                  context.push('/events'), // GoRouter 경로로 전체 일정 화면 이동
              child: Text(
                'See All',
                style: TextStyle(
                  fontSize: w * 0.037,
                  color: const Color(0xFF9FA2B2),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- Today 일정 카드 리스트 ----------
  Widget _todayList(
    AppRepository repo,
    double iconBg,
    double iconSize,
    double cardPadding,
    double titleInCard,
    double chipFs,
    double timeFs,
    double cardRadius,
    double cardGap,
  ) {
    return ListView.separated(
      shrinkWrap: true, // 부모 ListView 안에서도 스크롤이 겹치지 않도록 처리
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: repo.events.length > 4 ? 4 : repo.events.length,
      itemBuilder: (context, index) {
        final e = repo.events[index];
        final running = _runningId == e.id;
        final base = e.endAt.difference(e.startAt);
        final remain = running ? _remain : _remainMap[e.id] ?? base;
        final rate = _rateFor(e, repo);
        final isProtected = repo.isProtectedEvent(e.id);

        return Dismissible(
          key: ValueKey(e.id),
          direction:
              isProtected ? DismissDirection.none : DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            if (isProtected) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('기본 일정은 삭제할 수 없습니다.')),
              );
              return false;
            }
            return true;
          },
          onDismissed: (_) async {
            if (isProtected) return;
            if (running) await _stopEvent();
            try {
              await ref.read(notificationProvider).cancel(e.id.hashCode);
            } catch (_) {}
            await ref.read(repositoryProvider).deleteEvent(e.id);
            setState(() {
              _remainMap.remove(e.id);
            });
            await _saveRemainMap();
          },
          child: _EventTile.scaled(
            event: e,
            running: running,
            remain: remain,
            rate: rate,
            onPressed: () async {
              if (running) {
                await _stopEvent();
              } else {
                await _startEvent(e);
              }
            },
            onTap: () => _openDetail(e),
            iconBg: iconBg,
            iconSize: iconSize,
            cardPadding: cardPadding,
            titleFs: titleInCard,
            chipFs: chipFs,
            timeFs: timeFs,
            cardRadius: cardRadius,
            cardGap: cardGap,
          ),
        );
      },
      separatorBuilder: (_, __) => SizedBox(height: s(context, 8)),
    );
  }

}

// ===================== 일정 카드 =====================
class _EventTile extends StatelessWidget {
  final Event event;
  final bool running;
  final Duration remain;
  final double rate;
  final VoidCallback onPressed;
  final VoidCallback? onTap; // 타일 전체 탭 동작

  final double iconBg;
  final double iconSize;
  final double cardPadding;
  final double titleFs;
  final double chipFs;
  final double timeFs;
  final double cardRadius;
  final double cardGap;

  const _EventTile.scaled({
    required this.event,
    required this.running,
    required this.remain,
    required this.rate,
    required this.onPressed,
    this.onTap,
    required this.iconBg,
    required this.iconSize,
    required this.cardPadding,
    required this.titleFs,
    required this.chipFs,
    required this.timeFs,
    required this.cardRadius,
    required this.cardGap,
  });

  @override
  Widget build(BuildContext context) {
    final typeTag =
        event.type.name[0].toUpperCase() + event.type.name.substring(1);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7FA),
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        child: Row(
          children: [
            Container(
              width: iconBg,
              height: iconBg,
              decoration: BoxDecoration(
                color: colorFromName(event.colorName), // 사용자가 고른 색상을 배경으로 표시
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                iconDataFromName(event.iconName),
                color: Colors.white,
                size: iconSize,
              ),
            ),
            SizedBox(width: cardGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111118),
                            fontSize: titleFs,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatDuration(remain),
                            style: TextStyle(
                                color: const Color(0xFF717489), fontSize: timeFs),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${_batteryDelta(rate, remain)})',
                            style: TextStyle(
                                color: const Color(0xFF717489),
                                fontSize: timeFs - 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: s(context, 6)),
                  Row(
                    children: [
                      _TagChip(
                        text: typeTag,
                        color: const Color(0xFFFFE8EC),
                        textColor: const Color(0xFFF35D6A),
                        fontSize: chipFs,
                        hp: s(context, 8),
                        vp: s(context, 4),
                        radius: s(context, 8),
                      ),
                      SizedBox(width: s(context, 6)),
                      if (event.content != null && event.content!.isNotEmpty)
                        _TagChip(
                          text: event.content!,
                          color: const Color(0xFFF5F0FF),
                          textColor: const Color(0xFF9B51E0),
                          fontSize: chipFs,
                          hp: s(context, 8),
                          vp: s(context, 4),
                          radius: s(context, 8),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: cardGap),
            IconButton(
              iconSize: s(context, 24),
              icon: Icon(running ? Icons.stop : Icons.play_arrow),
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _batteryDelta(double rate, Duration remain) {
    final change = rate * remain.inSeconds / 3600;
    final sign = change > 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)}%';
  }
}

// ===================== 태그 칩 =====================
class _TagChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final double fontSize;
  final double hp;
  final double vp;
  final double radius;

  const _TagChip({
    required this.text,
    required this.color,
    required this.textColor,
    required this.fontSize,
    required this.hp,
    required this.vp,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hp, vertical: vp),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
