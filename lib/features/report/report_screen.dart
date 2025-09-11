import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories.dart';

/// 리포트 화면
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final now = DateTime.now();
    final data = repo.simulateDay(now);
    final values = data.values.toList();
    double min = values.reduce((a, b) => a < b ? a : b);
    return Scaffold(
      appBar: AppBar(title: const Text('리포트')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('최저 배터리: ${min.toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            Text('총 분포 데이터: ${values.length}개'),
          ],
        ),
      ),
    );
  }
}
