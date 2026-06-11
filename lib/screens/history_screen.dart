import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/food_entry.dart';
import '../providers/diary_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/settings_provider.dart';
import '../repositories/food_log_repository.dart';
import '../utils/date_helpers.dart';
import '../widgets/app_header.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _weekOffset = 0; // 0 = bu hafta, -1 = geçen hafta
  bool _loading = true;

  Map<String, double> _totals = {}; // seçili hafta
  double _prevWeekAvg = 0;

  static const _dayLabels = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _weekStart {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: 7 * _weekOffset));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = context.read<FoodLogRepository>();
    final start = _weekStart;
    final end = start.add(const Duration(days: 6));
    final prevStart = start.subtract(const Duration(days: 7));
    final prevEnd = start.subtract(const Duration(days: 1));

    final entries = await repo.entriesBetween(
        DateHelpers.keyOf(start), DateHelpers.keyOf(end));
    final prevEntries = await repo.entriesBetween(
        DateHelpers.keyOf(prevStart), DateHelpers.keyOf(prevEnd));

    final totals = <String, double>{};
    for (final FoodEntry e in entries) {
      totals[e.date] = (totals[e.date] ?? 0) + e.calories;
    }
    final prevTotals = <String, double>{};
    for (final e in prevEntries) {
      prevTotals[e.date] = (prevTotals[e.date] ?? 0) + e.calories;
    }

    if (mounted) {
      setState(() {
        _totals = totals;
        _prevWeekAvg = _avg(prevTotals.values);
        _loading = false;
      });
    }
  }

  double _avg(Iterable<double> values) {
    final list = values.where((v) => v > 0).toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  List<double> get _weekValues => List.generate(7, (i) {
        final key = DateHelpers.keyOf(_weekStart.add(Duration(days: i)));
        return _totals[key] ?? 0;
      });

  @override
  Widget build(BuildContext context) {
    final goal = context.watch<SettingsProvider>().calorieGoal;
    final values = _weekValues;
    final avg = _avg(values);
    final loggedDays = values.where((v) => v > 0).length;
    final daysWithinGoal =
        values.where((v) => v > 0 && v <= goal).length;
    final completion =
        loggedDays == 0 ? 0 : (daysWithinGoal / loggedDays * 100).round();
    final diff = avg - _prevWeekAvg;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const AppHeader(),
                  _weekSelector(),
                  const SizedBox(height: 14),
                  _calorieChartCard(goal),
                  const SizedBox(height: 14),
                  _avgCard(avg, diff),
                  const SizedBox(height: 14),
                  _completionCard(completion),
                  const SizedBox(height: 14),
                  _weightCard(),
                ],
              ),
      ),
    );
  }

  Widget _weekSelector() {
    final start = _weekStart;
    final end = start.add(const Duration(days: 6));
    final fmt = DateFormat('d MMM', 'tr');
    final label =
        _weekOffset == 0 ? 'Bu Hafta' : '${-_weekOffset} hafta önce';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() => _weekOffset--);
                  _load();
                },
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('${fmt.format(start)} - ${fmt.format(end)}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(label,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _weekOffset >= 0
                    ? null
                    : () {
                        setState(() => _weekOffset++);
                        _load();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _calorieChartCard(int goal) {
    final scheme = Theme.of(context).colorScheme;
    final values = _weekValues;
    final maxVal = [
      goal.toDouble(),
      ...values,
    ].reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kalori Alımı',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Hedef: $goal kcal/gün',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: scheme.secondary,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Text('Gerçek', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(height: 180, child: _lineChart(goal, maxVal * 1.2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lineChart(int goal, double maxY) {
    final scheme = Theme.of(context).colorScheme;
    final values = _weekValues;
    final muted =
        Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 100 : maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= 7) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_dayLabels[i],
                      style: TextStyle(fontSize: 12, color: muted)),
                );
              },
            ),
          ),
        ),
        // Hedef çizgisi (kesikli)
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(
            y: goal.toDouble(),
            color: muted.withValues(alpha: 0.6),
            strokeWidth: 1.5,
            dashArray: [6, 4],
          ),
        ]),
        lineTouchData: LineTouchData(
          touchCallback: (event, resp) {
            if (event is FlTapUpEvent && resp?.lineBarSpots != null) {
              final i = resp!.lineBarSpots!.first.x.toInt();
              final key =
                  DateHelpers.keyOf(_weekStart.add(Duration(days: i)));
              context.read<DiaryProvider>().loadDate(key);
              context.read<NavProvider>().go(0);
            }
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < 7; i++) FlSpot(i.toDouble(), values[i]),
            ],
            isCurved: true,
            color: scheme.secondary,
            barWidth: 3,
            dotData: FlDotData(
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                radius: 4,
                color: scheme.secondary,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.secondary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avgCard(double avg, double diff) {
    final scheme = Theme.of(context).colorScheme;
    final down = diff < 0;
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.restaurant_outlined, size: 18, color: muted),
                  const SizedBox(width: 8),
                  Text('Ortalama Günlük Alım',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                        text: '${avg.round()} ',
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                    TextSpan(text: 'kcal', style: TextStyle(color: muted)),
                  ],
                ),
              ),
              if (_prevWeekAvg > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(down ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 14, color: scheme.secondary),
                    Text(
                      '${diff.abs().round()} kcal geçen haftaya göre',
                      style: TextStyle(
                          color: scheme.secondary, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _completionCard(int completion) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1FA463),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.flag_outlined, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('Hedef Tutturma',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('%$completion',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.verified_outlined,
                color: Colors.white54, size: 56),
          ],
        ),
      ),
    );
  }

  Widget _weightCard() {
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.monitor_weight_outlined, color: muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kilo Takibi',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Yakında eklenecek',
                        style: TextStyle(color: muted, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('YAKINDA',
                    style: TextStyle(
                        color: scheme.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
