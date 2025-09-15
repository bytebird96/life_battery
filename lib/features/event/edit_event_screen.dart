import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../core/compute.dart';
import 'event_icons.dart';
import 'event_colors.dart';

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

/// 아이콘 선택 버튼 위젯
///
/// - 동그란 버튼 안에 실제 아이콘을 보여주고 선택 시 강조 표시한다.
/// - 사용자가 어떤 아이콘인지 이해할 수 있도록 아래에 라벨 텍스트도 출력한다.
class _IconChoice extends StatelessWidget {
  final EventIconOption option; // 현재 표시할 아이콘 옵션
  final bool selected; // 사용자가 이 옵션을 선택했는지 여부
  final VoidCallback onSelected; // 사용자가 누를 때 실행할 콜백

  const _IconChoice({
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? const Color(0xFF9B51E0) : const Color(0xFFF7F7FA);
    final borderColor = selected ? const Color(0xFF9B51E0) : const Color(0xFFDDDEE5);
    final iconColor = selected ? Colors.white : const Color(0xFF717489);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onSelected,
            customBorder: const CircleBorder(),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              alignment: Alignment.center,
              child: Icon(option.icon, color: iconColor, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          option.label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF55586A)),
        ),
      ],
    );
  }
}

/// 색상 선택 버튼 위젯
///
/// - 원형 색상 뱃지를 보여주고 선택된 색상은 체크 아이콘으로 강조한다.
/// - 초보자도 이해할 수 있도록 아래에 색상 이름을 함께 노출한다.
class _ColorChoice extends StatelessWidget {
  final EventColorOption option; // 현재 표시할 색상 옵션
  final bool selected; // 사용자가 이 색상을 선택했는지 여부
  final VoidCallback onSelected; // 누를 때 실행할 콜백

  const _ColorChoice({
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onSelected,
            customBorder: const CircleBorder(),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: option.color, // 실제 색상 표시
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : option.color.withOpacity(0.4), // 선택 여부에 따른 테두리 색상
                  width: 3,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: option.color.withOpacity(0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check, color: Colors.white)
                  : null, // 선택된 경우 체크 아이콘 표시
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          option.label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF55586A)),
        ),
      ],
    );
  }
}

class _EditEventState extends ConsumerState<EditEventScreen> {
  final _formKey = GlobalKey<FormState>(); // 폼 상태 관리 키

  // --- 사용자가 입력할 값들 ---
  String _title = ''; // 일정 제목
  String _content = ''; // 일정 설명
  int _minutes = 0; // 소요 시간(분)
  double _battery = 0.0; // 배터리 변화량(절대값, 양수만 저장)
  bool _isCharge = false; // true=충전, false=소모 (기본값: 소모)
  String _iconName = defaultEventIconName; // 선택된 아이콘 식별자 (문자열)
  String _colorName = defaultEventColorName; // 선택된 색상 식별자 (문자열)

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
      _iconName = e.iconName; // 저장된 아이콘을 그대로 사용
      _colorName = e.colorName; // 저장된 색상도 함께 적용
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
            const SizedBox(height: 16),
            // 아이콘 선택 영역 (여러 후보 중 하나 선택)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '아이콘 선택',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final option in eventIconOptions)
                      _IconChoice(
                        option: option,
                        selected: _iconName == option.name,
                        onSelected: () {
                          setState(() => _iconName = option.name);
                        },
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 색상 선택 영역 (원형 색상 중 하나 선택)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '색상 선택',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final option in eventColorOptions)
                      _ColorChoice(
                        option: option,
                        selected: _colorName == option.name,
                        onSelected: () {
                          setState(() => _colorName = option.name);
                        },
                      ),
                  ],
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
                  iconName: _iconName, // 사용자가 고른 아이콘을 함께 저장
                  colorName: _colorName, // 사용자가 고른 색상도 함께 저장
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
