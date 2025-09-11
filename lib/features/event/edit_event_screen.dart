import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../core/compute.dart'; // 우선순위 계산 함수 사용

/// 이벤트 편집 화면
class EditEventScreen extends ConsumerStatefulWidget {
  const EditEventScreen({super.key});

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventState();
}

class _EditEventState extends ConsumerState<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  String title = ''; // 이벤트 제목
  EventType type = EventType.work; // 기본 이벤트 종류
  DateTime start = DateTime.now(); // 시작 시각
  DateTime end = DateTime.now().add(const Duration(hours: 1)); // 종료 시각
  double? rate; // 사용자 지정 시간당 비율

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('이벤트 편집')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: '제목'),
              onChanged: (v) => title = v,
            ),
            DropdownButtonFormField<EventType>(
              value: type,
              items: EventType.values
                  .map((e) => DropdownMenuItem(
                      value: e, child: Text(e.toString())))
                  .toList(),
              onChanged: (v) => setState(() => type = v!),
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: '시간당 비율'),
              keyboardType: TextInputType.number,
              onChanged: (v) => rate = double.tryParse(v),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: () {
                  final e = Event(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      title: title,
                      startAt: start,
                      endAt: end,
                      type: type,
                      ratePerHour: rate,
                      // 선택한 타입의 기본 우선순위 적용
                      priority: defaultPriority(type),
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now());
                  repo.saveEvent(e); // 저장
                  Navigator.pop(context); // 이전 화면으로 돌아가기
                },
                child: const Text('저장'))
          ],
        ),
      ),
    );
  }
}
