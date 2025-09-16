import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/schedule_models.dart';
import '../../data/schedule_repository.dart';
import '../../services/geofence_manager.dart';
import 'providers.dart';

/// 홈 화면 - 오늘 일정과 다가오는 일정을 보여주고 권한 요청 및 지오펜스 동기화를 담당
class ScheduleHomeScreen extends ConsumerStatefulWidget {
  const ScheduleHomeScreen({super.key});

  @override
  ConsumerState<ScheduleHomeScreen> createState() => _ScheduleHomeScreenState();
}

class _ScheduleHomeScreenState extends ConsumerState<ScheduleHomeScreen> {
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepare();
    });
  }

  Future<void> _prepare() async {
    if (!mounted) return;
    // 앱 최초 진입 시 필요한 권한을 요청한다.
    await _requestPermissions();
    if (!mounted) return;
    // 권한이 허용되었다면 DB와 지오펜스 등록 상태를 맞춘다.
    await _syncGeofences();
  }

  Future<void> _requestPermissions() async {
    if (_requesting) return;
    _requesting = true;
    try {
      await Permission.location.request();
      if (Platform.isAndroid) {
        await Permission.locationAlways.request();
        await Permission.notification.request();
        await Permission.ignoreBatteryOptimizations.request();
      } else {
        await Permission.locationAlways.request();
      }
    } finally {
      _requesting = false;
    }
  }

  Future<void> _syncGeofences() async {
    final repo = ref.read(scheduleRepositoryProvider);
    final manager = ref.read(geofenceManagerProvider);
    await manager.syncSchedules(repo.currentSchedules);
  }

  @override
  Widget build(BuildContext context) {
    // DB에서 가져온 일정 목록을 스트림으로 구독한다.
    final schedules = ref.watch(scheduleStreamProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 기반 일정'),
        actions: [
          IconButton(
            tooltip: '설정',
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/schedule/new'),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('일정 추가'),
      ),
      body: schedules.when(
        data: (items) => _buildBody(items),
        error: (err, stack) => _buildError(err),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildError(Object err) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text('일정을 불러오는 중 오류가 발생했습니다\n$err',
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _prepare,
            child: const Text('다시 시도'),
          )
        ],
      ),
    );
  }

  Widget _buildBody(List<Schedule> schedules) {
    final now = DateTime.now();
    final todayList = schedules
        .where((s) => _isSameDay(s.startAt, now))
        .toList(growable: false);
    final upcomingList = schedules
        .where((s) => s.startAt.isAfter(now) && !_isSameDay(s.startAt, now))
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async {
        await _syncGeofences();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (todayList.isEmpty)
            _sectionTitle('오늘 일정이 없습니다'),
         if (todayList.isNotEmpty) ...[
            _sectionTitle('오늘 일정'),
            ...todayList.map(_buildTile),
          ],
          const SizedBox(height: 16),
          _sectionTitle('다가오는 일정'),
          if (upcomingList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('등록된 향후 일정이 없습니다. 상단 + 버튼으로 추가해보세요.'),
            ),
          ...upcomingList.map(_buildTile),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTile(Schedule schedule) {
    final timeFormat = DateFormat('MM/dd HH:mm');
    final locationText = schedule.useLocation
        ? '${schedule.placeName ?? '좌표'} · 반경 ${(schedule.radiusMeters ?? 150).toStringAsFixed(0)}m'
        : '위치 사용 안 함';
    final statusIcon = schedule.executed
        ? const Icon(Icons.check_circle, color: Colors.green)
        : const Icon(Icons.notifications_active, color: Colors.orange);
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(schedule.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${timeFormat.format(schedule.startAt)} ~ ${timeFormat.format(schedule.endAt)}'),
            Text(locationText),
            Text('트리거: ${schedule.triggerType.koLabel}, 조건: ${schedule.dayCondition.koLabel}'),
          ],
        ),
        trailing: statusIcon,
       onTap: () => context.go('/schedule/${schedule.id}'),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
