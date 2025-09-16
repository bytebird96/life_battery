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

/// 업무 강도 옵션을 정의하는 열거형
///
/// - 각 항목은 `시간당 배터리 변화량(ratePerHour)`을 고정값으로 제공한다.
/// - 사용자는 이해하기 쉬운 라벨과 설명을 보고 적절한 강도를 선택한다.
enum _IntensityLevel {
  low, // 여유로운 업무 (낮은 소모)
  medium, // 일반적인 업무
  high, // 몰입이 필요한 고강도 업무
}

/// [_IntensityLevel]에 부가 정보를 제공하는 확장
extension _IntensityLevelDescription on _IntensityLevel {
  /// UI에 표시할 간단한 라벨
  String get label {
    switch (this) {
      case _IntensityLevel.low:
        return '여유로움';
      case _IntensityLevel.medium:
        return '보통';
      case _IntensityLevel.high:
        return '집중';
    }
  }

  /// 사용자가 참고할 수 있는 상세 설명 (초보자 배려)
  String get description {
    switch (this) {
      case _IntensityLevel.low:
        return '간단한 확인 위주의 업무 (시간당 약 5%)';
      case _IntensityLevel.medium:
        return '일반적인 작업량 (시간당 약 10%)';
      case _IntensityLevel.high:
        return '고강도 집중 작업 (시간당 약 15%)';
    }
  }

  /// 시간당 배터리 변화율(절대값) - %/h 단위
  double get ratePerHour {
    switch (this) {
      case _IntensityLevel.low:
        return 5.0;
      case _IntensityLevel.medium:
        return 10.0;
      case _IntensityLevel.high:
        return 15.0;
    }
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
  bool _useManualBatteryInput = false; // 고급 옵션 사용 여부 (true면 직접 입력)
  _IntensityLevel _selectedIntensity =
      _IntensityLevel.medium; // 기본 업무 강도 (보통)

  // 강도 추정 시 사용할 허용 오차 (floating point 보정용)
  static const double _intensityTolerance = 0.01;

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
      final rate = (e.ratePerHour ?? 0).abs(); // 시간당 변화율의 절대값
      final matched = _matchIntensity(rate); // 기존 일정의 강도를 역으로 추정
      if (matched != null) {
        _selectedIntensity = matched; // 추정이 가능한 경우 자동 계산 유지
        _useManualBatteryInput = false;
      } else {
        _useManualBatteryInput = true; // 기존 수치가 표준 강도와 다르면 직접 입력으로 전환
      }
    } else {
      _useManualBatteryInput = false; // 신규 등록 시 기본적으로 자동 계산 사용
    }
  }

  /// 저장된 시간당 변화율이 강도 옵션 중 하나와 가까운지 확인하는 헬퍼
  _IntensityLevel? _matchIntensity(double rate) {
    if (rate <= 0) {
      return null; // 0 이하이면 강도를 추정할 수 없다.
    }
    for (final level in _IntensityLevel.values) {
      if ((level.ratePerHour - rate).abs() < _intensityTolerance) {
        return level; // 허용 오차 내에 있으면 해당 강도로 본다.
      }
    }
    return null; // 어떤 강도와도 맞지 않는 경우 null 반환
  }

  /// 강도/시간/직접 입력 상태를 종합해 총 배터리 변화를 계산한다.
  double _calculateBatteryChange() {
    if (_minutes <= 0) {
      return 0.0; // 시간이 0이면 변화도 0으로 간주
    }
    if (_useManualBatteryInput) {
      final manual = _battery <= 0 ? 0.0 : _battery; // 음수 또는 0 이하 입력은 0으로 처리
      return _isCharge ? manual : -manual; // 충전/소모 선택에 따라 부호 적용
    }
    final intensityRate = _selectedIntensity.ratePerHour; // 선택된 강도의 시간당 변화율
    final hours = _minutes / 60.0; // 분 단위를 시간 단위로 변환
    final change = intensityRate * hours; // 절대값 기준 변화량 계산
    return _isCharge ? change : -change; // 충전 시 양수, 소모 시 음수
  }

  /// 미리보기 텍스트를 사용자 친화적으로 생성한다.
  String _buildBatteryPreviewText() {
    if (_minutes <= 0) {
      return '예상 배터리 변화: 시간을 입력하면 자동 계산됩니다.';
    }
    final change = _calculateBatteryChange();
    if (change == 0) {
      return '예상 배터리 변화: 변화 없음 (입력값을 확인해 주세요)';
    }
    final action = change > 0 ? '충전' : '소모';
    final sign = change > 0 ? '+' : '-';
    final amount = change.abs();
    final perHour = amount / (_minutes / 60.0);
    return '예상 배터리 변화: $action $sign${amount.toStringAsFixed(1)}% (시간당 $sign${perHour.toStringAsFixed(1)}%)';
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
              onChanged: (v) {
                setState(() {
                  _minutes = int.tryParse(v) ?? 0; // 값이 바뀌면 즉시 상태 갱신
                });
              },
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return '소요 시간을 입력해주세요.'; // 필수 입력 안내
                }
                final parsed = int.tryParse(v);
                if (parsed == null || parsed <= 0) {
                  return '1분 이상의 숫자를 입력해주세요.'; // 음수/0 방지
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            // 배터리 변화 입력 (충전/소모 + 자동 계산 및 직접 입력 토글)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<bool>(
                  decoration: const InputDecoration(labelText: '종류'),
                  value: _isCharge,
                  items: const [
                    DropdownMenuItem(value: false, child: Text('소모')),
                    DropdownMenuItem(value: true, child: Text('충전')),
                  ],
                  onChanged: (v) {
                    setState(() => _isCharge = v ?? false); // 부호 선택도 즉시 반영
                  },
                ),
                const SizedBox(height: 12),
                if (!_useManualBatteryInput) ...[
                  const Text(
                    '업무 강도 선택',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  // 라디오 버튼으로 강도를 선택해 자동 계산 값을 지정
                  for (final level in _IntensityLevel.values)
                    RadioListTile<_IntensityLevel>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(level.label),
                      subtitle: Text(level.description),
                      value: level,
                      groupValue: _selectedIntensity,
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _selectedIntensity = value);
                      },
                    ),
                ],
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('고급 옵션: 배터리 변화 직접 입력'),
                  subtitle:
                      const Text('자동 계산이 맞지 않을 때 수동으로 값을 설정하세요.'),
                  value: _useManualBatteryInput,
                  onChanged: (value) {
                    setState(() => _useManualBatteryInput = value);
                  },
                ),
                if (_useManualBatteryInput)
                  TextFormField(
                    decoration:
                        const InputDecoration(labelText: '배터리 변화(%)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue: _battery == 0 ? '' : _battery.toString(),
                    onChanged: (v) {
                      setState(() {
                        _battery =
                            double.tryParse(v) ?? 0.0; // 숫자 변환 실패 시 0으로 처리
                      });
                    },
                    validator: (v) {
                      if (!_useManualBatteryInput) {
                        return null; // 자동 계산 모드에서는 검증하지 않음
                      }
                      if (v == null || v.isEmpty) {
                        return '배터리 변화량을 입력해주세요.';
                      }
                      final parsed = double.tryParse(v);
                      if (parsed == null || parsed <= 0) {
                        return '0보다 큰 숫자를 입력해주세요.';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 8),
                Text(
                  _buildBatteryPreviewText(), // 실시간 미리보기 출력
                  style: const TextStyle(color: Color(0xFF55586A)),
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
                FocusScope.of(context).unfocus(); // 저장 시 키보드를 닫아준다.
                if (!(_formKey.currentState?.validate() ?? false)) {
                  return; // 검증 실패 시 저장을 중단한다.
                }
                final minutes = _minutes > 0 ? _minutes : 0; // 혹시 모를 음수 입력 방어
                final start =
                    widget.event?.startAt ?? DateTime.now(); // 기존 일정이면 시작 시각 유지
                final end = start.add(Duration(minutes: minutes)); // 종료 시각 계산
                final change = _calculateBatteryChange(); // 총 배터리 변화(부호 포함)
                final double rate = minutes > 0
                    ? change / (minutes / 60)
                    : 0.0; // 분 단위를 시간으로 환산해 시간당 변화율 산출

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
