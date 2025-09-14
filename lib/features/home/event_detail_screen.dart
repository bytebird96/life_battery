import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';

/// 일정의 상세 정보를 보여주는 화면
///
/// - 남은 시간과 배터리 변화량을 크게 표시
/// - "즉시 완료" 버튼을 누르면 남은 배터리 변화량을 한 번에 적용
/// - "초기화" 버튼을 누르면 진행 중인 일정을 멈추고 처음 상태로 되돌림
class EventDetailScreen extends ConsumerStatefulWidget {
  final Event event; // 보여줄 일정 정보
  final bool running; // 현재 실행 중인지 여부
  final Duration remain; // 남은 시간
  final Future<void> Function() onInstantComplete; // 즉시 완료 콜백
  final Future<void> Function() onReset; // 초기화 콜백

  const EventDetailScreen({
    super.key,
    required this.event,
    required this.running,
    required this.remain,
    required this.onInstantComplete,
    required this.onReset,
  });

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  late Duration _remain; // 화면에 표시할 남은 시간
  Timer? _timer; // 실행 중인 일정의 시간을 갱신하는 타이머

  @override
  void initState() {
    super.initState();
    _remain = widget.remain; // 전달받은 남은 시간을 초기값으로 설정

    // 실행 중인 일정이라면 1초마다 남은 시간을 감소시킨다.
    if (widget.running) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          if (_remain.inSeconds > 0) {
            _remain -= const Duration(seconds: 1);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // 타이머 정리
    super.dispose();
  }

  /// Duration을 "HH:mm:ss" 형태의 문자열로 변환하는 헬퍼
  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// 이벤트 종류에 따라 시간당 배터리 변화를 계산
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

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider); // 리포지토리 접근
    final e = widget.event; // 가독성을 위한 별칭

    // 전체 일정 동안의 배터리 변화량 계산
    final totalDuration = e.endAt.difference(e.startAt);
    final totalChange =
        _rateFor(e, repo) * totalDuration.inSeconds / 3600; // 퍼센트 단위
    final label = totalChange >= 0 ? '충전량' : '소모량';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Battery'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 일정 제목
            Text(
              e.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            // 배터리 변화량 표시
            Text(
              '$label: ${totalChange.abs().toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            // 남은 시간 표시
            Text(
              _formatDuration(_remain),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            // 즉시 완료 버튼
            ElevatedButton(
              onPressed: () async {
                await widget.onInstantComplete();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('즉시 완료'),
            ),
            const SizedBox(height: 8),
            // 초기화 버튼
            TextButton(
              onPressed: () async {
                await widget.onReset();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('초기화'),
            ),
          ],
        ),
      ),
    );
  }
}

