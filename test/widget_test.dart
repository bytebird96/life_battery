import 'package:flutter_test/flutter_test.dart';
import 'package:energy_battery/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:energy_battery/data/repositories.dart';

/// 홈 화면 렌더 및 FAB 동작 테스트
void main() {
  testWidgets('홈 렌더 및 FAB', (tester) async {
    final repo = AppRepository();
    await repo.init();
    await tester.pumpWidget(ProviderScope(overrides: [
      repositoryProvider.overrideWithValue(repo)
    ], child: const EnergyBatteryApp()));
    expect(find.text('에너지 배터리'), findsOneWidget);
    // init()에서 더미 이벤트 3개가 생성된 상태 확인
    expect(repo.events.length, 3);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    // 빠른 이벤트 생성으로 총 4개가 되어야 함
    expect(repo.events.length, 4);
  });
}
