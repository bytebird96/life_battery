import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/schedule_repository.dart';
import '../../services/geofence_manager.dart';
import '../../services/holiday_service.dart';
import '../schedule/providers.dart';

/// 설정 및 권한 가이드 화면
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  PermissionStatus? _locationStatus;
  PermissionStatus? _alwaysStatus;
  PermissionStatus? _notificationStatus;
  PermissionStatus? _batteryStatus;
  String _holidaySource = '주말 기준 (기본)';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    setState(() => _loading = true);
    // permission_handler로 각 권한의 현재 상태를 확인한다.
    final location = await Permission.location.status;
    final always = await Permission.locationAlways.status;
    final notification = await Permission.notification.status;
    final battery = Platform.isAndroid
        ? await Permission.ignoreBatteryOptimizations.status
        : null;
    setState(() {
      _locationStatus = location;
      _alwaysStatus = always;
      _notificationStatus = notification;
      _batteryStatus = battery;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(scheduleLogStreamProvider);
    final repo = ref.watch(scheduleRepositoryProvider);
    final manager = ref.watch(geofenceManagerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정 및 가이드'),
        // 설정 화면도 독립적으로 뒤로가기를 제공해 길을 잃지 않도록 한다.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '뒤로가기',
          onPressed: () => context.pop(),
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
                await manager.syncSchedules(repo.currentSchedules);
                if (!mounted) return;
                // 동기화 완료 후 사용자에게 안내 메시지를 띄운다.
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('지오펜스를 다시 등록했습니다.')));
              },
            ),
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
}
