import 'package:flutter_test/flutter_test.dart';
import 'package:energy_battery/core/compute.dart';
import 'package:energy_battery/data/models.dart';

void main() {
  test('시뮬레이션 기본 시나리오', () {
    final settings = UserSettings();
    final events = [
      Event(
          id: 'w',
          title: '작업',
          startAt: DateTime(2024, 1, 1, 9),
          endAt: DateTime(2024, 1, 1, 15),
          type: EventType.work,
          ratePerHour: -5,
          priority: defaultPriority(EventType.work),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now()),
      Event(
          id: 'r',
          title: '휴식',
          startAt: DateTime(2024, 1, 1, 15),
          endAt: DateTime(2024, 1, 1, 15, 30),
          type: EventType.rest,
          ratePerHour: 3,
          priority: defaultPriority(EventType.rest),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now()),
      Event(
          id: 's',
          title: '수면',
          startAt: DateTime(2024, 1, 1, 23, 30),
          endAt: DateTime(2024, 1, 2, 7, 30),
          type: EventType.sleep,
          ratePerHour: null,
          priority: defaultPriority(EventType.sleep),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now()),
    ];
    final start = DateTime(2024, 1, 1, 9);
    final end = DateTime(2024, 1, 2, 7, 30);
    final sim = simulate(events, settings, start, end);
    expect(sim[DateTime(2024, 1, 1, 15)]!.toStringAsFixed(1), '50.0');
    expect(sim[DateTime(2024, 1, 1, 15, 30)]!.toStringAsFixed(1), '51.5');
    expect(sim[DateTime(2024, 1, 2, 7, 29)]!.toStringAsFixed(1), '99.9');
  });
}
