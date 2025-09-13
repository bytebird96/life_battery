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

    final notif = ref.read(notificationProvider);
    await notif.cancel(e.id.hashCode);
    await notif.scheduleComplete(
      id: e.id.hashCode,
      title: '일정 완료',
      body: '${e.title}이(가) 완료되었습니다',
      after: duration,
    );

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

    if (!completed && _runningId != null) {
      await ref.read(notificationProvider).cancel(_runningId!.hashCode);
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
                top: 360,
                left: 20,
                right: 20,
                bottom: 100,
                child: ListView.separated(
                  itemCount: repo.events.length,
                  itemBuilder: (context, index) {
                    final e = repo.events[index];
                    final running = _runningId == e.id;
                    final base = e.endAt.difference(e.startAt);
                    final remain = running ? _remain : _remainMap[e.id] ?? base;

                    return _EventTile(
                      event: e,
                      running: running,
                      remain: remain,
                      onPressed: () async {
                        if (running) {
                          await _stopEvent();
                        } else {
                          await _startEvent(e);
                        }
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
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

  @override
  Widget build(BuildContext context) {
    // 디자인 시안과 동일하게 220x220 크기의 원형 게이지를 사용한다.
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 연한 배경 원 (전체 100%)
          CustomPaint(
            size: const Size(220, 220),
            painter: _CirclePainter(
              progress: 1,
              color: const Color(0xFFEAE6FF), // 옅은 보라색
            ),
          ),
          // 실제 퍼센트만큼 채워지는 보라색 원호
          CustomPaint(
            size: const Size(220, 220),
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
  final VoidCallback onPressed; // 시작/중지 버튼 콜백

  const _EventTile({
    required this.event,
    required this.running,
    required this.remain,
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
                    Text(
                      _formatDuration(remain),
                      style: const TextStyle(color: Colors.black54),
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
    const strokeWidth = 16.0; // 선의 두께 (디자인 시안과 동일)
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

