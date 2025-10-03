import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/compute.dart';
import 'data/models.dart';
import 'data/repositories.dart';
import 'data/schedule_db.dart';
import 'data/schedule_repository.dart';
import 'features/event/edit_event_screen.dart';
import 'features/schedule/providers.dart';
import 'features/schedule/schedule_detail_screen.dart';
import 'features/home/life_battery_home_screen.dart';
import 'features/schedule/schedule_home_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/task/task_screen.dart';
import 'features/home/event_list_screen.dart';
import 'features/report/report_screen.dart';
import 'services/geofence_manager.dart';
import 'services/holiday_service.dart';
import 'services/notifications.dart';
import 'data/schedule_models.dart'; // Schedule 타입 참조 시 필요

/// 앱 시작점
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ▼ intl 패키지에서 제공하는 날짜/시간 포맷 정보를 로드한다.
  //    한국어(ko_KR) 로케일 데이터를 사전에 초기화해야 DateFormat 사용 시 오류가 발생하지 않는다.
  await initializeDateFormatting('ko_KR', null);
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
  // Schedule.presetType에 따라 어떤 Event를 자동 실행해야 하는지 매핑한다.
  geofenceManager.eventIdResolver = (schedule) {
    switch (schedule.presetType) {
      case SchedulePresetType.commuteIn:
      case SchedulePresetType.commuteOut:
        // 기본 제공 출근 이벤트와 연결한다. (퇴근도 동일 이벤트를 재사용)
        return AppRepository.commuteEventId;
      case SchedulePresetType.move:
      case SchedulePresetType.workout:
        // 아직은 대응되는 기본 Event가 없으므로 null을 반환해 자동 실행을 생략한다.
        return null;
    }
  };

  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWith((ref) => repo),
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
        builder: (context, state) {
          // ▼ 초보자도 이해하기 쉽게: 앱을 켰을 때 가장 먼저 보이는 화면을 지정한다.
          //    기존에는 일정 홈(ScheduleHomeScreen)으로 이동했지만,
          //    요청에 따라 라이프 배터리 홈(LifeBatteryHomeScreen)을 기본 화면으로 교체했다.
          return const LifeBatteryHomeScreen();
        },
      ),
      GoRoute(
        path: '/tasks',
        name: 'tasks',
        builder: (context, state) {
          // ▼ 하단 탭의 시계 아이콘을 눌렀을 때 보여줄 작업 화면을 연결한다.
          //    기존 Navigator.pushNamed('/tasks') 호출과 동일한 목적이지만,
          //    GoRouter를 사용해 라우팅을 일관되게 관리한다.
          return const TaskScreen();
        },
      ),
      GoRoute(
        path: '/report',
        name: 'report',
        builder: (context, state) {
          // ▼ 우측 하단 파이차트 아이콘을 눌렀을 때 사용할 배터리 리포트 화면.
          //    그래프와 요약 통계를 함께 제공해 배터리 흐름을 쉽게 이해할 수 있도록 구성했다.
          return const ReportScreen();
        },
      ),
      GoRoute(
        path: '/events',
        name: 'events',
        builder: (context, state) {
          // ▼ 홈 화면의 "See All" 텍스트를 누르면 전체 일정 목록을 확인하도록 연결한다.
          //    추후 다른 화면에서도 같은 경로를 재사용할 수 있도록 라우트로 등록한다.
          return const EventListScreen();
        },
      ),
      GoRoute(
        path: '/schedule',
        name: 'scheduleHome',
        builder: (context, state) {
          // ▼ 라이프 배터리 홈에서 일정 전용 화면으로 이동하고 싶을 때 사용할 라우트.
          //    '/schedule' 경로로 이동하면 이전에 사용하던 일정 홈 UI를 그대로 확인할 수 있다.
          return const ScheduleHomeScreen();
        },
      ),
      GoRoute(
        path: '/schedule/new',
        name: 'scheduleNew',
        builder: (context, state) {
          // ▼ 위치 기반 옵션이 포함된 새 일정 작성 화면을 `EditEventScreen`으로 통합했다.
          //    이벤트와 지오펜스 정보를 한 번에 입력할 수 있도록 바로 해당 화면을 연다.
          return const EditEventScreen();
        },
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
          // ▼ 기존 일정 수정 시에도 동일한 편집 화면을 사용한다.
          //    Consumer를 이용해 Riverpod 상태를 구독하고, 저장된 이벤트/일정 정보를 불러온다.
          return Consumer(
            builder: (context, ref, _) {
              final repo = ref.watch(repositoryProvider);
              final asyncSchedules = ref.watch(scheduleStreamProvider);

              // 1) 우선 이벤트 목록에서 동일 ID를 찾는다. (이전 통합 저장 구조와 호환)
              final existingEvent = repo.findEventById(id);
              if (existingEvent != null) {
                return EditEventScreen(event: existingEvent);
              }

              // 2) 이벤트가 없을 경우, 기존 위치 기반 일정만 존재할 수 있으므로 스트림에서 찾아본다.
              return asyncSchedules.when(
                data: (items) {
                  Schedule? schedule;
                  for (final item in items) {
                    if (item.id == id) {
                      schedule = item;
                      break;
                    }
                  }

                  if (schedule != null) {
                    // ▼ 일정 정보만 있을 때도 사용자가 당황하지 않도록, 임시 Event 데이터를 만들어 전달한다.
                    final fallbackEvent = Event(
                      id: schedule.id,
                      title: schedule.title,
                      content: schedule.placeName, // 장소명을 메모 용도로 채워준다.
                      startAt: schedule.startAt,
                      endAt: schedule.endAt,
                      type: EventType.neutral,
                      ratePerHour: 0,
                      priority: defaultPriority(EventType.neutral),
                      createdAt: schedule.createdAt,
                      updatedAt: schedule.updatedAt,
                      iconName:
                          repo.eventIcons[schedule.id] ?? defaultEventIconName,
                      colorName:
                          repo.eventColors[schedule.id] ?? defaultEventColorName,
                    );
                    return EditEventScreen(event: fallbackEvent);
                  }

                  // 3) 어떤 정보도 없으면 안내 문구를 보여준다.
                  return const Scaffold(
                    body: Center(
                      child: Text('해당 일정을 불러오지 못했습니다. 홈으로 돌아가 다시 시도해주세요.'),
                    ),
                  );
                },
                loading: () => const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stack) => Scaffold(
                  body: Center(
                    child: Text('일정을 불러오는 중 오류가 발생했습니다: $error'),
                  ),
                ),
              );
            },
          );
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
