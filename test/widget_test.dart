import 'package:flutter_test/flutter_test.dart';
import 'package:energy_battery/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:energy_battery/data/repositories.dart';

/// 홈 화면 렌더 및 수면 타이머 테스트
void main() {
  testWidgets('수면 시작 후 배터리 증가', (tester) async {
    final repo = AppRepository();
    await repo.init();
    await tester.pumpWidget(ProviderScope(overrides: [
      repositoryProvider.overrideWith((ref) => repo)
    ], child: const EnergyBatteryApp()));

    // 초기 배터리 80% 확인
    expect(find.text('80.0%'), findsOneWidget);

    // 첫 번째 시작 버튼(수면)을 탭
    await tester.tap(find.widgetWithText(ElevatedButton, '시작').first);
    await tester.pump();

    // 1시간이 경과하도록 펌프 -> 10% 충전되어 90%가 되어야 함
    await tester.pump(const Duration(hours: 1));
    expect(find.text('90.0%'), findsOneWidget);
  });
}
