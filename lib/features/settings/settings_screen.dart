import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/units.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/schedule_repository.dart';
import '../../services/geofence_manager.dart';
import '../../services/holiday_service.dart';
import '../../services/notifications.dart';
import '../schedule/providers.dart';

/// 설정 및 권한 가이드 화면
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  PermissionStatus? _locationStatus;
  PermissionStatus? _alwaysStatus;
  PermissionStatus? _notificationStatus;
  PermissionStatus? _batteryStatus;
  String _holidaySource = '주말 기준 (기본)';
  bool _loading = false;
  final _settingsFormKey = GlobalKey<FormState>(); // 배터리 기본 설정 폼 키
  late final TextEditingController _drainController; // 작업(소모) 기본값 입력 필드
  late final TextEditingController _restController; // 휴식(충전) 기본값 입력 필드
  late final TextEditingController _sleepController; // 수면(충전) 기본값 입력 필드

  @override
  void initState() {
    super.initState();
    // 앱 라이프사이클 변화를 감지하기 위해 옵저버로 등록한다.
    WidgetsBinding.instance.addObserver(this);
    final repo = ref.read(repositoryProvider);
    _drainController =
        TextEditingController(text: _formatRate(repo.settings.defaultDrainRate));
    _restController =
        TextEditingController(text: _formatRate(repo.settings.defaultRestRate));
    _sleepController =
        TextEditingController(text: _formatRate(repo.settings.sleepChargeRate));
    _refreshStatuses();
  }

  @override
  void dispose() {
    // 더 이상 라이프사이클 이벤트가 필요 없으므로 옵저버를 해제한다.
    WidgetsBinding.instance.removeObserver(this);
    _drainController.dispose();
    _restController.dispose();
    _sleepController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 전경으로 올라오는 시점에 권한 정보를 재조회한다.
    if (state == AppLifecycleState.resumed) {
      _refreshStatuses();
    }
  }

  Future<void> _refreshStatuses() async {
    // dispose 이후 호출되거나, 이미 로딩 중인 경우를 피한다.
    if (!mounted || _loading) return;

    setState(() => _loading = true);
    // permission_handler로 각 권한의 현재 상태를 확인한다.
    final location = await Permission.location.status;
    final always = await Permission.locationAlways.status;
    final notification = await Permission.notification.status;
    final battery = Platform.isAndroid
        ? await Permission.ignoreBatteryOptimizations.status
        : null;
    // 비동기 처리 중 위젯이 dispose되었을 수 있으므로 다시 한 번 확인한다.
    if (!mounted) return;

    setState(() {
      _locationStatus = location;
      _alwaysStatus = always;
      _notificationStatus = notification;
      _batteryStatus = battery;
      _loading = false;
    });
  }

  /// 설정 화면에서 테스트 알림을 발송하는 헬퍼
  Future<void> _showTestNotification() async {
    // 실제 알림을 담당하는 서비스를 읽어와 즉시 사용한다.
    final notificationService = ref.read(notificationProvider);
    // scheduleId는 추후 식별을 위해 필요하므로 고정 문자열을 부여한다.
    await notificationService.showScheduleReminder(
      scheduleId: 'settings_test_notification',
      title: '테스트 알림',
      body: '테스트 알림',
    );
    if (!mounted) return;
    // 사용자가 버튼을 눌렀을 때 어떤 일이 일어나는지 쉽게 인지하도록 스낵바로 안내한다.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('테스트 알림을 발송했습니다. 잠시 후 알림을 확인해보세요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(scheduleLogStreamProvider);
    final appRepo = ref.watch(repositoryProvider); // 사용자 설정을 읽기 위해 구독
    final scheduleRepo = ref.watch(scheduleRepositoryProvider);
    final manager = ref.watch(geofenceManagerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정 및 가이드'),
        // 설정 화면도 독립적으로 뒤로가기를 제공해 길을 잃지 않도록 한다.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '뒤로가기',
          onPressed: () {
            // 사용자가 딥링크 등으로 들어온 경우를 대비해 pop이 불가하면 홈으로 이동한다.
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshStatuses,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('권한 상태',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildPermissionTile(
              title: '정밀 위치 권한',
              status: _locationStatus,
              onRequest: () => Permission.location.request(),
            ),
            _buildPermissionTile(
              title: Platform.isIOS ? '항상 위치 허용' : '백그라운드 위치 허용',
              status: _alwaysStatus,
              onRequest: () => Permission.locationAlways.request(),
            ),
            _buildPermissionTile(
              title: '알림 권한',
              status: _notificationStatus,
              onRequest: () => Permission.notification.request(),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _showTestNotification,
              icon: const Icon(Icons.notifications_active),
              label: const Text('테스트 알림 보내기'),
            ),
            if (Platform.isAndroid)
              _buildPermissionTile(
                title: '배터리 최적화 예외',
                status: _batteryStatus,
                onRequest: () => Permission.ignoreBatteryOptimizations.request(),
                description: '갤럭시 등에서 지오펜스가 끊기지 않도록 예외 등록을 권장합니다.',
              ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('위치 서비스 켜기'),
              subtitle: const Text('지오펜스가 동작하지 않을 때 사용'),
              trailing: const Icon(Icons.open_in_new),
              // 시스템 위치 설정 화면으로 이동
              onTap: () => Geolocator.openLocationSettings(),
            ),
            ListTile(
              title: const Text('앱 설정 열기'),
              subtitle: const Text('권한을 다시 허용하려면 눌러주세요.'),
              trailing: const Icon(Icons.settings),
              // OS 앱 설정으로 이동하여 사용자가 직접 권한을 변경할 수 있도록 안내
              onTap: () => openAppSettings(),
            ),
            const Divider(height: 32),
            const Text('공휴일 소스',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _holidaySource,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                    value: '주말 기준 (기본)', child: Text('주말 기준 (기본)')),
                DropdownMenuItem(
                    value: 'holidays.json 사용', child: Text('holidays.json 사용')),
              ],
              onChanged: (value) async {
                if (value == null) return;
                setState(() => _holidaySource = value);
                final holidayService = ref.read(holidayServiceProvider);
                // 선택에 따라 공휴일 JSON을 다시 불러오도록 한다.
                await holidayService.load();
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('지오펜스 재동기화'),
              subtitle: const Text('DB와 등록된 지오펜스 상태를 다시 맞춥니다.'),
              trailing: const Icon(Icons.sync),
              onTap: () async {
                await manager.syncSchedules(scheduleRepo.currentSchedules);
                if (!mounted) return;
                // 동기화 완료 후 사용자에게 안내 메시지를 띄운다.
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('지오펜스를 다시 등록했습니다.')));
              },
            ),
            const Divider(height: 32),
            const Text('배터리 기본 설정',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildBatterySettingsSection(appRepo.settings),
            const Divider(height: 32),
            const Text('최근 지오펜스 로그',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            logs.when(
              data: (entries) => entries.isEmpty
                  ? const Text('기록이 없습니다.')
                  : Column(
                      children: entries
                          .map((log) => ListTile(
                                title: Text(log.message),
                                subtitle: Text(log.createdAt.toString()),
                              ))
                          .toList(),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
              error: (err, stack) => Text('로그를 불러오지 못했습니다: $err'),
            ),
            const SizedBox(height: 24),
            if (_loading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required PermissionStatus? status,
    required Future<PermissionStatus> Function() onRequest,
    String? description,
  }) {
    final label = status == null
        ? '확인 중'
        : status.isGranted
            ? '허용됨'
            : status.isPermanentlyDenied
                ? '영구 거부'
                : status.isDenied
                    ? '거부됨'
                    : status.toString();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(title),
        subtitle: description != null ? Text(description) : null,
        trailing: Text(label),
        onTap: () async {
          final result = await onRequest();
          if (!mounted) return;
          await _refreshStatuses();
          if (result.isPermanentlyDenied) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.')),
            );
          }
        },
      ),
    );
  }

  /// 숫자를 사람이 읽기 좋은 문자열로 변환하는 헬퍼
  String _formatRate(double value) {
    // 소수점이 없는 경우 정수만 보여주고, 그렇지 않으면 소수 둘째 자리까지 표현한다.
    return (value % 1 == 0) ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  /// 문자열을 double로 변환하되, 콤마 입력도 허용한다.
  double? _parseRate(String value) {
    final sanitized = value.replaceAll(',', '.').trim();
    if (sanitized.isEmpty) return null;
    return double.tryParse(sanitized);
  }

  /// 분당 변화량 안내 문구를 생성한다.
  String _perMinuteHelper(double? perHour, {required bool isDrain}) {
    if (perHour == null) {
      return '올바른 숫자를 입력하면 분당 변화량을 안내합니다.';
    }
    final perMinute = perHourToPerMinute(perHour).abs();
    final verb = isDrain ? '소모' : '충전';
    return '분당 약 ${perMinute.toStringAsFixed(2)}% $verb';
  }

  /// 입력값 검증: 음수나 비정상적인 숫자가 들어오면 사용자에게 안내한다.
  String? _validateRate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '값을 입력해주세요.';
    }
    final parsed = _parseRate(value);
    if (parsed == null) {
      return '숫자 형태로 입력해주세요.';
    }
    if (parsed < 0) {
      return '0 이상 값을 입력해주세요.';
    }
    if (parsed > 100) {
      return '100%를 넘는 값은 계산이 어렵습니다.';
    }
    return null;
  }

  /// 현재 폼 입력과 저장된 설정을 비교하여 변경사항이 있는지 확인한다.
  bool _hasUnsavedChanges(UserSettings settings) {
    final drain = _parseRate(_drainController.text);
    final rest = _parseRate(_restController.text);
    final sleep = _parseRate(_sleepController.text);
    if (drain == null || rest == null || sleep == null) {
      // 아직 제대로 입력되지 않은 경우도 저장 전 확인이 필요하므로 true 처리
      return true;
    }
    bool diff(double a, double b) => (a - b).abs() > 0.0001;
    return diff(drain, settings.defaultDrainRate) ||
        diff(rest, settings.defaultRestRate) ||
        diff(sleep, settings.sleepChargeRate);
  }

  /// 리포지토리에 저장된 값으로 입력창을 다시 맞춘다.
  void _syncControllersFromRepo(UserSettings settings) {
    _drainController.text = _formatRate(settings.defaultDrainRate);
    _restController.text = _formatRate(settings.defaultRestRate);
    _sleepController.text = _formatRate(settings.sleepChargeRate);
    setState(() {}); // helperText 갱신을 위해 빌드를 요청
  }

  /// 사용자 입력을 저장소에 반영하고 검증 메시지를 보여준다.
  Future<void> _saveRateSettings() async {
    FocusScope.of(context).unfocus(); // 키보드를 숨겨 사용자가 변화를 인지하기 쉽게 한다.
    final form = _settingsFormKey.currentState;
    if (form == null) return;
    if (!form.validate()) {
      // validator가 자동으로 에러 메시지를 표시하지만, 추가로 스낵바를 통해 알림.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입력값을 다시 확인해주세요. 숫자만 입력할 수 있습니다.')),
      );
      return;
    }

    final drain = _parseRate(_drainController.text)!.clamp(0, 100).toDouble();
    final rest = _parseRate(_restController.text)!.clamp(0, 100).toDouble();
    final sleep = _parseRate(_sleepController.text)!.clamp(0, 100).toDouble();

    final repo = ref.read(repositoryProvider);
    await repo.updateDefaultRates(
      defaultDrainRate: drain,
      defaultRestRate: rest,
      sleepChargeRate: sleep,
    );

    if (!mounted) return;
    _syncControllersFromRepo(repo.settings);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('배터리 기본 변화량을 저장했습니다. 이제부터 새 계산에 반영됩니다.')),
    );
  }

  /// 기본값으로 되돌리는 버튼에 연결될 함수
  void _restoreDefaultRates() {
    FocusScope.of(context).unfocus();
    final defaults = UserSettings();
    _drainController.text = _formatRate(defaults.defaultDrainRate);
    _restController.text = _formatRate(defaults.defaultRestRate);
    _sleepController.text = _formatRate(defaults.sleepChargeRate);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('기본값으로 되돌렸습니다. 저장 버튼을 눌러야 적용됩니다.')),
    );
  }

  /// 배터리 기본 설정 섹션 UI
  Widget _buildBatterySettingsSection(UserSettings settings) {
    final hasUnsaved = _hasUnsavedChanges(settings);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _settingsFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '작업 · 휴식 · 수면에 별도 배터리 수치가 없을 때 사용할 기본값을 조정할 수 있습니다.',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _drainController,
                decoration: InputDecoration(
                  labelText: '작업 기본 소모량 (시간당 %)',
                  hintText: '예: 5',
                  suffixText: '%/시간',
                  helperText: _perMinuteHelper(_parseRate(_drainController.text), isDrain: true),
                  border: const OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: false),
                validator: _validateRate,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              const Text(
                '작업(EventType.work) 이벤트에 별도 속도가 없다면 이 값이 사용됩니다.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _restController,
                decoration: InputDecoration(
                  labelText: '휴식 기본 회복량 (시간당 %)',
                  hintText: '예: 3',
                  suffixText: '%/시간',
                  helperText: _perMinuteHelper(_parseRate(_restController.text), isDrain: false),
                  border: const OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: false),
                validator: _validateRate,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              const Text(
                '휴식(EventType.rest) 이벤트에 별도 속도가 없다면 이 값으로 충전량을 계산합니다.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sleepController,
                decoration: InputDecoration(
                  labelText: '수면 기본 회복량 (시간당 %)',
                  hintText: '예: 12',
                  suffixText: '%/시간',
                  helperText:
                      _perMinuteHelper(_parseRate(_sleepController.text), isDrain: false),
                  border: const OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: false),
                validator: _validateRate,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              const Text(
                '수면(EventType.sleep) 이벤트의 기본 충전량을 조절합니다. 밤새 충전량이 너무 크거나 작다면 조절해보세요.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              if (hasUnsaved)
                const Text(
                  '변경 사항이 있습니다. 아래 "설정 저장" 버튼을 눌러야 다른 화면에 반영됩니다.',
                  style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600),
                ),
              if (hasUnsaved) const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _saveRateSettings,
                    icon: const Icon(Icons.save),
                    label: const Text('설정 저장'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _restoreDefaultRates,
                    icon: const Icon(Icons.refresh),
                    label: const Text('기본값 복원'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
