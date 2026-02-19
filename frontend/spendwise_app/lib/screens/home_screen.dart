import 'dart:math';
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/user_settings.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../theme/app_tokens.dart';
import 'add_expense_screen.dart';

class HomeScreen extends StatefulWidget {
  final int reloadSignal;

  const HomeScreen({required this.reloadSignal, super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double todayTotal = 0;
  double monthTotal = 0;
  List<dynamic> expenses = [];
  UserSettings settings = UserSettings.defaults;
  bool loading = true;
  int touchedSlice = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadSignal != widget.reloadSignal) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final results = await Future.wait<dynamic>([
      ApiService.getTodayTotal(),
      ApiService.getMonthTotal(),
      ApiService.getAllExpenses(),
      SettingsService.load(),
    ]);
    if (!mounted) return;
    setState(() {
      todayTotal = results[0] as double;
      monthTotal = results[1] as double;
      expenses = results[2] as List<dynamic>;
      settings = results[3] as UserSettings;
      loading = false;
    });
  }

  DateTime _d(dynamic raw) =>
      DateTime.tryParse((raw ?? "").toString()) ??
      DateTime.fromMillisecondsSinceEpoch(0);

  List<dynamic> _sorted() {
    final copy = [...expenses];
    copy.sort((a, b) => _d(b["date"]).compareTo(_d(a["date"])));
    return copy;
  }

  bool _isIncome(Map<String, dynamic> tx) {
    final amount = (tx["amount"] as num?)?.toDouble() ?? 0;
    final c = (tx["category"] ?? "").toString().toLowerCase();
    return amount < 0 ||
        c.contains("income") ||
        c.contains("salary") ||
        c.contains("refund");
  }

  Map<String, double> _categoryTotals() {
    final now = DateTime.now();
    final m = <String, double>{};
    for (final e in expenses) {
      final tx = e as Map<String, dynamic>;
      final d = _d(tx["date"]);
      if (d.year == now.year && d.month == now.month) {
        if (_isIncome(tx)) continue;
        final k = (tx["category"] ?? "Other").toString();
        final v = ((tx["amount"] as num?)?.toDouble() ?? 0).abs();
        if (v <= 0) continue;
        m[k] = (m[k] ?? 0) + v;
      }
    }
    final list = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map<String, double>.fromEntries(list.take(5));
  }

  List<double> _sparklineData() {
    final now = DateTime.now();
    final v = List<double>.filled(7, 0);
    for (final e in expenses) {
      final tx = e as Map<String, dynamic>;
      if (_isIncome(tx)) continue;
      final dd = _d(tx["date"]);
      final diff = now.difference(DateTime(dd.year, dd.month, dd.day)).inDays;
      if (diff >= 0 && diff < 7) {
        final amt = ((tx["amount"] as num?)?.toDouble() ?? 0).abs();
        if (amt <= 0) continue;
        v[6 - diff] += amt;
      }
    }
    return v;
  }

  String _statusLine() {
    final budget = settings.monthlyBudget <= 0 ? 1.0 : settings.monthlyBudget;
    return monthTotal <= budget ? "You're under budget ✅" : "Watch out 👀";
  }

  String _insightText() {
    final c = _categoryTotals();
    if (c.isEmpty) return "No trend yet. Add expenses to unlock insights.";
    final top = c.entries.first;
    return "${top.key} is your biggest category this month (₹${top.value.toStringAsFixed(0)}).";
  }

  IconData _icon(String c) {
    final x = c.toLowerCase();
    if (x.contains("food")) return Icons.restaurant;
    if (x.contains("travel")) return Icons.directions_bus;
    if (x.contains("bill")) return Icons.receipt_long;
    if (x.contains("shopping")) return Icons.shopping_bag;
    return Icons.category;
  }

  Color _p(int i) => const [
        AppColors.primary,
        AppColors.secondary,
        AppColors.accent,
        Color(0xFFFFB020),
        AppColors.danger
      ][i % 5];

  Widget _glass(Widget child, {EdgeInsets pad = const EdgeInsets.all(AppSpace.md)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: pad,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 6))
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _hero() {
    final budget = settings.monthlyBudget <= 0 ? 1.0 : settings.monthlyBudget;
    final progress = (monthTotal / budget).clamp(0, 1).toDouble();
    final h = TimeOfDay.now().hour;
    final greet = h < 12 ? "Morning" : h < 17 ? "Afternoon" : "Evening";
    return Stack(children: [
      ClipPath(
        clipper: _BottomWaveClipper(),
        child: Container(
          height: 250,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary]),
          ),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                  center: const Alignment(-0.8, -0.6),
                  radius: 1.2,
                  colors: [Colors.white.withValues(alpha: 0.25), Colors.transparent]),
            ),
          ),
        ),
      ),
      SizedBox(
        height: 245,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Good $greet, ${settings.userName}",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: monthTotal),
                    duration: const Duration(milliseconds: 850),
                    builder: (context, v, _) => Text("₹${v.toStringAsFixed(2)}",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800)),
                  ),
                  Text(_statusLine(), style: const TextStyle(color: Colors.white70)),
                ]),
              ),
              CircleAvatar(
                  radius: 21,
                  backgroundColor: Colors.white24,
                  child: const Text("🙂")),
            ]),
            const Spacer(),
            _glass(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Budget progress",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF9BFFD7))),
              ),
              const SizedBox(height: 6),
              Text("₹${monthTotal.toStringAsFixed(0)} / ₹${budget.toStringAsFixed(0)}",
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]), pad: const EdgeInsets.all(12)),
          ]),
        ),
      ),
    ]);
  }

  Widget _topCards() {
    final spark = _sparklineData();
    final maxY = max(1.0, spark.fold<double>(0, (p, e) => max(p, e)));
    return Row(children: [
      Expanded(
        flex: 6,
        child: _glass(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("This Month"),
          Text("₹${monthTotal.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          SizedBox(
            height: 58,
            child: LineChart(LineChartData(
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY: maxY + maxY * 0.2,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                    spots: List.generate(7, (i) => FlSpot(i.toDouble(), spark[i])),
                    isCurved: true,
                    barWidth: 2.8,
                    gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary]),
                    dotData: const FlDotData(show: false))
              ],
            )),
          ),
        ])),
      ),
      const SizedBox(width: AppSpace.sm),
      Expanded(
        flex: 4,
        child: _glass(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Today"),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: todayTotal),
            duration: const Duration(milliseconds: 700),
            builder: (context, v, _) => Text("₹${v.toStringAsFixed(2)}",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          Text(todayTotal > 0 ? "Logged today" : "No spend yet",
              style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
        ])),
      ),
    ]);
  }

  Widget _donut() {
    final c = _categoryTotals();
    final values = c.values.toList();
    final total = values.fold<double>(0, (p, e) => p + e);
    return _glass(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Category Distribution",
          style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      if (c.isEmpty)
        const Text("No category data yet.")
      else
        SizedBox(
          height: 160,
          child: Row(children: [
            Expanded(
                child: PieChart(PieChartData(
              centerSpaceRadius: 32,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                  touchCallback: (e, r) =>
                      setState(() => touchedSlice = r?.touchedSection?.touchedSectionIndex ?? -1)),
              sections: List.generate(c.length, (i) {
                final isT = touchedSlice == i;
                final pct = total == 0 ? 0 : (values[i] / total) * 100;
                return PieChartSectionData(
                    color: _p(i),
                    value: values[i],
                    radius: isT ? 58 : 50,
                    title: "${pct.toStringAsFixed(0)}%",
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold));
              }),
            ))),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: c.entries.toList().asMap().entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: _p(e.key),
                                  borderRadius: BorderRadius.circular(99))),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(
                                  "${e.value.key} ₹${e.value.value.toStringAsFixed(0)}",
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12))),
                        ]),
                      );
                    }).toList())),
          ]),
        ),
    ]));
  }

  Widget _insightCard() {
    final gp = settings.goalTarget <= 0
        ? 0.0
        : (settings.goalCurrent / settings.goalTarget).clamp(0, 1).toDouble();
    return _glass(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Spending Insight", style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(_insightText(), style: const TextStyle(color: AppColors.neutral700)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: AppColors.neutral50.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.lightbulb, color: AppColors.accent),
          SizedBox(width: 8),
          Expanded(
              child: Text("You spend more on travel in evenings. Add recurring reminder?",
                  style: TextStyle(fontSize: 12)))
        ]),
      ),
      const SizedBox(height: 12),
      Text(
          "Saving Goal: ${settings.goalName}  ₹${settings.goalCurrent.toStringAsFixed(0)} / ₹${settings.goalTarget.toStringAsFixed(0)}",
          style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: gp),
        duration: const Duration(milliseconds: 700),
        builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: 9,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: AppColors.neutral100,
            valueColor: const AlwaysStoppedAnimation(AppColors.success)),
      ),
    ]));
  }

  Widget _recentPreview() {
    final r = _sorted().take(3).toList();
    return _glass(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.receipt_long, size: 18),
        SizedBox(width: 6),
        Text("Recent transactions", style: TextStyle(fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      if (r.isEmpty)
        const Text("No transactions yet. Add expenses from + button.")
      else
        ...r.map((e) {
          final tx = e as Map<String, dynamic>;
          final amount = ((tx["amount"] as num?)?.toDouble() ?? 0);
          final income = _isIncome(tx);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Icon(_icon((tx["category"] ?? "Other").toString()),
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                  child: Text((tx["description"] ?? tx["category"] ?? "Untitled")
                      .toString(),
                      overflow: TextOverflow.ellipsis)),
              Text("${income ? "+" : "-"}₹${amount.abs().toStringAsFixed(0)}",
                  style: TextStyle(
                      color: income ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.w700)),
            ]),
          );
        }),
      const SizedBox(height: 4),
      const Text(
        "For full actions (repeat, split, delete), use the Expenses tab.",
        style: TextStyle(fontSize: 12, color: AppColors.neutral500),
      ),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      floatingActionButton: SizedBox(
        width: 60,
        height: 60,
        child: FloatingActionButton(
          heroTag: "add_square",
          onPressed: () async {
            await Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
            await _load();
          },
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          tooltip: "Add Expense",
          child: const Icon(Icons.add, size: 30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: EdgeInsets.zero, children: [
                _hero(),
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    child: Column(children: [
                      _topCards(),
                      const SizedBox(height: 16),
                      _donut(),
                      const SizedBox(height: 16),
                      _insightCard(),
                      const SizedBox(height: 16),
                      _recentPreview(),
                    ]),
                  ),
                ),
              ]),
            ),
    );
  }
}

class _BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path();
    p.lineTo(0, size.height - 48);
    p.quadraticBezierTo(
        size.width * 0.22, size.height + 6, size.width * 0.5, size.height - 22);
    p.quadraticBezierTo(
        size.width * 0.78, size.height - 48, size.width, size.height - 20);
    p.lineTo(size.width, 0);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
