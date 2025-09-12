import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../core/compute.dart';

/// 일정 등록/수정 화면
/// - 제목, 내용, 소요 시간, 배터리 변화를 입력받아 이벤트를 저장하거나 수정
class EditEventScreen extends ConsumerStatefulWidget {
  /// [event]가 null이면 신규 등록, null이 아니면 해당 일정을 수정
  const EditEventScreen({super.key, this.event});

  /// 수정 대상 일정 (없으면 새 일정 등록 모드)
  final Event? event;

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventState();
}

class _EditEventState extends ConsumerState<EditEventScreen> {
  final _formKey = GlobalKey<FormState>(); // 폼 상태 관리 키

  // --- 사용자가 입력할 값들 ---
  String _title = ''; // 일정 제목
  String _content = ''; // 일정 설명
  int _minutes = 0; // 소요 시간(분)
  double _battery = 0.0; // 배터리 변화량(절대값, 양수만 저장)
  bool _isCharge = false; // true=충전, false=소모 (기본값: 소모)

  @override
  void initState() {
    super.initState();
    final e = widget.event; // 전달받은 일정이 있는지 확인
    if (e != null) {
      // 기존 일정 정보를 입력 폼에 미리 채워 넣는다.
      _title = e.title;
      _content = e.content ?? '';
      _minutes = e.endAt.difference(e.startAt).inMinutes;
      final total = (e.ratePerHour ?? 0) * (_minutes / 60); // 전체 배터리 변화량
      _isCharge = total >= 0; // 0 이상이면 충전, 음수면 소모
      _battery = total.abs(); // 표시를 위해 절대값 사용
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider); // 리포지토리 접근
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.event == null ? '일정 등록' : '일정 수정')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 제목 입력 필드
            TextFormField(
              decoration: const InputDecoration(labelText: '제목'),
              initialValue: _title,
              onChanged: (v) => _title = v,
            ),
            // 내용(상세 설명) 입력 필드
            TextFormField(
              decoration: const InputDecoration(labelText: '내용'),
              initialValue: _content,
              onChanged: (v) => _content = v,
            ),
            // 소요 시간 입력 필드 (분 단위)
            TextFormField(
              decoration: const InputDecoration(labelText: '소요 시간(분)'),
              keyboardType: TextInputType.number,
              initialValue: _minutes == 0 ? '' : _minutes.toString(),
              onChanged: (v) => _minutes = int.tryParse(v) ?? 0,
            ),
            // 배터리 변화 입력 (충전/소모 선택 + 퍼센트)
            Row(
              children: [
                // 충전/소모 선택 드롭다운
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<bool>(
                    decoration: const InputDecoration(labelText: '종류'),
                    value: _isCharge,
                    items: const [
                      DropdownMenuItem(value: false, child: Text('소모')),
                      DropdownMenuItem(value: true, child: Text('충전')),
                    ],
                    onChanged: (v) => setState(() => _isCharge = v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                // 배터리 변화량 입력 (양수만 입력)
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    decoration:
                        const InputDecoration(labelText: '배터리 변화(%)'),
                    keyboardType: TextInputType.number,
                    initialValue: _battery == 0 ? '' : _battery.toString(),
                    onChanged: (v) =>
                        _battery = double.tryParse(v) ?? 0.0, // 숫자 변환 실패 시 0.0
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 저장 버튼
            ElevatedButton(
              onPressed: () {
                final start =
                    widget.event?.startAt ?? DateTime.now(); // 기존 일정이면 시작 시각 유지
                final end = start.add(Duration(minutes: _minutes)); // 종료 시각 계산
                final change =
                    _isCharge ? _battery : -_battery; // 선택에 따라 부호 결정
                final double rate = _minutes > 0
                    ? change / (_minutes / 60)
                    : 0.0; // 0.0을 사용해 double 타입 유지

                // 이벤트 생성 (신규/수정 공용)
                final e = Event(
                  id: widget.event?.id ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  title: _title,
                  content: _content,
                  startAt: start,
                  endAt: end,
                  type: widget.event?.type ?? EventType.neutral,
                  ratePerHour: rate,
                  priority:
                      widget.event?.priority ?? defaultPriority(EventType.neutral),
                  createdAt: widget.event?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                repo.saveEvent(e); // 이벤트 저장/수정
                Navigator.pop(context); // 이전 화면으로 복귀
              },
              child: Text(widget.event == null ? '저장' : '수정'),
            )
          ],
        ),
      ),
    );
  }
}
