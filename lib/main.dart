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
import 'data/schedule_models.dart'; // Schedule 타입 참조 시 필요

/// 앱 시작점
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = AppRepository();
  await repo.init();

  final notif = NotificationService();
  await notif.init();

  // 공휴일/DB/레포 초기화
  final holidayService = HolidayService();
  final scheduleDb = ScheduleDb();
  final scheduleRepo =
  ScheduleRepository(db: scheduleDb, holidayService: holidayService);
  await scheduleRepo.init();

  // 지오펜스 매니저는 생성만 하고, 시작/동기화는 runApp 이후로 지연
  final geofenceManager = GeofenceManager(
    repository: scheduleRepo,
    notificationService: notif,
  );

  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        notificationProvider.overrideWithValue(notif),
        holidayServiceProvider.overrideWithValue(holidayService),
        scheduleRepositoryProvider.overrideWithValue(scheduleRepo),
        geofenceManagerProvider.overrideWithValue(geofenceManager),
      ],
      child: const EnergyBatteryApp(),
    ),
  );
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
  late final ProviderSubscription<AsyncValue<String>> _notifSub;
  late final ProviderSubscription<AsyncValue<List<Schedule>>> _schedSub;

  @override
  void initState() {
    super.initState();

    // 첫 프레임 이후에 지오펜스 시작/동기화(무한 로딩 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final geo = ref.read(geofenceManagerProvider);
      try {
        await geo.init();
        final schedules = ref.read(scheduleRepositoryProvider).currentSchedules;
        await geo.syncSchedules(schedules);
      } catch (e) {
        debugPrint('지오펜스 지연 초기화 실패: $e');
      }
    });

    // A) 알림 탭 → 상세로 이동
    _notifSub = ref.listenManual<AsyncValue<String>>(
      notificationTapProvider,
          (prev, next) {
        next.whenData((id) {
          ref.read(routerProvider).go('/schedule/$id');
        });
      },
    );
    // 현재 값 즉시 처리(있다면)
    ref.read(notificationTapProvider).whenData((id) {
      ref.read(routerProvider).go('/schedule/$id');
    });

    // B) 일정 변경 → 지오펜스 동기화
    _schedSub = ref.listenManual<AsyncValue<List<Schedule>>>(
      scheduleStreamProvider,
          (prev, next) {
        next.whenData((list) {
          ref.read(geofenceManagerProvider).syncSchedules(list);
        });
      },
    );
    // 현재 값 즉시 처리(있다면)
    ref.read(scheduleStreamProvider).whenData((list) {
      ref.read(geofenceManagerProvider).syncSchedules(list);
    });
  }

  @override
  void dispose() {
    _notifSub.close();
    _schedSub.close();
    super.dispose();
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
