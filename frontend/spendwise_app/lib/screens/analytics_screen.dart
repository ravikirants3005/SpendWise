import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'dart:math';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List expenses = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = await ApiService.getAllExpenses();
      setState(() {
        expenses = data;
        loading = false;
      });
    } catch (e) {
      debugPrint('analytics load err $e');
      setState(() => loading = false);
    }
  }

  Map<String, double> categoryTotals() {
    final Map<String, double> m = {};
    for (var e in expenses) {
      final cat = (e['category'] ?? 'Unknown').toString();
      final amt = (e['amount'] as num).toDouble();
      m[cat] = (m[cat] ?? 0) + amt;
    }
    return m;
  }

  Map<int, double> dailyTotals() {
    final Map<int, double> m = {};
    for (var e in expenses) {
      final date = DateTime.tryParse(e['date'] ?? '') ?? DateTime.now();
      final day = date.day;
      final amt = (e['amount'] as num).toDouble();
      m[day] = (m[day] ?? 0) + amt;
    }
    final sorted = Map.fromEntries(m.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    return sorted;
  }

  double totalSpent() => expenses.fold(0.0, (p, e) => p + (e['amount'] as num).toDouble());

  List<PieChartSectionData> buildPie() {
    final data = categoryTotals();
    if (data.isEmpty) return [];
    final colors = [Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.teal];
    int i = 0;
    return data.entries.map((e) {
      return PieChartSectionData(
        value: e.value,
        color: colors[i++ % colors.length],
        title: '${e.key}\n₹${e.value.toInt()}',
        radius: 56,
        titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700),
      );
    }).toList();
  }

  List<BarChartGroupData> buildBar() {
    final d = dailyTotals();
    if (d.isEmpty) return [];
    return d.entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [BarChartRodData(toY: e.value, width: 18, color: Colors.cyan)],
      );
    }).toList();
  }

  LineChartData buildLineData() {
    final d = dailyTotals();
    final spots = d.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    final maxY = d.isEmpty ? 1.0 : (d.values.reduce(max));
    final interval = max(1, (maxY / 4).round());
    return LineChartData(
      lineBarsData: [
        LineChartBarData(spots: spots, isCurved: true, color: Colors.purple, barWidth: 3, dotData: FlDotData(show: true)),
      ],
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: interval.toDouble(), reservedSize: 40)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (value, meta) {
          return Text(value.toInt().toString());
        })),
      ),
      borderData: FlBorderData(show: true),
      minY: 0,
      maxY: maxY + interval.toDouble(),
    );
  }

  Widget cardHeader(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(children: [Text(title, style: const TextStyle(fontSize: 16)), const SizedBox(height: 12), SizedBox(height: 240, child: child)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final pieSections = buildPie();
    final barGroups = buildBar();
    final total = totalSpent();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // SUMMARY — only Total Spent (transactions card removed as requested)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xff7c4dff), Color(0xff8e7ff8)]), borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total Spent', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
            ),

            // PIE — only when there's category data
            if (pieSections.isNotEmpty)
              cardHeader(
                'Category Breakdown',
                Center(child: PieChart(PieChartData(sections: pieSections, centerSpaceRadius: 40, sectionsSpace: 2))),
              ),

            // BAR — daily spending (only when we have data)
            if (barGroups.isNotEmpty)
              cardHeader(
                'Daily Spending',
                BarChart(BarChartData(
                  barGroups: barGroups,
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24)),
                  ),
                  borderData: FlBorderData(show: true),
                  maxY: dailyTotals().isEmpty ? 1 : (dailyTotals().values.reduce(max) + 50),
                )),
              ),

            // LINE — trend
            if (dailyTotals().isNotEmpty)
              cardHeader(
                'Spending Trend',
                LineChart(buildLineData()),
              ),

            // Fallback message when no expenses exist
            if (expenses.isEmpty) ...[
              const SizedBox(height: 40),
              const Text('No data yet — add expenses to populate charts', style: TextStyle(color: Colors.grey)),
            ],

            const SizedBox(height: 80), // bottom spacing so FAB / bottom nav not overlap content
          ]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_expense',
        onPressed: () {
          // Keep nav simple: user can use bottom nav to go to Expenses or Add via Home
          Navigator.of(context).pop(); // optional — keep behavior simple (or open AddExpense)
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
