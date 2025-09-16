import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/repositories.dart';
import 'data/schedule_db.dart';
import 'data/schedule_repository.dart';
import 'features/schedule/providers.dart';
import 'features/schedule/schedule_detail_screen.dart';
import 'features/schedule/schedule_edit_screen.dart';
import 'features/schedule/schedule_home_screen.dart';
import 'features/settings/settings_screen.dart';
import 'services/geofence_manager.dart';
import 'services/holiday_service.dart';
import 'services/notifications.dart';

/// 앱 시작점
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = AppRepository();
  await repo.init();
  final notif = NotificationService();
  await notif.init();
  // 공휴일 판정과 지오펜스 스케줄 저장에 사용할 객체들을 미리 초기화한다.
  final holidayService = HolidayService();
  final scheduleDb = ScheduleDb();
  final scheduleRepo =
      ScheduleRepository(db: scheduleDb, holidayService: holidayService);
  await scheduleRepo.init();
  final geofenceManager = GeofenceManager(
    repository: scheduleRepo,
    notificationService: notif,
  );
  await geofenceManager.init();
  await geofenceManager.syncSchedules(scheduleRepo.currentSchedules);

  runApp(ProviderScope(overrides: [
    repositoryProvider.overrideWithValue(repo),
    notificationProvider.overrideWithValue(notif),
    holidayServiceProvider.overrideWithValue(holidayService),
    scheduleRepositoryProvider.overrideWithValue(scheduleRepo),
    geofenceManagerProvider.overrideWithValue(geofenceManager),
  ], child: const EnergyBatteryApp()));
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const ScheduleHomeScreen(),
      ),
      GoRoute(
        path: '/schedule/new',
        name: 'scheduleNew',
        builder: (context, state) => const ScheduleEditScreen(),
      ),
      GoRoute(
        path: '/schedule/:id',
        name: 'scheduleDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ScheduleDetailScreen(scheduleId: id);
        },
      ),
      GoRoute(
        path: '/schedule/:id/edit',
        name: 'scheduleEdit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ScheduleEditScreen(scheduleId: id);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

final notificationTapProvider = StreamProvider<String>((ref) {
  final notif = ref.watch(notificationProvider);
  return notif.payloadStream;
});

/// 루트 위젯
class EnergyBatteryApp extends ConsumerStatefulWidget {
  const EnergyBatteryApp({super.key});

  @override
  ConsumerState<EnergyBatteryApp> createState() => _EnergyBatteryAppState();
}

class _EnergyBatteryAppState extends ConsumerState<EnergyBatteryApp> {
  @override
  void initState() {
    super.initState();
    // 알림을 탭하면 해당 일정 상세 화면으로 이동하도록 처리한다.
    ref.listen<AsyncValue<String>>(notificationTapProvider, (previous, next) {
      next.whenData((id) {
        ref.read(routerProvider).go('/schedule/$id');
      });
    });
    // 일정 목록이 변경될 때마다 지오펜스 등록 상태를 갱신한다.
    ref.listen(scheduleStreamProvider, (previous, next) {
      next.whenData((list) {
        ref.read(geofenceManagerProvider).syncSchedules(list);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Energy Battery',
      theme: ThemeData(useMaterial3: true),
      routerConfig: router,
    );
  }
}
