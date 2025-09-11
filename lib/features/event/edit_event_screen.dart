import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';

/// 이벤트 편집 화면
class EditEventScreen extends ConsumerStatefulWidget {
  const EditEventScreen({super.key});

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventState();
}

class _EditEventState extends ConsumerState<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  String title = '';
  EventType type = EventType.work;
  DateTime start = DateTime.now();
  DateTime end = DateTime.now().add(const Duration(hours: 1));
  double? rate;

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
                      priority: defaultPriority(type),
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now());
                  repo.saveEvent(e);
                  Navigator.pop(context);
                },
                child: const Text('저장'))
          ],
        ),
      ),
    );
  }
}
