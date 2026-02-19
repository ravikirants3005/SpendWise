import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_tokens.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List expenses = [];
  bool loading = true;
  int touchedSlice = -1;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = await ApiService.getAllExpenses();
      if (!mounted) return;
      setState(() {
        expenses = data;
        loading = false;
      });
    } catch (e) {
      debugPrint('analytics load err $e');
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  DateTime _safeDate(dynamic raw) {
    return DateTime.tryParse((raw ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _isIncomeTx(Map<String, dynamic> tx) {
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
    final category = (tx['category'] ?? '').toString().toLowerCase();
    return amount < 0 ||
        category.contains('salary') ||
        category.contains('income') ||
        category.contains('refund');
  }

  double _expenseAmount(Map<String, dynamic> tx) {
    if (_isIncomeTx(tx)) return 0;
    return ((tx['amount'] as num?)?.toDouble() ?? 0).abs();
  }

  double totalSpent() {
    return expenses.fold<double>(
      0.0,
      (p, e) => p + _expenseAmount(e as Map<String, dynamic>),
    );
  }

  Map<String, double> categoryTotals({bool thisMonthOnly = false}) {
    final out = <String, double>{};
    final now = DateTime.now();
    for (final e in expenses) {
      final tx = e as Map<String, dynamic>;
      final dt = _safeDate(tx['date']);
      if (thisMonthOnly && (dt.year != now.year || dt.month != now.month)) {
        continue;
      }
      final amt = _expenseAmount(tx);
      if (amt <= 0) continue;
      final cat = (tx['category'] ?? 'Other').toString();
      out[cat] = (out[cat] ?? 0) + amt;
    }
    final sorted = out.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map<String, double>.fromEntries(sorted);
  }

  Map<int, double> dailyTotalsForCurrentMonth() {
    final out = <int, double>{};
    final now = DateTime.now();
    for (final e in expenses) {
      final tx = e as Map<String, dynamic>;
      final dt = _safeDate(tx['date']);
      if (dt.year == now.year && dt.month == now.month) {
        final amt = _expenseAmount(tx);
        if (amt <= 0) continue;
        out[dt.day] = (out[dt.day] ?? 0) + amt;
      }
    }
    final sorted = out.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Map<int, double>.fromEntries(sorted);
  }

  List<double> weeklySpendSeries() {
    final now = DateTime.now();
    final vals = List<double>.filled(7, 0);
    for (final e in expenses) {
      final tx = e as Map<String, dynamic>;
      final d = _safeDate(tx['date']);
      final diff = now.difference(DateTime(d.year, d.month, d.day)).inDays;
      if (diff >= 0 && diff < 7) {
        final amt = _expenseAmount(tx);
        if (amt <= 0) continue;
        vals[6 - diff] += amt;
      }
    }
    return vals;
  }

  double avgPerDayThisMonth() {
    final days = max(1, DateTime.now().day);
    return monthSpend() / days;
  }

  double monthSpend() {
    final now = DateTime.now();
    double v = 0;
    for (final e in expenses) {
      final tx = e as Map<String, dynamic>;
      final d = _safeDate(tx['date']);
      if (d.year == now.year && d.month == now.month) {
        final amt = _expenseAmount(tx);
        if (amt <= 0) continue;
        v += amt;
      }
    }
    return v;
  }

  double previousMonthSpend() {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1, 1);
    double v = 0;
    for (final e in expenses) {
      final tx = e as Map<String, dynamic>;
      final d = _safeDate(tx['date']);
      if (d.year == prev.year && d.month == prev.month) {
        final amt = _expenseAmount(tx);
        if (amt <= 0) continue;
        v += amt;
      }
    }
    return v;
  }

  Map<DateTime, double> monthHeatmapIntensity() {
    final now = DateTime.now();
    final dayTotals = <DateTime, double>{};
    double maxV = 1;
    for (final e in expenses) {
      final tx = e as Map<String, dynamic>;
      final d = _safeDate(tx['date']);
      if (d.year == now.year && d.month == now.month) {
        final key = DateTime(d.year, d.month, d.day);
        final amt = _expenseAmount(tx);
        if (amt <= 0) continue;
        final next = (dayTotals[key] ?? 0) + amt;
        dayTotals[key] = next;
        if (next > maxV) maxV = next;
      }
    }
    return {
      for (final entry in dayTotals.entries) entry.key: (entry.value / maxV).clamp(0, 1)
    };
  }

  String topCategoryLabel() {
    final totals = categoryTotals(thisMonthOnly: true);
    if (totals.isEmpty) return 'No category data yet';
    final e = totals.entries.first;
    return '${e.key} leads with \u20B9${e.value.toStringAsFixed(0)}';
  }

  List<PieChartSectionData> pieSections() {
    final data = categoryTotals(thisMonthOnly: true).entries.take(5).toList();
    if (data.isEmpty) return [];
    final sum = data.fold<double>(0, (p, e) => p + e.value);
    return List.generate(data.length, (i) {
      final e = data[i];
      final pct = sum == 0 ? 0 : (e.value / sum) * 100;
      final touched = touchedSlice == i;
      return PieChartSectionData(
        value: e.value,
        color: _palette(i),
        radius: touched ? 66 : 58,
        title: '${pct.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
    });
  }

  Color _palette(int i) {
    const colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      Color(0xFFFFB020),
      AppColors.danger,
    ];
    return colors[i % colors.length];
  }

  Widget _glass(Widget child, {EdgeInsets padding = const EdgeInsets.all(AppSpace.md)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }

  Widget _kpiRibbon() {
    final month = monthSpend();
    final avg = avgPerDayThisMonth();
    const budget = 5000.0;
    final budgetLeft = max(0.0, budget - month);
    final prev = previousMonthSpend();
    final growth = prev <= 0 ? 0.0 : ((month - prev) / prev) * 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analytics',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Money movement, habits, and signals',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _kpiCard('Monthly spend', month, Icons.account_balance_wallet),
              _kpiCard('Avg/day', avg, Icons.show_chart),
              _kpiCard('Budget left', budgetLeft, Icons.savings),
              _kpiCard('vs last month', growth, Icons.trending_up, suffix: '%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, double value, IconData icon, {String suffix = ''}) {
    return _glass(
      padding: const EdgeInsets.all(12),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: value),
                duration: const Duration(milliseconds: 850),
                builder: (context, v, _) => Text(
                  suffix == '%'
                      ? '${v.toStringAsFixed(1)}$suffix'
                      : '\u20B9${v.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallMultiples() {
    final weekly = weeklySpendSeries();
    final maxY = max(1.0, weekly.fold<double>(0, (p, e) => max(p, e)));
    final daily = dailyTotalsForCurrentMonth();
    final category = categoryTotals(thisMonthOnly: true).entries.take(4).toList();
    final total = max(1.0, category.fold<double>(0, (p, e) => p + e.value));

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth > 760;
        final cardWidth = twoCol ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _glass(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('7-day trend', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 110,
                      child: LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: 6,
                          minY: 0,
                          maxY: maxY + maxY * 0.2,
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineTouchData: const LineTouchData(enabled: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                weekly.length,
                                (i) => FlSpot(i.toDouble(), weekly[i]),
                              ),
                              isCurved: true,
                              barWidth: 3,
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.secondary],
                              ),
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.24),
                                    AppColors.secondary.withValues(alpha: 0.04),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _glass(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Category share', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (category.isEmpty)
                      const Text('No category data')
                    else
                      ...category.asMap().entries.map((entry) {
                        final i = entry.key;
                        final e = entry.value;
                        final pct = (e.value / total).clamp(0, 1).toDouble();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(e.key),
                                  Text('${(pct * 100).toStringAsFixed(0)}%'),
                                ],
                              ),
                              const SizedBox(height: 5),
                              LinearProgressIndicator(
                                value: pct,
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(999),
                                backgroundColor: AppColors.neutral100,
                                valueColor: AlwaysStoppedAnimation(_palette(i)),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _glass(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Daily spend (month)', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 110,
                      child: BarChart(
                        BarChartData(
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          barTouchData: BarTouchData(enabled: true),
                          barGroups: daily.entries
                              .take(12)
                              .map(
                                (e) => BarChartGroupData(
                                  x: e.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: e.value,
                                      width: 9,
                                      borderRadius: BorderRadius.circular(5),
                                      color: AppColors.accent,
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _glass(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Insight rail', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _insightLine('Top category', topCategoryLabel()),
                    _insightLine('Budget signal', monthSpend() <= 5000 ? 'Within budget this month' : 'Over budget this month'),
                    _insightLine('Action', 'Set recurring for your top expense'),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _insightLine(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bolt, size: 16, color: AppColors.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                Text(body, style: const TextStyle(color: AppColors.neutral700, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerpieceRow() {
    final pie = pieSections();
    final category = categoryTotals(thisMonthOnly: true).entries.take(4).toList();
    final values = category.isEmpty
        ? [0.0, 0.0, 0.0]
        : category
            .map((e) => e.value)
            .take(3)
            .map((v) => (v / category.first.value).clamp(0, 1).toDouble())
            .toList();
    while (values.length < 3) {
      values.add(0.0);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;
        final donut = _glass(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category flow', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (pie.isEmpty)
                const SizedBox(
                  height: 180,
                  child: Center(child: Text('No transactions for this month')),
                )
              else
                SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sections: pie,
                      centerSpaceRadius: 36,
                      sectionsSpace: 2,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            touchedSlice =
                                response?.touchedSection?.touchedSectionIndex ??
                                    -1;
                          });
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

        final radial = _glass(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Goal rings', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Center(
                child: LayeredRadialGoals(
                  values: values,
                  colors: const [AppColors.primary, AppColors.secondary, AppColors.success],
                ),
              ),
            ],
          ),
        );

        if (stacked) {
          return Column(
            children: [
              donut,
              const SizedBox(height: 12),
              radial,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: donut),
            const SizedBox(width: 12),
            Expanded(child: radial),
          ],
        );
      },
    );
  }

  Widget _heatmapCard() {
    final now = DateTime.now();
    final heatmap = monthHeatmapIntensity();
    return _glass(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Spending heatmap', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SimpleHeatmap(values: heatmap, year: now.year, month: now.month),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _kpiRibbon(),
            const SizedBox(height: 12),
            _centerpieceRow(),
            const SizedBox(height: 12),
            _heatmapCard(),
            const SizedBox(height: 12),
            _smallMultiples(),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}

class LayeredRadialGoals extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;
  final double size;

  const LayeredRadialGoals({
    required this.values,
    required this.colors,
    this.size = 160,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final top = values.isEmpty ? 0.0 : values.first;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < values.length; i++)
            _AnimatedRing(
              index: i,
              stroke: 12,
              value: values[i].clamp(0, 1),
              color: colors[i % colors.length],
              size: size - i * 18,
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Goals', style: TextStyle(fontSize: 12, color: AppColors.neutral500)),
              const SizedBox(height: 6),
              Text(
                '${(top * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedRing extends StatefulWidget {
  final int index;
  final double stroke;
  final double value;
  final double size;
  final Color color;

  const _AnimatedRing({
    required this.index,
    required this.stroke,
    required this.value,
    required this.size,
    required this.color,
  });

  @override
  State<_AnimatedRing> createState() => _AnimatedRingState();
}

class _AnimatedRingState extends State<_AnimatedRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 900 + widget.index * 80),
    );
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          return CustomPaint(
            painter: _RingPainter(
              color: widget.color,
              stroke: widget.stroke,
              sweep: widget.value * _anim.value * 2 * pi,
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  final double stroke;
  final double sweep;

  const _RingPainter({
    required this.color,
    required this.stroke,
    required this.sweep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) / 2 - stroke / 2;

    final bg = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..shader = SweepGradient(colors: [color, color.withValues(alpha: 0.8)])
          .createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.sweep != sweep || oldDelegate.color != color;
  }
}

class SimpleHeatmap extends StatelessWidget {
  final Map<DateTime, double> values;
  final int year;
  final int month;

  const SimpleHeatmap({
    required this.values,
    required this.year,
    required this.month,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final days = last.day;
    final startWeekday = first.weekday % 7;

    final cells = <Widget>[];
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (int d = 1; d <= days; d++) {
      final dt = DateTime(year, month, d);
      final intensity = values[DateTime(dt.year, dt.month, dt.day)] ?? 0.0;
      cells.add(_dayCell(d, intensity));
    }
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${first.month}/${first.year}',
          style: const TextStyle(color: AppColors.neutral700, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          shrinkWrap: true,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: cells,
        ),
      ],
    );
  }

  Widget _dayCell(int day, double intensity) {
    final color = Color.lerp(
      AppColors.neutral100,
      AppColors.secondary,
      intensity.clamp(0, 1),
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        '$day',
        style: TextStyle(
          fontSize: 11,
          color: intensity > 0.4 ? Colors.black : AppColors.neutral900,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
