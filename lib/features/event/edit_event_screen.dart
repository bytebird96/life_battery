import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../core/compute.dart';

/// 일정 등록 화면
/// - 제목, 내용, 소요 시간, 배터리 변화를 입력받아 이벤트를 저장
class EditEventScreen extends ConsumerStatefulWidget {
  const EditEventScreen({super.key});

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventState();
}

class _EditEventState extends ConsumerState<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();

  String _title = ''; // 일정 제목 저장 변수
  String _content = ''; // 일정 설명 저장 변수
  int _minutes = 0; // 소요 시간(분)
  double _battery = 0.0; // 전체 배터리 변화 퍼센트 (초기값 0.0)

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider); // 리포지토리 접근
    return Scaffold(
      appBar: AppBar(title: const Text('일정 등록')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 제목 입력 필드
            TextFormField(
              decoration: const InputDecoration(labelText: '제목'),
              onChanged: (v) => _title = v,
            ),
            // 내용(상세 설명) 입력 필드
            TextFormField(
              decoration: const InputDecoration(labelText: '내용'),
              onChanged: (v) => _content = v,
            ),
            // 소요 시간 입력 필드 (분 단위)
            TextFormField(
              decoration: const InputDecoration(labelText: '소요 시간(분)'),
              keyboardType: TextInputType.number,
              onChanged: (v) => _minutes = int.tryParse(v) ?? 0,
            ),
            // 배터리 변화 입력 필드 (양수=충전, 음수=소모)
            TextFormField(
              decoration: const InputDecoration(labelText: '배터리 변화(%)'),
              keyboardType: TextInputType.number,
              onChanged: (v) =>
                  _battery = double.tryParse(v) ?? 0.0, // 숫자 변환 실패 시 0.0으로 처리
            ),
            const SizedBox(height: 20),
            // 저장 버튼
            ElevatedButton(
              onPressed: () {
                final start = DateTime.now(); // 시작 시각은 현재로 설정
                final end = start.add(Duration(minutes: _minutes)); // 종료 시각 계산
                final double rate = _minutes > 0
                    ? _battery / (_minutes / 60)
                    : 0.0; // 0.0을 사용해 double 타입 유지
                // 이벤트 생성
                final e = Event(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  title: _title,
                  content: _content,
                  startAt: start,
                  endAt: end,
                  type: EventType.neutral, // 기본 타입은 중립
                  ratePerHour: rate,
                  priority: defaultPriority(EventType.neutral),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                repo.saveEvent(e); // 이벤트 저장
                Navigator.pop(context); // 이전 화면으로 복귀
              },
              child: const Text('저장'),
            )
          ],
        ),
      ),
    );
  }
}
