import 'dart:async'; // Timer 사용
import 'dart:convert'; // JSON 변환

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'battery_controller.dart';
import '../../data/models.dart'; // Event 모델 사용
import '../../data/repositories.dart'; // 일정 저장소
import '../../services/notifications.dart'; // 알림 서비스
import 'package:shared_preferences/shared_preferences.dart'; // 로컬 저장소
import 'widgets/life_tab_bar.dart'; // 하단 탭바 위젯
import 'widgets/charging_ring.dart'; // 새로 만든 충전 링 위젯
import '../../core/scale.dart'; // 화면 스케일 헬퍼

/// HTML/CSS로 전달된 템플릿을 Flutter로 옮긴 홈 화면
class LifeBatteryHomeScreen extends ConsumerStatefulWidget {
  const LifeBatteryHomeScreen({super.key});
  @override
  ConsumerState<LifeBatteryHomeScreen> createState() => _LifeBatteryHomeScreenState();
}

class _LifeBatteryHomeScreenState extends ConsumerState<LifeBatteryHomeScreen> {
  String? _runningId;
  Duration _remain = Duration.zero;
  double _runningRate = 0;
  final Map<String, Duration> _remainMap = {};
  Timer? _countdown;

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

  Future<void> _saveRunningTask({required String id, required double rate, required Duration duration}) async {
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

      final elapsed = DateTime.now().millisecondsSinceEpoch ~/ 1000 - startMillis ~/ 1000;
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
    await _saveRunningTask(id: e.id, rate: e.ratePerHour ?? 0, duration: duration);

    _countdown?.cancel();
    setState(() {
      _runningId = e.id;
      _remain = duration;
      _runningRate = e.ratePerHour ?? 0;
    });
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remain.inSeconds <= 1) {
        _stopEvent(completed: true);
      } else {
        setState(() {
          _remain -= const Duration(seconds: 1);
        });
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
        _remainMap[_runningId!] = _remain.inSeconds <= 1 ? Duration.zero : _remain;
      }
      _runningId = null;
      _runningRate = 0;
    });

    await _saveRemainMap();
    await _clearRunningTask();
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: Builder(
        builder: (context) {
          // 스케일 변수
          final titleTop = s(context, 56);
          final ringTop = s(context, 108);
          final ringSize = s(context, 220);
          final ringThick = s(context, 16);
          final percentFs = s(context, 36);
          final sectionTop = s(context, 320);
          final pageSide = s(context, 20);
          final listBottom = s(context, 100);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // 제목
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
                      fontSize: s(context, 28),
                      height: 1.1,
                    ),
                  ),
                ),
              ),

              // 배터리 링
              Positioned(
                top: ringTop,
                left: 0,
                right: 0,
                child: Center(
                  child: ChargingRing(
                    percent: percent,
                    charging: _runningRate > 0,
                    size: ringSize,
                    thickness: ringThick,
                    labelFont: percentFs,
                  ),
                ),
              ),

              // 리스트 섹션
              Positioned(
                top: sectionTop,
                left: pageSide,
                right: pageSide,
                bottom: listBottom,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today',
                      style: TextStyle(
                        fontSize: s(context, 14),
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
                            fontSize: s(context, 22),
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111118),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/events'),
                          child: Text(
                            'See All',
                            style: TextStyle(
                              fontSize: s(context, 14),
                              color: const Color(0xFF9FA2B2),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: s(context, 12)),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: repo.events.length > 3 ? 3 : repo.events.length,
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
                              iconBg: s(context, 52),
                              iconSize: s(context, 24),
                              cardPadding: s(context, 16),
                              titleFs: s(context, 16),
                              chipFs: s(context, 12),
                              timeFs: s(context, 13),
                              cardRadius: s(context, 20),
                              cardGap: s(context, 12),
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => SizedBox(height: s(context, 12)),
                      ),
                    ),
                  ],
                ),
              ),

              // 하단 탭바
              Positioned(
                left: s(context, 40),
                right: s(context, 40),
                bottom: s(context, 8),
                child: LifeTabBar(
                  onAdd: () async {
                    await Navigator.pushNamed(context, '/event');
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 일정 카드
class _EventTile extends StatelessWidget {
  final Event event;
  final bool running;
  final Duration remain;
  final double rate;
  final VoidCallback onPressed;

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
    final typeTag = event.type.name[0].toUpperCase() + event.type.name.substring(1);

    return Container(
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
                          style: TextStyle(color: const Color(0xFF717489), fontSize: timeFs),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${_batteryDelta(rate, remain)})',
                          style: TextStyle(color: const Color(0xFF717489), fontSize: timeFs - 1),
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

/// 태그 칩
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
