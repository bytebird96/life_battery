import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../data/schedule_models.dart';
import '../../data/schedule_repository.dart';
import '../../services/geofence_manager.dart';
import 'providers.dart';

/// 일정 등록/수정 화면
class ScheduleEditScreen extends ConsumerStatefulWidget {
  const ScheduleEditScreen({super.key, this.scheduleId});

  final String? scheduleId;

  @override
  ConsumerState<ScheduleEditScreen> createState() => _ScheduleEditScreenState();
}

class _ScheduleEditScreenState extends ConsumerState<ScheduleEditScreen> {
  final _titleController = TextEditingController();
  final _placeController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  DateTime _startAt = DateTime.now();
  DateTime _endAt = DateTime.now().add(const Duration(hours: 1));
  bool _useLocation = true;
  double? _lat;
  double? _lng;
  double _radius = 150;
  ScheduleTriggerType _triggerType = ScheduleTriggerType.arrive;
  ScheduleDayCondition _dayCondition = ScheduleDayCondition.always;
  SchedulePresetType _presetType = SchedulePresetType.move;
  bool _remindIfNotExecuted = true;
  bool _executed = false;
  DateTime? _createdAt;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.scheduleId != null) {
      _loadExisting(widget.scheduleId!);
    }
  }

  Future<void> _loadExisting(String id) async {
    final repo = ref.read(scheduleRepositoryProvider);
    final schedule = await repo.findById(id);
    if (!mounted || schedule == null) return;
    setState(() {
      // 기존 일정의 정보를 폼 필드에 채운다.
      _titleController.text = schedule.title;
      _placeController.text = schedule.placeName ?? '';
      _startAt = schedule.startAt;
      _endAt = schedule.endAt;
      _useLocation = schedule.useLocation;
      _lat = schedule.lat;
      _lng = schedule.lng;
      _latController.text = schedule.lat?.toStringAsFixed(6) ?? '';
      _lngController.text = schedule.lng?.toStringAsFixed(6) ?? '';
      _radius = schedule.radiusMeters ?? 150;
      _triggerType = schedule.triggerType;
      _dayCondition = schedule.dayCondition;
      _presetType = schedule.presetType;
      _remindIfNotExecuted = schedule.remindIfNotExecuted;
      _executed = schedule.executed;
      _createdAt = schedule.createdAt;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _placeController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.scheduleId == null
        ? null
        : ref.watch(scheduleByIdProvider(widget.scheduleId!));
    final titleText = widget.scheduleId == null ? '일정 등록' : '일정 수정';
    return Scaffold(
      appBar: AppBar(title: Text(titleText)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 제목 입력
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '제목'),
          ),
          const SizedBox(height: 12),
          // 시작/종료 시각 선택
          _buildDateRow(context),
          const SizedBox(height: 12),
          // 위치 사용 여부 스위치
          SwitchListTile(
            title: const Text('위치 사용'),
            subtitle: const Text('지오펜스로 도착/이탈 시 알림'),
            value: _useLocation,
            onChanged: (value) {
              setState(() {
                _useLocation = value;
              });
            },
          ),
          if (_useLocation) ...[
            // 장소명 입력(선택)
            TextField(
              controller: _placeController,
              decoration: const InputDecoration(labelText: '장소명 (선택)'),
            ),
            // 위도/경도 수동 입력
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    decoration: const InputDecoration(labelText: '위도'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) =>
                        _lat = double.tryParse(value.replaceAll(',', '.')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    decoration: const InputDecoration(labelText: '경도'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) =>
                        _lng = double.tryParse(value.replaceAll(',', '.')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 현재 위치 버튼
            FilledButton.icon(
              onPressed: _setCurrentLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('현재 위치로 좌표 설정'),
            ),
            // 반경 조정 슬라이더 (50~300m)
            Slider(
              value: _radius,
              min: 50,
              max: 300,
              divisions: 5,
              label: '${_radius.toStringAsFixed(0)}m',
              onChanged: (value) {
                setState(() {
                  _radius = value;
                });
              },
            ),
            // 현재 좌표가 있을 때 지도 미리보기 표시
            MapPreview(lat: _lat, lng: _lng, radius: _radius),
          ],
          const SizedBox(height: 16),
          // 트리거 유형 라디오 버튼
          _buildRadioSection<ScheduleTriggerType>(
            title: '트리거 유형',
            values: ScheduleTriggerType.values,
            groupValue: _triggerType,
            labelBuilder: (value) => value.koLabel,
            onChanged: (value) {
              setState(() => _triggerType = value);
            },
          ),
          const SizedBox(height: 12),
          // 요일/공휴일 조건 라디오 버튼
          _buildRadioSection<ScheduleDayCondition>(
            title: '요일/공휴일 조건',
            values: ScheduleDayCondition.values,
            groupValue: _dayCondition,
            labelBuilder: (value) => value.koLabel,
            onChanged: (value) {
              setState(() => _dayCondition = value);
            },
          ),
          const SizedBox(height: 12),
          // 프리셋 라디오 버튼
          _buildRadioSection<SchedulePresetType>(
            title: '일정 유형(알림 문구)',
            values: SchedulePresetType.values,
            groupValue: _presetType,
            labelBuilder: (value) => value.koLabel,
            onChanged: (value) {
              setState(() => _presetType = value);
            },
          ),
          // 미실행 조건 스위치
          SwitchListTile(
            title: const Text('미실행 시 알림 유지'),
            subtitle: const Text('실행 완료로 표시하기 전까지 반복 알림'),
            value: _remindIfNotExecuted,
            onChanged: (value) {
              setState(() => _remindIfNotExecuted = value);
            },
          ),
          const SizedBox(height: 16),
          // 저장 버튼
          ElevatedButton.icon(
            onPressed: _loading ? null : () => _save(context, existing),
            icon: const Icon(Icons.save),
            label: Text(_loading ? '저장 중...' : '저장'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    return Row(
      children: [
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('시작 시각'),
            subtitle: Text(dateFormat.format(_startAt)),
            onTap: () => _pickDateTime(isStart: true),
          ),
        ),
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('종료 시각'),
            subtitle: Text(dateFormat.format(_endAt)),
            onTap: () => _pickDateTime(isStart: false),
          ),
        ),
      ],
    );
  }

  Widget _buildRadioSection<T>({
    required String title,
    required List<T> values,
    required T groupValue,
    required String Function(T) labelBuilder,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ...values.map(
          (value) => RadioListTile<T>(
            title: Text(labelBuilder(value)),
            value: value,
            groupValue: groupValue,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final base = isStart ? _startAt : _endAt;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startAt = selected;
        if (_endAt.isBefore(_startAt)) {
          _endAt = _startAt.add(const Duration(hours: 1));
        }
      } else {
        _endAt = selected;
      }
    });
  }

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
        return;
      }
      // 현재 위치를 읽어오는 동안 저장 버튼을 비활성화한다.
      setState(() => _loading = true);
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
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
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save(BuildContext context, Schedule? existing) async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('제목을 입력해주세요.')));
      return;
    }
    if (_useLocation && (_lat == null || _lng == null)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('좌표를 입력하거나 현재 위치를 설정해주세요.')));
      return;
    }
    setState(() => _loading = true);
    final repo = ref.read(scheduleRepositoryProvider);
    final manager = ref.read(geofenceManagerProvider);
    final now = DateTime.now();
    final schedule = Schedule(
      id: existing?.id ?? repo.newId(),
      title: _titleController.text.trim(),
      startAt: _startAt,
      endAt: _endAt,
      useLocation: _useLocation,
      placeName: _placeController.text.isEmpty ? null : _placeController.text,
      lat: _useLocation ? _lat : null,
      lng: _useLocation ? _lng : null,
      radiusMeters: _useLocation ? _radius : null,
      triggerType: _triggerType,
      dayCondition: _dayCondition,
      presetType: _presetType,
      remindIfNotExecuted: _remindIfNotExecuted,
      executed: _executed && widget.scheduleId != null,
      createdAt: existing?.createdAt ?? _createdAt ?? now,
      updatedAt: now,
    );
    // DB에 저장하고 로그/지오펜스를 갱신한다.
    await repo.saveSchedule(schedule);
    await repo.addLog('일정 저장: ${schedule.title}', scheduleId: schedule.id);
    await manager.applySchedule(schedule);
    if (!mounted) return;
    setState(() => _loading = false);
    context.pop();
  }
}

/// 간단한 지도 프리뷰(FlutterMap 기반)
class MapPreview extends StatelessWidget {
  const MapPreview({super.key, required this.lat, required this.lng, required this.radius});

  final double? lat;
  final double? lng;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (lat == null || lng == null) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('좌표가 설정되면 지도가 표시됩니다.'),
      );
    }
    final position = LatLng(lat!, lng!);
    return SizedBox(
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: position,
            initialZoom: 16,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.energy_battery',
            ),
            CircleLayer(
              circles: [
                CircleMarker(
                  point: position,
                  color: Colors.blue.withOpacity(0.2),
                  borderStrokeWidth: 2,
                  borderColor: Colors.blue,
                  useRadiusInMeter: true,
                  radius: radius,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: position,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
