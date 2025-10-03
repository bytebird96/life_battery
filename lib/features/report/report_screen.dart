import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/compute.dart'; // 이벤트 타입별 기본 배터리 증감율 계산을 재사용
import '../../core/time.dart'; // 하루 시작 시각을 구해 그래프 범위를 정리
import '../../data/models.dart'; // Event, UserSettings 타입 참조
import '../../data/repositories.dart'; // 저장된 일정/설정 데이터 접근
import '../event/event_colors.dart'; // 일정 색상을 그대로 재활용해 목록에 색감을 부여

/// 배터리 리포트 화면
///
/// - 아이폰의 "배터리" > "모든 배터리 사용량 보기" 화면을 참고해 섹션을 구성했다.
/// - 상단에는 지난 24시간과 지난 10일을 손쉽게 전환할 수 있는 토글을 배치했다.
/// - 그래프와 요약 카드를 통해 초보자도 현재 데이터를 시각적으로 이해할 수 있도록 돕는다.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

/// 토글 버튼에서 사용할 기간 옵션
enum _ReportRange { day, tenDays }

class _ReportScreenState extends ConsumerState<ReportScreen> {
  _ReportRange _range = _ReportRange.day; // 기본값은 "지난 24시간"

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider); // 저장소에서 일정/설정 정보를 읽어온다.
    final now = DateTime.now();

    // 하루 시작과 끝을 계산해 리포트 범위를 명확히 맞춘다.
    final dayStart = todayStart(now, repo.settings.dayStart);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // 시뮬레이션을 통해 1분 단위 배터리 변화 데이터를 확보한다.
    final timeline = repo.simulateDay(now);
    final sortedTimeline = timeline.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final values = sortedTimeline.map((e) => e.value).toList();

    // 하루 동안의 일정 데이터를 불러와 배터리 증감량을 계산한다.
    final events = repo.eventsInRange(dayStart, dayEnd);
    final usageSummary = _buildUsageSummary(events, repo.settings, dayStart, dayEnd);

    // 지난 10일 통계는 토글 전환 시 즉시 보여줄 수 있도록 미리 계산한다.
    final tenDayStats = _buildTenDayStats(repo, now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('배터리 리포트'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRangeSelector(),
              const SizedBox(height: 24),
              if (_range == _ReportRange.day)
                _DayReportView(
                  values: values,
                  timeline: sortedTimeline,
                  usage: usageSummary,
                )
              else
                _TenDayReportView(stats: tenDayStats),
            ],
          ),
        ),
      ),
    );
  }

  /// 기간 토글 버튼을 구성한다. (지난 24시간 ↔ 지난 10일)
  Widget _buildRangeSelector() {
    return SegmentedButton<_ReportRange>(
      // SegmentedButton은 머티리얼 3에서 제공하는 토글 UI로, 아이폰의 세그먼트와 유사하다.
      segments: const [
        ButtonSegment(
          value: _ReportRange.day,
          icon: Icon(Icons.calendar_view_day_outlined),
          label: Text('지난 24시간'),
        ),
        ButtonSegment(
          value: _ReportRange.tenDays,
          icon: Icon(Icons.calendar_month_outlined),
          label: Text('지난 10일'),
        ),
      ],
      selected: {_range},
      onSelectionChanged: (set) {
        // 사용자가 버튼을 누르면 선택된 값을 꺼내 상태를 갱신한다.
        setState(() => _range = set.first);
      },
    );
  }

  /// 일정 목록을 바탕으로 배터리 사용/충전량을 계산한다.
  _UsageSummary _buildUsageSummary(
    List<Event> events,
    UserSettings settings,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final aggregated = <String, _AggregatedUsage>{};

    for (final event in events) {
      // 각 이벤트가 리포트 범위와 겹치는지 확인한다.
      final start = event.startAt.isBefore(rangeStart) ? rangeStart : event.startAt;
      final end = event.endAt.isAfter(rangeEnd) ? rangeEnd : event.endAt;
      final minutes = end.difference(start).inMinutes;
      if (minutes <= 0) continue; // 겹치는 구간이 없으면 건너뛴다.

      // 이벤트에 직접 설정한 ratePerHour가 없다면 타입별 기본값을 사용한다.
      final ratePerHour = event.ratePerHour ?? defaultRate(event.type, settings);
      final delta = ratePerHour * (minutes / 60.0); // 시간당 변화량을 실제 지속 시간에 맞게 환산

      final key = event.title;
      final bucket = aggregated.putIfAbsent(
        key,
        () => _AggregatedUsage(
          title: event.title,
          color: colorFromName(event.colorName),
          type: event.type,
        ),
      );
      if (delta < 0) {
        bucket.drain += -delta; // 마이너스 값은 소모로 합산
      } else {
        bucket.charge += delta; // 플러스 값은 충전으로 합산
      }
    }

    final drains = <_UsageRow>[];
    final charges = <_UsageRow>[];
    for (final bucket in aggregated.values) {
      if (bucket.drain > 0) {
        drains.add(
          _UsageRow(
            title: bucket.title,
            value: bucket.drain,
            color: bucket.color,
            type: bucket.type,
          ),
        );
      }
      if (bucket.charge > 0) {
        charges.add(
          _UsageRow(
            title: bucket.title,
            value: bucket.charge,
            color: bucket.color,
            type: bucket.type,
          ),
        );
      }
    }

    drains.sort((a, b) => b.value.compareTo(a.value));
    charges.sort((a, b) => b.value.compareTo(a.value));

    final totalDrain = drains.fold<double>(0, (sum, e) => sum + e.value);
    final totalCharge = charges.fold<double>(0, (sum, e) => sum + e.value);

    return _UsageSummary(
      drains: drains,
      charges: charges,
      totalDrain: totalDrain,
      totalCharge: totalCharge,
    );
  }

  /// 10일 간 배터리 흐름을 정리한다.
  List<_DailyStat> _buildTenDayStats(AppRepository repo, DateTime now) {
    final items = <_DailyStat>[];
    for (int i = 0; i < 10; i++) {
      final targetDay = now.subtract(Duration(days: i));
      final timeline = repo.simulateDay(targetDay);
      if (timeline.isEmpty) {
        continue; // 데이터가 없으면 건너뛴다.
      }
      final sorted = timeline.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final values = sorted.map((e) => e.value).toList();
      final minValue = values.reduce(math.min);
      final maxValue = values.reduce(math.max);
      final startValue = values.first;
      final endValue = values.last;
      items.add(
        _DailyStat(
          date: todayStart(targetDay, repo.settings.dayStart),
          min: minValue,
          max: maxValue,
          delta: endValue - startValue,
        ),
      );
    }
    return items.reversed.toList(); // 오래된 날짜가 위로 오도록 뒤집는다.
  }
}

/// "지난 24시간" 전용 뷰
class _DayReportView extends StatelessWidget {
  final List<double> values;
  final List<MapEntry<DateTime, double>> timeline;
  final _UsageSummary usage;

  const _DayReportView({
    required this.values,
    required this.timeline,
    required this.usage,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      // 기록이 없을 때는 간단한 안내 문구만 표시한다.
      return _EmptySection(
        icon: Icons.battery_alert,
        message: '표시할 배터리 기록이 없습니다.',
      );
    }

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final startValue = values.first;
    final endValue = values.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BatteryChartCard(
          minValue: minValue,
          maxValue: maxValue,
          startValue: startValue,
          endValue: endValue,
          timeline: timeline,
        ),
        const SizedBox(height: 24),
        _UsageSection(
          title: '배터리 사용량 (소모)',
          description: '어떤 일정이 배터리를 가장 많이 소비했는지 확인할 수 있습니다.',
          items: usage.drains,
          total: usage.totalDrain,
          emptyMessage: '배터리를 소비한 일정이 없습니다.',
          accentColor: const Color(0xFF2D9CDB),
        ),
        const SizedBox(height: 24),
        _UsageSection(
          title: '배터리 충전 (회복)',
          description: '휴식 또는 수면으로 인해 회복된 배터리 양을 확인하세요.',
          items: usage.charges,
          total: usage.totalCharge,
          emptyMessage: '배터리를 충전한 일정이 없습니다.',
          accentColor: const Color(0xFF27AE60),
        ),
      ],
    );
  }
}

/// 지난 10일 간의 흐름을 보여주는 뷰
class _TenDayReportView extends StatelessWidget {
  final List<_DailyStat> stats;

  const _TenDayReportView({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return _EmptySection(
        icon: Icons.calendar_today_outlined,
        message: '지난 10일 동안의 데이터가 없습니다.',
      );
    }

    final df = DateFormat('M월 d일 (E)', 'ko_KR');
    final maxRange = stats
        .map((e) => e.max)
        .fold<double>(0, (prev, value) => math.max(prev, value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '10일간 배터리 추이',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '각 날짜별 최고/최저 배터리와 하루 동안의 증가량을 요약했습니다.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        ...stats.map((stat) {
          final increaseColor = stat.delta >= 0
              ? const Color(0xFF27AE60)
              : const Color(0xFFEB5757);
          final increaseText = stat.delta >= 0 ? '증가' : '감소';
          final percentRange = maxRange == 0 ? 0 : stat.max / maxRange;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(df.format(stat.date)),
                    Text(
                      '${stat.delta >= 0 ? '+' : ''}${stat.delta.toStringAsFixed(1)}% $increaseText',
                      style: TextStyle(
                        color: increaseColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: percentRange.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF2D9CDB),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey[600]),
                    Text('최저 ${stat.min.toStringAsFixed(1)}%'),
                    const SizedBox(width: 12),
                    Icon(Icons.arrow_drop_up, size: 18, color: Colors.grey[600]),
                    Text('최고 ${stat.max.toStringAsFixed(1)}%'),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// 그래프와 기본 통계를 묶어 보여주는 카드
class _BatteryChartCard extends StatelessWidget {
  final double minValue;
  final double maxValue;
  final double startValue;
  final double endValue;
  final List<MapEntry<DateTime, double>> timeline;

  const _BatteryChartCard({
    required this.minValue,
    required this.maxValue,
    required this.startValue,
    required this.endValue,
    required this.timeline,
  });

  @override
  Widget build(BuildContext context) {
    final sampled = _downsample(timeline.map((e) => e.value).toList(), 120);
    return Card(
      elevation: 0,
      color: const Color(0xFFF7F8FC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '배터리 레벨',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '최저 ${minValue.toStringAsFixed(1)}% · 최고 ${maxValue.toStringAsFixed(1)}%',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: CustomPaint(
                painter: _BatteryTrendPainter(sampled),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _SummaryChip(
                  icon: Icons.play_arrow,
                  label: '시작',
                  value: '${startValue.toStringAsFixed(1)}%'
                      ' → ${endValue.toStringAsFixed(1)}%',
                ),
                _SummaryChip(
                  icon: Icons.arrow_downward,
                  label: '최저',
                  value: '${minValue.toStringAsFixed(1)}%',
                ),
                _SummaryChip(
                  icon: Icons.arrow_upward,
                  label: '최고',
                  value: '${maxValue.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 데이터가 너무 많을 경우 일정 개수로 줄여 그래프 렌더링을 가볍게 만든다.
  List<double> _downsample(List<double> source, int maxSamples) {
    if (source.length <= maxSamples || source.length < 2) {
      return source;
    }
    final step = (source.length - 1) / (maxSamples - 1);
    final result = <double>[];
    for (int i = 0; i < maxSamples; i++) {
      final index = (i * step).round();
      result.add(source[index]);
    }
    return result;
  }
}

/// 배터리 변화를 선 그래프로 그려주는 페인터
class _BatteryTrendPainter extends CustomPainter {
  final List<double> values;

  _BatteryTrendPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = (maxValue - minValue).abs() < 0.01 ? 1 : (maxValue - minValue);

    // 배경 그리드 라인 (25%, 50%, 75%)
    final gridPaint = Paint()
      ..color = const Color(0xFFE0E3F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final dy = size.height * (i / 4);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    final path = Path();
    final dx = values.length == 1 ? size.width : size.width / (values.length - 1);
    for (int i = 0; i < values.length; i++) {
      final normalized = (values[i] - minValue) / range;
      final dy = size.height - normalized * size.height;
      final dxPos = dx * i;
      if (i == 0) {
        path.moveTo(dxPos, dy);
      } else {
        path.lineTo(dxPos, dy);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF6BD5A6), Color(0x336BD5A6)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = const Color(0xFF2D9CDB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _BatteryTrendPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

/// 카드 하단에 출력하는 짧은 요약 배지
class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2D9CDB)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }
}

/// 일정별 사용/충전량을 보여주는 섹션
class _UsageSection extends StatelessWidget {
  final String title;
  final String description;
  final List<_UsageRow> items;
  final double total;
  final String emptyMessage;
  final Color accentColor;

  const _UsageSection({
    required this.title,
    required this.description,
    required this.items,
    required this.total,
    required this.emptyMessage,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style:
              Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          _EmptySection(icon: Icons.info_outline, message: emptyMessage)
        else ...[
          _UsageTotalBanner(total: total, accentColor: accentColor),
          const SizedBox(height: 16),
          ..._buildTiles(context),
        ],
      ],
    );
  }

  List<Widget> _buildTiles(BuildContext context) {
    final maxValue = items.fold<double>(
      0,
      (max, e) => math.max(max, e.value),
    );
    return items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _UsageTile(
              item: item,
              maxValue: maxValue == 0 ? 1 : maxValue,
            ),
          ),
        )
        .toList();
  }
}

/// 섹션의 총 사용량을 알려주는 배너
class _UsageTotalBanner extends StatelessWidget {
  final double total;
  final Color accentColor;

  const _UsageTotalBanner({
    required this.total,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, color: accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '총합 ${total.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('아래 리스트는 전체 합 대비 비율을 막대로 보여줍니다.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 일정 하나의 사용량을 보여주는 항목
class _UsageTile extends StatelessWidget {
  final _UsageRow item;
  final double maxValue;

  const _UsageTile({
    required this.item,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final percentOfMax = (item.value / maxValue).clamp(0.0, 1.0);
    final typeLabel = _typeLabel(item.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                '${item.value.toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentOfMax,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(item.color.withOpacity(0.85)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            typeLabel,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// 이벤트 타입을 초보자도 이해하기 쉬운 문장으로 변환한다.
  String _typeLabel(EventType type) {
    switch (type) {
      case EventType.work:
        return '작업 중 배터리 변동';
      case EventType.rest:
        return '휴식 중 배터리 변동';
      case EventType.sleep:
        return '수면 중 배터리 변동';
      case EventType.neutral:
        return '중립 활동 배터리 변동';
    }
  }
}

/// 데이터가 없을 때 보여줄 공통 위젯
class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptySection({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}

/// 사용/충전량 합산 결과를 담는 모델
class _UsageSummary {
  final List<_UsageRow> drains;
  final List<_UsageRow> charges;
  final double totalDrain;
  final double totalCharge;

  const _UsageSummary({
    required this.drains,
    required this.charges,
    required this.totalDrain,
    required this.totalCharge,
  });
}

/// 동일 제목의 일정을 합산할 때 임시로 사용하는 버킷
class _AggregatedUsage {
  final String title;
  final Color color;
  final EventType type;
  double drain;
  double charge;

  _AggregatedUsage({
    required this.title,
    required this.color,
    required this.type,
  })  : drain = 0,
        charge = 0;
}

/// UI에 직접 그릴 데이터 모델
class _UsageRow {
  final String title;
  final double value;
  final Color color;
  final EventType type;

  const _UsageRow({
    required this.title,
    required this.value,
    required this.color,
    required this.type,
  });
}

/// 하루 단위 요약에 사용되는 데이터 모델
class _DailyStat {
  final DateTime date;
  final double min;
  final double max;
  final double delta;

  const _DailyStat({
    required this.date,
    required this.min,
    required this.max,
    required this.delta,
  });
}
