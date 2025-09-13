import 'dart:async'; // Timer 사용
import 'dart:convert'; // JSON 변환
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'battery_controller.dart';
import '../../data/models.dart'; // Event 모델 사용
import '../../data/repositories.dart'; // 일정 저장소
import '../../services/notifications.dart'; // 알림 서비스
import 'package:shared_preferences/shared_preferences.dart'; // 로컬 저장소
import 'widgets/life_tab_bar.dart'; // 하단 탭바 위젯

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
      body: Center(
        child: SizedBox(
          width: 375,
          height: 812,
          child: Stack(
            children: [
              const Positioned(
                top: 64,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Life Battery',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 129,
                left: 0,
                right: 0,
                child: Center(child: _CircularBattery(percent: percent)),
              ),
              Positioned(
              Positioned(
                top: 330,
                left: 20,
                right: 20,
                bottom: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '일정',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/events'),
                          child: const Text(
                            'See All',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 홈 화면에서는 최대 3개의 일정만 표시한다.
                    Expanded(
                      child: ListView.separated(
                        itemCount: repo.events.length > 3 ? 3 : repo.events.length,
                        itemBuilder: (context, index) {
                          final e = repo.events[index];
                          final running = _runningId == e.id;
                          final base = e.endAt.difference(e.startAt); // 전체 시간
                          final remain = running ? _remain : _remainMap[e.id] ?? base;
                          final rate = _rateFor(e, repo); // 시간당 배터리 증감률 계산

                          // 스와이프로 삭제할 수 있도록 Dismissible 사용
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
                                await _stopEvent(); // 실행 중이면 중지
                              }
                              try {
                                await ref.read(notificationProvider).cancel(e.id.hashCode);
                              } catch (_) {
                                // 실패해도 무시
                              }
                              await ref.read(repositoryProvider).deleteEvent(e.id);
                              setState(() {
                                _remainMap.remove(e.id); // 남은 시간도 제거
                              });
                              await _saveRemainMap();
                            },
                            child: _EventTile(
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
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 40,
                right: 40,
                bottom: 8,
                child: LifeTabBar(
                  onAdd: () async {
                    // 일정 추가 후 돌아오면 목록 갱신
                    await Navigator.pushNamed(context, '/event');
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 배터리 퍼센트를 원형으로 그려주는 위젯
class _CircularBattery extends StatelessWidget {
  final double percent; // 0~1 사이의 값

  const _CircularBattery({required this.percent});

  // 원형 배터리 전체 크기
  // 기존 220px에서 30% 줄인 154px를 사용한다.
  static const double _gaugeSize = 154;

  @override
  Widget build(BuildContext context) {
    // 디자인 시안(220x220)에서 30% 축소된 154x154 크기의 원형 게이지를 사용한다.
    return SizedBox(
      width: _gaugeSize,
      height: _gaugeSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 연한 배경 원 (전체 100%)
          CustomPaint(
            size: const Size(_gaugeSize, _gaugeSize),
            painter: _CirclePainter(
              progress: 1,
              color: const Color(0xFFEAE6FF), // 옅은 보라색
            ),
          ),
          // 실제 퍼센트만큼 채워지는 보라색 원호
          CustomPaint(
            size: const Size(_gaugeSize, _gaugeSize),
            painter: _CirclePainter(
              progress: percent,
              color: const Color(0xFF9B51E0), // 진한 보라색
            ),
          ),
          // 중앙에 퍼센트 텍스트 표시
          Text(
            '${(percent * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 40,
              letterSpacing: 2, // 디자인에서 사용된 자간
            ),
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

  const _EventTile({
    required this.event,
    required this.running,
    required this.remain,
    required this.rate,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // 이벤트 유형을 문자열 태그로 변환 (예: work -> Work)
    final typeTag = event.type.name[0].toUpperCase() + event.type.name.substring(1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF9B51E0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.computer, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    // 남은 시간과 그 동안 변하는 배터리 퍼센트 표시
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDuration(remain),
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          // 전체 남은 시간 동안 변하는 배터리 양 계산
                          '(${_batteryDelta(rate, remain)})',
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _TagChip(
                      text: typeTag,
                      color: const Color(0xFFFFE8EC),
                      textColor: const Color(0xFFF35D6A),
                    ),
                    const SizedBox(width: 4),
                    if (event.content != null && event.content!.isNotEmpty)
                      _TagChip(
                        text: event.content!,
                        color: const Color(0xFFF5F0FF),
                        textColor: const Color(0xFF9B51E0),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
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

  const _TagChip({
    required this.text,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 12),
      ),
    );
  }
}

/// 원형 진행률을 그려주는 커스텀 페인터
class _CirclePainter extends CustomPainter {
  final double progress; // 0~1 사이 진행률
  final Color color; // 선 색상

  _CirclePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // 선 두께도 전체 크기 축소 비율(30%)에 맞춰 11.2로 조정
    const strokeWidth = 11.2; // 기존 16에서 30% 줄인 값
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - strokeWidth / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round; // 끝을 둥글게 처리

    // -pi/2 부터 시작해서 progress 비율만큼 그린다 (12시 방향 기준)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CirclePainter oldDelegate) {
    // progress 또는 color가 변경되면 다시 그린다
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

