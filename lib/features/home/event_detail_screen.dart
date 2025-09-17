import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../event/edit_event_screen.dart';

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
  bool _localeReady = false; // 한글 날짜 포맷 사용 준비 여부
  late DateFormat _dateFormat; // 시작/종료 날짜 포맷터 (초기화 후 사용)
  late DateFormat _timeFormat; // 시작/종료 시간 포맷터 (초기화 후 사용)

  @override
  void initState() {
    super.initState();
    _remain = widget.remain; // 전달받은 남은 시간을 초기값으로 설정

    // 1) intl 패키지는 한국어 요일/오전·오후 표시를 위해 별도의 초기화가 필요하다.
    // 2) initializeDateFormatting은 비동기로 동작하므로 완료 후 setState로 다시 그리도록 한다.
    initializeDateFormatting('ko').then((_) {
      if (!mounted) return; // 위젯이 사라졌다면 추가 작업 불필요

      setState(() {
        // 초기화가 끝난 뒤에야 한국어 포맷 객체를 안전하게 생성할 수 있다.
        _dateFormat = DateFormat('yyyy년 MM월 dd일 (E)', 'ko');
        _timeFormat = DateFormat('a h시 mm분', 'ko');
        _localeReady = true; // 화면에서 날짜/시간을 정상적으로 보여줄 수 있음을 표시
      });
    }).catchError((error) {
      if (!mounted) return; // 에러가 났더라도 위젯이 남아있을 때만 처리

      setState(() {
        // 초기화가 실패하면 기본 포맷(영문)으로라도 정보를 보여주도록 한다.
        _dateFormat = DateFormat('yyyy-MM-dd (E)');
        _timeFormat = DateFormat('a h:mm');
        _localeReady = true; // 최소한의 정보 제공을 위해 로딩 상태 해제
      });
    });

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

  /// 카드에 표시할 상세 정보를 보기 좋은 문자열로 변환
  String _formatHumanDuration(Duration d) {
    final hours = d.inHours; // 총 시간
    final minutes = d.inMinutes.remainder(60); // 남은 분 단위
    if (hours == 0) {
      return '${minutes}분'; // 시간 단위가 없다면 분만 표시
    }
    if (minutes == 0) {
      return '${hours}시간'; // 분 단위가 없다면 시간만 표시
    }
    return '${hours}시간 ${minutes}분'; // 시간과 분을 함께 표시
  }

  /// 이벤트 타입을 한국어 라벨로 변환
  String _typeLabel(EventType type) {
    switch (type) {
      case EventType.work:
        return '작업/집중';
      case EventType.rest:
        return '휴식';
      case EventType.sleep:
        return '수면';
      case EventType.neutral:
        return '기타';
    }
  }

  /// 일정 수정 화면으로 이동하는 헬퍼
  Future<void> _openEdit(Event event) async {
    // 리포지토리는 ChangeNotifier이므로 ref.read로 최신 인스턴스를 즉시 얻는다.
    final repo = ref.read(repositoryProvider);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditEventScreen(event: event),
      ),
    );

    if (!mounted) return; // 위젯이 이미 사라졌다면 추가 처리 없이 종료

    final refreshed = repo.findEventById(event.id);
    if (refreshed == null) {
      // 수정 화면에서 일정을 삭제했을 수도 있으므로 안전하게 이전 화면으로 돌아간다.
      Navigator.pop(context);
      return;
    }

    if (!widget.running) {
      // 실행 중이 아닌 일정은 남은 시간이 전체 시간보다 길다면 잘라준다.
      final full = refreshed.endAt.difference(refreshed.startAt);
      if (_remain > full) {
        setState(() => _remain = full);
      }
    }
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
    if (!_localeReady) {
      // 한국어 날짜 정보를 준비하는 동안에는 간단한 로딩 화면을 보여준다.
      return Scaffold(
        appBar: AppBar(
          title: const Text('Life Battery'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final repo = ref.watch(repositoryProvider); // 리포지토리 접근
    // 최신 일정 정보를 리포지토리에서 다시 불러온다. (수정 후에도 내용이 갱신되도록)
    final current = repo.findEventById(widget.event.id) ?? widget.event;

    // 전체 일정 동안의 배터리 변화량 계산
    final totalDuration = current.endAt.difference(current.startAt);
    final totalChange =
        _rateFor(current, repo) * totalDuration.inSeconds / 3600; // 퍼센트 단위
    final label = totalChange >= 0 ? '충전량' : '소모량';

    // 상세 정보 카드에 사용할 날짜/시간 문자열을 미리 준비한다.
    final startDate = _dateFormat.format(current.startAt);
    final startTime = _timeFormat.format(current.startAt);
    final endDate = _dateFormat.format(current.endAt);
    final endTime = _timeFormat.format(current.endAt);
    final detailDuration = _formatHumanDuration(totalDuration);
    final content =
        (current.content?.trim().isNotEmpty ?? false) ? current.content!.trim() : '작성된 상세 설명이 없습니다.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Battery'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1) 제목과 남은 시간을 가운데 정렬로 크게 보여준다.
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 일정 제목
                  Text(
                    current.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 배터리 변화량 표시 (양수/음수에 따라 라벨 변경)
                  Text(
                    '$label: ${totalChange.abs().toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  // 남은 시간 표시 (실행 중이면 타이머가 1초마다 갱신된다.)
                  Text(
                    _formatDuration(_remain),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '총 소요 시간: $detailDuration',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // 2) 일정에 대한 자세한 정보를 카드로 정리해 보여준다.
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 시작 시각 정보
                      Row(
                        children: [
                          const Icon(Icons.play_arrow, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('시작 시각', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('$startDate · $startTime'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 종료 시각 정보
                      Row(
                        children: [
                          const Icon(Icons.flag, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('종료 시각', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('$endDate · $endTime'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 일정 유형 정보
                      Row(
                        children: [
                          const Icon(Icons.category, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('일정 유형', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(_typeLabel(current.type)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 상세 설명 (없으면 대체 문구를 보여준다.)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.notes, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('상세 설명', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(content),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // 3) 실행 관련 버튼 영역 (즉시 완료 / 초기화)
              ElevatedButton(
                onPressed: () async {
                  await widget.onInstantComplete();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('즉시 완료'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await widget.onReset();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('초기화'),
              ),
              const SizedBox(height: 16),
              // 4) 하단에 수정 버튼을 배치해 상세 화면에서도 곧바로 편집할 수 있게 한다.
              OutlinedButton.icon(
                onPressed: () => _openEdit(current),
                icon: const Icon(Icons.edit),
                label: const Text('일정 수정'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

