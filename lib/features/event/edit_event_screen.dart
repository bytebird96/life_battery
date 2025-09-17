import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../core/compute.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/schedule_models.dart';
import '../../data/schedule_repository.dart';
import '../../services/geofence_manager.dart';
import '../schedule/widgets/map_preview.dart';
import 'event_colors.dart';
import 'event_icons.dart';

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
  final _minutesController = TextEditingController(); // 소요 시간을 표시/수정할 입력 컨트롤러
  int _minutes = 0; // 소요 시간(분)
  late DateTime _startAt; // 사용자가 선택한 시작 시각
  late DateTime _endAt; // 사용자가 선택한 종료 시각
  double _battery = 0.0; // 배터리 변화량(절대값, 양수만 저장)
  bool _isCharge = false; // true=충전, false=소모 (기본값: 소모)
  String _iconName = defaultEventIconName; // 선택된 아이콘 식별자 (문자열)
  String _colorName = defaultEventColorName; // 선택된 색상 식별자 (문자열)
  bool _useManualBatteryInput = false; // 고급 옵션 사용 여부 (true면 직접 입력)
  _IntensityLevel _selectedIntensity =
      _IntensityLevel.medium; // 기본 업무 강도 (보통)

  // --- 위치 기반 일정과 연동하기 위한 추가 상태 ---
  final _placeController = TextEditingController(); // 장소명 입력 필드
  final _latController = TextEditingController(); // 위도 입력 필드
  final _lngController = TextEditingController(); // 경도 입력 필드
  bool _useLocation = false; // 위치 기반 알림 사용 여부
  double? _lat; // 사용자가 설정한 위도
  double? _lng; // 사용자가 설정한 경도
  double _radius = 150; // 지오펜스 반경 (미터)
  ScheduleTriggerType _triggerType = ScheduleTriggerType.arrive; // 도착/이탈 트리거
  ScheduleDayCondition _dayCondition = ScheduleDayCondition.always; // 요일 조건
  SchedulePresetType _presetType = SchedulePresetType.move; // 알림 문구 프리셋
  bool _remindIfNotExecuted = true; // 미실행 시 반복 알림 여부
  bool _scheduleExecuted = false; // 기존 일정이 이미 실행 완료인지 기록
  DateTime? _scheduleCreatedAt; // 기존 일정 생성 시각(없으면 새로 생성)
  Schedule? _loadedSchedule; // 로딩된 위치 기반 일정 정보 (null이면 새로 생성)
  bool _saving = false; // 저장 버튼 중복 클릭 방지용 플래그
  bool _gettingLocation = false; // 현재 위치 읽기 진행 상태

  // 강도 추정 시 사용할 허용 오차 (floating point 보정용)
  static const double _intensityTolerance = 0.01;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now(); // 현재 시각을 미리 계산 (여러 곳에서 사용)
    final e = widget.event; // 전달받은 일정이 있는지 확인
    if (e != null) {
      // 기존 일정 정보를 입력 폼에 미리 채워 넣는다.
      _title = e.title;
      _content = e.content ?? '';
      _startAt = e.startAt; // 기존 일정의 시작 시각을 그대로 가져온다.
      _endAt = e.endAt; // 기존 일정의 종료 시각도 함께 저장한다.
      _minutes = _endAt.difference(_startAt).inMinutes;
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
      _startAt = now; // 새 일정은 현재 시각을 기본 시작 시각으로 사용한다.
      _endAt = now.add(const Duration(hours: 1)); // 기본 종료 시각은 1시간 뒤로 설정한다.
      _minutes = _endAt.difference(_startAt).inMinutes; // 기본 소요 시간은 60분으로 맞춘다.
    }

    // 초기 소요 시간을 텍스트 필드에도 반영해 사용자가 현재 값을 바로 확인할 수 있게 한다.
    _updateMinutesTextField();

    if (e != null) {
      // 위치 기반 일정과 연동되어 있다면 추가 정보를 비동기로 불러온다.
      Future.microtask(() => _loadLinkedSchedule(e.id));
    }
  }

  @override
  void dispose() {
    // 위치 입력용 컨트롤러는 메모리 누수를 막기 위해 반드시 해제한다.
    _placeController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _minutesController.dispose();
    super.dispose();
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

  /// _minutes 값이 갱신될 때마다 텍스트 필드의 표시도 함께 맞춰주는 헬퍼
  void _updateMinutesTextField() {
    final text = _minutes > 0 ? _minutes.toString() : '';
    _minutesController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
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

  /// 기존 이벤트와 연결된 위치 기반 일정이 있다면 정보를 불러와 폼에 채워 넣는다.
  Future<void> _loadLinkedSchedule(String eventId) async {
    final repo = ref.read(scheduleRepositoryProvider);
    final schedule = await repo.findById(eventId);
    if (!mounted || schedule == null) {
      return; // 연동된 위치 일정이 없다면 그대로 종료
    }
    setState(() {
      _useLocation = schedule.useLocation;
      _placeController.text = schedule.placeName ?? '';
      _lat = schedule.lat;
      _lng = schedule.lng;
      _latController.text = schedule.lat?.toStringAsFixed(6) ?? '';
      _lngController.text = schedule.lng?.toStringAsFixed(6) ?? '';
      _radius = schedule.radiusMeters ?? 150;
      _triggerType = schedule.triggerType;
      _dayCondition = schedule.dayCondition;
      _presetType = schedule.presetType;
      _remindIfNotExecuted = schedule.remindIfNotExecuted;
      _scheduleExecuted = schedule.executed;
      _scheduleCreatedAt = schedule.createdAt;
      _loadedSchedule = schedule;
      _startAt = schedule.startAt; // 일정과 동일한 시작 시각으로 동기화한다.
      _endAt = schedule.endAt; // 종료 시각도 동일하게 맞춰준다.
      _minutes = _endAt.difference(_startAt).inMinutes; // 소요 시간을 다시 계산해 둔다.
    });
    _updateMinutesTextField(); // UI에 반영되도록 텍스트 필드도 갱신한다.
  }

  /// 현재 위치 버튼을 눌렀을 때 호출되는 함수. 지오로케이터를 이용해 좌표를 갱신한다.
  Future<void> _setCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 허용해주세요.')),
        );
        return;
      }
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        await Geolocator.openLocationSettings();
        return; // 사용자가 설정을 켤 수 있도록 시스템 설정 화면으로 이동
      }

      setState(() => _gettingLocation = true); // 저장 버튼이 비활성화되도록 상태 갱신
      final position =
          await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _latController.text = _lat!.toStringAsFixed(6);
        _lngController.text = _lng!.toStringAsFixed(6);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('현재 위치를 가져오지 못했습니다: $e')));
    } finally {
      if (mounted) {
        setState(() => _gettingLocation = false);
      }
    }
  }

  /// 시작/종료 시각을 고르는 UI를 따로 추출했다.
  Widget _buildDateTimeRow(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm'); // 날짜/시간을 보기 좋게 포맷팅
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '시작/종료 시각',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('시작 시각'),
                subtitle: Text(formatter.format(_startAt)),
                onTap: () => _pickDateTime(isStart: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('종료 시각'),
                subtitle: Text(formatter.format(_endAt)),
                onTap: () => _pickDateTime(isStart: false),
              ),
            ),
          ],
        ),
        const Text(
          '시간을 직접 조정하면 위의 소요 시간이 자동으로 업데이트됩니다.',
          style: TextStyle(fontSize: 12, color: Color(0xFF55586A)),
        ),
      ],
    );
  }

  /// 날짜/시간 선택 다이얼로그를 호출해 시작 또는 종료 시각을 수정한다.
  Future<void> _pickDateTime({required bool isStart}) async {
    final base = isStart ? _startAt : _endAt; // 현재 선택되어 있는 기준 시각
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000), // 너무 과거/미래는 제한한다.
      lastDate: DateTime(2100),
    );
    if (date == null) {
      return; // 사용자가 취소한 경우
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) {
      return; // 시간 선택도 취소하면 종료
    }
    final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final previousMinutes = _endAt.difference(_startAt).inMinutes; // 기존 소요 시간 기억
    final fallbackMinutes = _minutes > 0
        ? _minutes
        : (previousMinutes > 0 ? previousMinutes : 60); // 0 이하일 때 기본값 보정

    setState(() {
      if (isStart) {
        _startAt = selected; // 시작 시각을 새로 지정
        final keepMinutes = fallbackMinutes > 0 ? fallbackMinutes : 60;
        _endAt = _startAt.add(Duration(minutes: keepMinutes)); // 기존 소요 시간을 유지하도록 종료 시각을 이동
      } else {
        if (selected.isAfter(_startAt)) {
          _endAt = selected; // 정상적으로 더 늦은 시각이면 그대로 반영
        } else {
          _endAt = _startAt.add(const Duration(minutes: 1)); // 최소 1분 이상 차이가 나도록 보정
        }
      }
      final diff = _endAt.difference(_startAt).inMinutes;
      _minutes = diff > 0 ? diff : 1; // 다시 계산한 소요 시간을 상태에 반영
    });
    _updateMinutesTextField(); // 숫자 입력창도 최신 값으로 동기화
  }

  /// 위치 기반 일정 옵션에 공통으로 사용하는 라디오 리스트 UI를 생성한다.
  Widget _buildScheduleRadioSection<T>({
    required String title,
    required List<T> values,
    required T groupValue,
    required String Function(T) labelBuilder,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        for (final value in values)
          RadioListTile<T>(
            contentPadding: EdgeInsets.zero,
            title: Text(labelBuilder(value)),
            value: value,
            groupValue: groupValue,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
      ],
    );
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
              controller: _minutesController,
              decoration: const InputDecoration(labelText: '소요 시간(분)'),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final parsed = int.tryParse(v);
                setState(() {
                  _minutes = parsed ?? 0; // 값이 바뀌면 즉시 상태 갱신
                  if (parsed != null && parsed > 0) {
                    // 사용자가 시간을 바꾸면 종료 시각도 함께 이동시켜 일관성을 유지한다.
                    _endAt = _startAt.add(Duration(minutes: parsed));
                  }
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
            // 시작/종료 시각을 직관적으로 선택할 수 있는 영역
            _buildDateTimeRow(context),
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
            const Divider(),
            const SizedBox(height: 16),
            // ================= 위치 기반 일정 옵션 =================
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '위치 기반 알림',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '특정 장소에 도착하거나 이탈했을 때 자동으로 일정을 알려주고 싶다면 아래 옵션을 켜주세요.',
                  style: TextStyle(color: Color(0xFF55586A)),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('위치 기반 알림 사용'),
                  subtitle: const Text('지오펜스를 만들어 도착/이탈 시 알림을 받습니다.'),
                  value: _useLocation,
                  onChanged: (value) {
                    setState(() => _useLocation = value);
                  },
                ),
                if (_useLocation) ...[
                  TextField(
                    controller: _placeController,
                    decoration: const InputDecoration(
                      labelText: '장소명 (선택)',
                      helperText: '예: 회사, 헬스장 등. 입력하지 않으면 좌표만 사용합니다.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latController,
                          decoration: const InputDecoration(labelText: '위도'),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            setState(() {
                              _lat = double.tryParse(value.replaceAll(',', '.'));
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _lngController,
                          decoration: const InputDecoration(labelText: '경도'),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            setState(() {
                              _lng = double.tryParse(value.replaceAll(',', '.'));
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _gettingLocation ? null : _setCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: Text(_gettingLocation ? '현재 위치 확인 중...' : '현재 위치로 좌표 설정'),
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: _radius,
                    min: 50,
                    max: 300,
                    divisions: 5,
                    label: '${_radius.toStringAsFixed(0)}m',
                    onChanged: (value) {
                      setState(() => _radius = value);
                    },
                  ),
                  const Text(
                    '반경은 알림을 울리고 싶은 범위를 의미합니다. 숫자가 커질수록 더 넓은 영역에서 감지합니다.',
                    style: TextStyle(color: Color(0xFF55586A)),
                  ),
                  const SizedBox(height: 12),
                  MapPreview(lat: _lat, lng: _lng, radius: _radius),
                  const SizedBox(height: 16),
                  _buildScheduleRadioSection<ScheduleTriggerType>(
                    title: '트리거 유형',
                    values: ScheduleTriggerType.values,
                    groupValue: _triggerType,
                    labelBuilder: (value) => (value as Enum).koLabel,
                    onChanged: (value) {
                      setState(() => _triggerType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildScheduleRadioSection<ScheduleDayCondition>(
                    title: '요일/공휴일 조건',
                    values: ScheduleDayCondition.values,
                    groupValue: _dayCondition,
                    labelBuilder: (value) => (value as Enum).koLabel,
                    onChanged: (value) {
                      setState(() => _dayCondition = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildScheduleRadioSection<SchedulePresetType>(
                    title: '알림 문구 프리셋',
                    values: SchedulePresetType.values,
                    groupValue: _presetType,
                    labelBuilder: (value) => (value as Enum).koLabel,
                    onChanged: (value) {
                      setState(() => _presetType = value);
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('미실행 시 알림 유지'),
                    subtitle: const Text('알림을 확인했어도 직접 완료 처리할 때까지 반복됩니다.'),
                    value: _remindIfNotExecuted,
                    onChanged: (value) {
                      setState(() => _remindIfNotExecuted = value);
                    },
                  ),
                ],
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
              onPressed: _saving
                  ? null
                  : () async {
                      FocusScope.of(context).unfocus(); // 저장 시 키보드를 닫아준다.
                      if (!(_formKey.currentState?.validate() ?? false)) {
                        return; // 검증 실패 시 저장을 중단한다.
                      }
                      if (_useLocation && (_lat == null || _lng == null)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('좌표를 입력하거나 현재 위치를 설정해주세요.')),
                        );
                        return;
                      }

                      final computedMinutes =
                          _endAt.difference(_startAt).inMinutes; // 시작/종료 시각으로 계산된 실제 소요 시간
                      final safeMinutes = computedMinutes > 0
                          ? computedMinutes
                          : (_minutes > 0 ? _minutes : 0); // 혹시 모를 불일치를 대비한 보정
                      if (safeMinutes <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('시작과 종료 시각을 다시 확인해주세요.')), // 최소 1분 이상 필요
                        );
                        return;
                      }

                      _minutes = safeMinutes; // 배터리 계산에 사용하는 분 값도 최신으로 맞춘다.
                      _endAt = _startAt.add(Duration(minutes: safeMinutes)); // 종료 시각을 일관되게 맞춘다.

                      setState(() => _saving = true); // 저장 중임을 표시
                      final now = DateTime.now();
                      final start = _startAt; // 사용자가 선택한 시작 시각을 그대로 저장
                      final end = _endAt; // 종료 시각도 사용자가 고른 값을 사용
                      final change = _calculateBatteryChange(); // 총 배터리 변화(부호 포함)
                      final double rate = _minutes > 0
                          ? change / (_minutes / 60)
                          : 0.0; // 분 단위를 시간으로 환산해 시간당 변화율 산출
                      final eventId = widget.event?.id ??
                          DateTime.now().microsecondsSinceEpoch.toString();

                      // 이벤트 생성 (신규/수정 공용)
                      final e = Event(
                        id: eventId,
                        title: _title,
                        content: _content,
                        startAt: start,
                        endAt: end,
                        type: widget.event?.type ?? EventType.neutral,
                        ratePerHour: rate,
                        priority:
                            widget.event?.priority ?? defaultPriority(EventType.neutral),
                        createdAt: widget.event?.createdAt ?? now,
                        updatedAt: now,
                        iconName: _iconName, // 사용자가 고른 아이콘을 함께 저장
                        colorName: _colorName, // 사용자가 고른 색상도 함께 저장
                      );

                      final scheduleRepo = ref.read(scheduleRepositoryProvider);
                      final geofenceManager = ref.read(geofenceManagerProvider);

                      try {
                        await repo.saveEvent(e); // 이벤트 저장/수정

                        if (_useLocation) {
                          // 위치 기반 알림을 사용한다면 Schedule 모델을 생성해 함께 저장한다.
                          final schedule = Schedule(
                            id: eventId, // 이벤트와 동일한 ID를 사용해 연동을 단순화한다.
                            title: e.title,
                            startAt: start,
                            endAt: end,
                            useLocation: true,
                            placeName:
                                _placeController.text.trim().isEmpty ? null : _placeController.text.trim(),
                            lat: _lat,
                            lng: _lng,
                            radiusMeters: _radius,
                            triggerType: _triggerType,
                            dayCondition: _dayCondition,
                            presetType: _presetType,
                            remindIfNotExecuted: _remindIfNotExecuted,
                            executed: _scheduleExecuted,
                            createdAt: _loadedSchedule?.createdAt ?? _scheduleCreatedAt ?? now,
                            updatedAt: now,
                          );
                          await scheduleRepo.saveSchedule(schedule);
                          await scheduleRepo.addLog('이벤트와 연동된 일정 저장: ${schedule.title}',
                              scheduleId: schedule.id);
                          await geofenceManager.applySchedule(schedule);
                        } else {
                          // 위치 기능을 사용하지 않는다면 기존에 저장된 일정을 정리한다.
                          final existing =
                              _loadedSchedule ?? await scheduleRepo.findById(eventId);
                          if (existing != null) {
                            await scheduleRepo.deleteSchedule(existing.id);
                            await scheduleRepo.addLog('이벤트 연동 일정 삭제: ${existing.title}',
                                scheduleId: existing.id);
                            await geofenceManager.removeSchedule(existing.id);
                          }
                        }

                        if (!mounted) return;
                        Navigator.pop(context); // 이전 화면으로 복귀
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('일정 저장 중 문제가 발생했습니다: $e')),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _saving = false);
                        }
                      }
                    },
              child: Text(_saving
                  ? '저장 중...'
                  : widget.event == null
                      ? '저장'
                      : '수정'),
            )
          ],
        ),
      ),
    );
  }
}
