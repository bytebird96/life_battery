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
///
/// "Life Battery" 제목, 중앙의 원형 배터리 게이지, 일정 목록,
/// 하단의 커스텀 탭바로 구성되어 있으며 템플릿 레이아웃을 재현했다.
class LifeBatteryHomeScreen extends ConsumerStatefulWidget {
  const LifeBatteryHomeScreen({super.key});

  @override
  ConsumerState<LifeBatteryHomeScreen> createState() => _LifeBatteryHomeScreenState();
}

class _LifeBatteryHomeScreenState extends ConsumerState<LifeBatteryHomeScreen> {
  // ------------------------------ 상태 필드 ------------------------------
  // 현재 실행 중인 일정의 ID
  String? _runningId;

  // 실행 중인 일정의 남은 시간
  Duration _remain = Duration.zero;

  // 현재 실행 중인 일정의 배터리 증감률
  // 양수면 충전, 음수면 소모를 의미한다.
  double _runningRate = 0;

  // 각 일정별 남은 시간을 저장하는 맵
  final Map<String, Duration> _remainMap = {};

  // 주기적으로 남은 시간을 감소시키는 타이머
  Timer? _countdown;

  /// 화면이 처음 생성될 때 저장된 상태를 복원한다.
  @override
  void initState() {
    super.initState();
    // 저장된 일정 목록의 기본 남은 시간을 초기화
    final repo = ref.read(repositoryProvider);
    for (final e in repo.events) {
      _remainMap[e.id] = e.endAt.difference(e.startAt);
    }

    // 비동기적으로 저장된 실행 정보 복원
    Future.microtask(_loadState);
  }

  /// 위젯이 제거될 때 타이머를 정리한다.
  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  // ------------------------------ 저장/복원 로직 ------------------------------

  /// 남은 시간 정보를 로컬 저장소에 저장
  Future<void> _saveRemainMap() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _remainMap.map((k, v) => MapEntry(k, v.inSeconds));
    await prefs.setString('remainMap', jsonEncode(map));
  }

  /// 실행 중인 작업 정보를 저장
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

  /// 실행 중인 작업 정보를 초기화
  Future<void> _clearRunningTask() async {
    final prefs = await SharedPreferences.getInstance();
    final battery = ref.read(batteryControllerProvider);
    await prefs.setDouble('battery', battery);
    await prefs.remove('taskId');
    await prefs.remove('ratePerHour');
    await prefs.remove('duration');
    await prefs.remove('startTime');
  }

  /// 앱 재시작 시 저장된 정보를 복원
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

  // ------------------------------ 일정 제어 ------------------------------

  /// 일정 시작
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

    // ------------------------------
    // 알림 관련 처리는 플랫폼에 따라 실패할 수 있다.
    // 예를 들어 웹이나 테스트 환경에서는 플러그인이 동작하지 않아
    // 예외가 발생할 수 있으므로 try/catch로 감싸 안전하게 처리한다.
    // ------------------------------
    final notif = ref.read(notificationProvider);
    try {
      await notif.cancel(e.id.hashCode); // 기존 예약 알림 취소
      await notif.scheduleComplete(
        id: e.id.hashCode,
        title: '일정 완료',
        body: '${e.title}이(가) 완료되었습니다',
        after: duration,
      );
    } catch (e) {
      // 알림 예약이 실패해도 작업 진행에는 문제가 없으므로
      // 콘솔에만 오류를 표시하고 무시한다.
      debugPrint('알림 예약 실패: $e');
    }

    _remainMap[e.id] = duration;
    await _saveRunningTask(id: e.id, rate: e.ratePerHour ?? 0, duration: duration);

    _countdown?.cancel();
    setState(() {
      _runningId = e.id;
      _remain = duration;
      _runningRate = e.ratePerHour ?? 0; // 현재 실행 중인 일정의 배터리 변화율 저장
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

  /// 일정 중지
  Future<void> _stopEvent({bool completed = false}) async {
    ref.read(batteryControllerProvider.notifier).stop();
    _countdown?.cancel();

    // 작업 중지 시에도 예약된 알림이 있다면 취소해야 한다.
    // 플러그인 미설치 등의 이유로 실패할 수 있으므로 역시 예외를 무시한다.
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
      _runningRate = 0; // 실행 중인 일정이 없으므로 배터리 변화율 초기화
    });

    await _saveRemainMap();
    await _clearRunningTask();
  }

  /// 일정에 따라 시간당 배터리 증감률을 계산하는 함수
  ///
  /// `ratePerHour`가 null일 경우 이벤트 종류별 기본값을 사용한다.
  double _rateFor(Event e, AppRepository repo) {
    if (e.ratePerHour != null) {
      return e.ratePerHour!; // 일정에 지정된 값
    }

    // 종류에 따라 기본 배터리 변화량 결정
    switch (e.type) {
      case EventType.work:
        return -repo.settings.defaultDrainRate; // 작업은 배터리 소모
      case EventType.rest:
        return repo.settings.defaultRestRate; // 휴식은 조금 충전
      case EventType.sleep:
        return repo.settings.sleepChargeRate; // 수면은 많이 충전
      case EventType.neutral:
        return 0; // 중립은 변화 없음
    }
  }

  // ------------------------------ 빌드 ------------------------------
  @override
  Widget build(BuildContext context) {
    // 배터리 퍼센트(0~100)를 상태관리에서 읽어와 0~1 범위로 변환
    final percent = ref.watch(batteryControllerProvider) / 100;
    final repo = ref.watch(repositoryProvider);

    // 새로 추가된 일정이 있다면 기본 남은 시간을 설정
    for (final e in repo.events) {
      _remainMap.putIfAbsent(e.id, () => e.endAt.difference(e.startAt));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      // Builder를 사용해 MediaQuery 값을 얻고 Stack으로 UI를 배치한다.
      body: Builder(
        builder: (context) {
          // ------------------------------ 스케일 변수 ------------------------------
          // 디자인 시안에서 측정한 값을 스케일 함수로 변환한다.
          // 가로 375 기준에서 계산된 값이므로 어떤 화면에서도 비례를 유지한다.
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
                  // ------------------------------ 제목 ------------------------------
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
                          fontSize: s(context, 28), // 디자인 대비 28px
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),

                  // ------------------------------ 배터리 링 ------------------------------
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

                  // ------------------------------ 일정 리스트 섹션 ------------------------------
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
                        // 홈 화면에서는 최대 3개의 일정만 표시
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

                              // 스와이프로 삭제 기능 제공
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
                                  if (running) {
                                    await _stopEvent();
                                  }
                                  try {
                                    await ref.read(notificationProvider).cancel(e.id.hashCode);
                                  } catch (_) {
                                    // 실패해도 무시
                                  }
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
                                  // 스케일 파라미터 전달
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

                  // ------------------------------ 하단 탭바 ------------------------------
                  Positioned(
                    left: s(context, 40),
                    right: s(context, 40),
                    bottom: s(context, 8),
                    child: LifeTabBar(
                      onAdd: () async {
                        // 일정 추가 후 돌아오면 목록 갱신
                        await Navigator.pushNamed(context, '/event');
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 일정 목록을 보여주는 위젯
/// 디자인 시안과 유사한 형태로 이벤트를 표시하는 타일
class _EventTile extends StatelessWidget {
  final Event event; // 표시할 일정 정보
  final bool running; // 현재 실행 중인지 여부
  final Duration remain; // 남은 시간
  final double rate; // 시간당 배터리 증감률
  final VoidCallback onPressed; // 시작/중지 버튼 콜백

  // ------------------------------ 스케일 파라미터 ------------------------------
  final double iconBg; // 아이콘 배경 원 크기
  final double iconSize; // 아이콘 크기
  final double cardPadding; // 카드 내부 패딩
  final double titleFs; // 제목 글자 크기
  final double chipFs; // 태그 글자 크기
  final double timeFs; // 남은 시간 글자 크기
  final double cardRadius; // 카드 모서리 반경
  final double cardGap; // 아이콘과 내용 사이 간격

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
    // 이벤트 유형을 문자열 태그로 변환 (예: work -> Work)
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

  /// 타일 내부에서 사용할 짧은 시간 포맷터
  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// 남은 시간 동안 변화하는 배터리 퍼센트를 계산해 문자열로 반환
  String _batteryDelta(double rate, Duration remain) {
    final change = rate * remain.inSeconds / 3600;
    final sign = change > 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)}%';
  }
}

/// 태그 표시를 위한 작은 말풍선 모양 위젯
class _TagChip extends StatelessWidget {
  final String text; // 태그에 표시할 문자열
  final Color color; // 배경색
  final Color textColor; // 글자색
  final double fontSize; // 글자 크기
  final double hp; // 가로 패딩
  final double vp; // 세로 패딩
  final double radius; // 모서리 반경

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
