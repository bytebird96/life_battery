import 'dart:async';
import 'dart:convert';

import 'package:energy_battery/features/home/widgets/life_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'battery_controller.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../services/notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ▼▼▼ 중요: MagSafe 스타일 배터리 링 위젯 경로(너 프로젝트에 맞춰 수정) ▼▼▼
import 'widgets/mag_safe_charging_ring.dart';
import 'event_detail_screen.dart';

import '../../core/scale.dart'; // s(context, px) 헬퍼

/// HTML/CSS 시안을 Flutter로 이식한 홈 화면
class LifeBatteryHomeScreen extends ConsumerStatefulWidget {
  const LifeBatteryHomeScreen({super.key});

  @override
  ConsumerState<LifeBatteryHomeScreen> createState() =>
      _LifeBatteryHomeScreenState();
}

class _LifeBatteryHomeScreenState
    extends ConsumerState<LifeBatteryHomeScreen> {
  String? _runningId;
  Duration _remain = Duration.zero;
  double _runningRate = 0;
  final Map<String, Duration> _remainMap = {};
  Timer? _countdown;

  // ------------------------------ 상태 복원/저장 ------------------------------
  @override
  void initState() {
    super.initState();
    final repo = ref.read(repositoryProvider);
    for (final e in repo.events) {
      _remainMap[e.id] = e.endAt.difference(e.startAt);
    }
    Future.microtask(_loadState);
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

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
    final prefs = await SharedPreferences.getInstance();

    final remainStr = prefs.getString('remainMap');
    if (remainStr != null) {
      final decoded = Map<String, dynamic>.from(jsonDecode(remainStr));
      decoded.forEach((key, value) {
        _remainMap[key] = Duration(seconds: value as int);
      });
    }

    final savedBattery = prefs.getDouble('battery');
    if (savedBattery != null) {
      ref.read(batteryControllerProvider.notifier).state = savedBattery;
    }

    final runningId = prefs.getString('taskId');
    if (runningId != null) {
      final rate = prefs.getDouble('ratePerHour') ?? 0;
      final durationSec = prefs.getInt('duration') ?? 0;
      final startMillis = prefs.getInt('startTime') ?? 0;

      final elapsed = DateTime.now().millisecondsSinceEpoch ~/ 1000 -
          startMillis ~/ 1000;
      final usedSec = elapsed > durationSec ? durationSec : elapsed;

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
          await _startEvent(e);
        } catch (_) {
          _remainMap.remove(runningId);
          await _saveRemainMap();
        }
      } else {
        _remainMap[runningId] = Duration.zero;
        await _clearRunningTask();
        await _saveRemainMap();
      }
    } else {
      await _saveRemainMap();
    }

    if (!mounted) return;
    setState(() {});
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

    // ★ 하단 탭바의 실제 표시 높이(작게)
    final tabH = s(context, 85);                       // ★ 축소된 탭바 높이
    final tabScale = 0.99;                             // ★ 보이는 크기 살짝 축소

    // 여백 (s(context, px)는 375 기준 px → 실제 스케일)
    final titleTop = s(context, 35);
    final ringTop = s(context, 96);
    final sectionTop = ringTop + ringSize + s(context, 0);
    final pageSide = s(context, 20);

    // ★ 리스트 영역을 키우기 위해 bottom 여백을 탭바 높이만큼만 두기
    final listBottom = tabH + s(context, 8);           // ★ 112 → 훨씬 작게

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
      body: Builder(
        builder: (context) {
          return Stack(
            clipBehavior: Clip.none, // 오라가 바깥으로 퍼지므로 자르면 안 됨
            children: [
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
                bottom: listBottom,                    // ★ 리스트 공간 확대
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today',
                      style: TextStyle(
                        fontSize: w * 0.032, // 14
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
                            fontSize: w * 0.048, // 기존 22 → 약 20
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111118),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/events'),
                          child: Text(
                            'See All',
                            style: TextStyle(
                              fontSize: w * 0.037, // 14
                              color: const Color(0xFF9FA2B2),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: s(context, 8)),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: repo.events.length > 4 ? 4 : repo.events.length,
                        itemBuilder: (context, index) {
                          final e = repo.events[index];
                          final running = _runningId == e.id;
                          final base = e.endAt.difference(e.startAt);
                          final remain = running ? _remain : _remainMap[e.id] ?? base;
                          final rate = _rateFor(e, repo);

                          return Dismissible(
                            key: ValueKey(e.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) async {
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
                      ),
                    ),
                  ],
                ),
              ),

              // ------------------ 하단 탭바 (작게 & 더 아래로) ------------------
              Positioned(
                left: s(context, 50),                  // ★ 좌우 간격 축소
                right: s(context, 50),
                bottom: s(context, 1),                 // ★ 거의 바닥에 붙임
                child: SizedBox(
                  height: tabH,                        // ★ 표시 높이 제한
                  child: Transform.scale(
                    scale: tabScale,                   // ★ 전체 스케일 다운
                    alignment: Alignment.bottomCenter,
                    // 하단 탭바: + 버튼과 시계 아이콘에 기능을 연결한다.
                    child: LifeTabBar(
                      onAdd: () async {
                        await Navigator.pushNamed(context, '/event');
                        if (mounted) setState(() {});
                      },
                      onClock: () async {
                        // 왼쪽 시계 아이콘을 누르면 작업 화면으로 이동
                        await Navigator.pushNamed(context, '/tasks');
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
            decoration: const BoxDecoration(
              color: Color(0xFF9B51E0),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.computer, color: Colors.white, size: iconSize),
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
          )
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