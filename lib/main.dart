import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/repositories.dart';
import 'features/home/home_screen.dart';
import 'features/event/edit_event_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/report/report_screen.dart';
import 'services/notifications.dart';

/// 앱 시작점
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = AppRepository();
  await repo.init();
  final notif = NotificationService();
  await notif.init();

  runApp(ProviderScope(overrides: [
    repositoryProvider.overrideWithValue(repo),
    notificationProvider.overrideWithValue(notif),
  ], child: const EnergyBatteryApp()));
}

/// 루트 위젯
class EnergyBatteryApp extends StatelessWidget {
  const EnergyBatteryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Energy Battery',
      theme: ThemeData(useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/event': (_) => const EditEventScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/report': (_) => const ReportScreen(),
      },
    );
  }
}
