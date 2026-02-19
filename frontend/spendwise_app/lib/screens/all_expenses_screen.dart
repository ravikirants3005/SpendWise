import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'add_expense_screen.dart';

class AllExpensesScreen extends StatefulWidget {
  const AllExpensesScreen({super.key});

  @override
  State<AllExpensesScreen> createState() => _AllExpensesScreenState();
}

class _AllExpensesScreenState extends State<AllExpensesScreen> {
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
      final result = await ApiService.getAllExpenses();
      result.sort((a, b) {
        final ad = DateTime.tryParse((a['date'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bd = DateTime.tryParse((b['date'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      setState(() {
        expenses = result;
        loading = false;
      });
    } catch (e) {
      debugPrint('load expenses err $e');
      setState(() => loading = false);
    }
  }

  bool _isIncome(Map<String, dynamic> tx) {
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
    final c = (tx['category'] ?? '').toString().toLowerCase();
    return amount < 0 ||
        c.contains('income') ||
        c.contains('salary') ||
        c.contains('refund');
  }

  IconData _icon(String c) {
    final x = c.toLowerCase();
    if (x.contains('food')) return Icons.restaurant;
    if (x.contains('travel')) return Icons.directions_bus;
    if (x.contains('bill')) return Icons.receipt_long;
    if (x.contains('shopping')) return Icons.shopping_bag;
    if (x.contains('health')) return Icons.medical_services;
    if (x.contains('salary') || x.contains('income')) return Icons.payments;
    return Icons.category;
  }

  String _date(String raw) {
    final d = DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (d.year < 2000) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _repeatTx(Map<String, dynamic> tx) async {
    final ok = await ApiService.addExpense(
      ((tx['amount'] as num?)?.toDouble() ?? 0).abs(),
      (tx['category'] ?? 'Other').toString(),
      (tx['description'] ?? 'Repeated').toString(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Transaction repeated.' : 'Repeat failed.')),
    );
    if (ok) load();
  }

  Future<void> _deleteTx(Map<String, dynamic> tx) async {
    final id = (tx['id'] ?? '').toString();
    if (id.isEmpty) return;
    final ok = await ApiService.deleteExpense(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Transaction deleted.' : 'Delete failed.')),
    );
    if (ok) load();
  }

  Future<void> _splitTx(Map<String, dynamic> tx) async {
    final total = ((tx['amount'] as num?)?.toDouble() ?? 0).abs();
    if (total <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot split a zero amount transaction.')),
      );
      return;
    }

    final firstCtrl = TextEditingController(text: (total / 2).toStringAsFixed(2));
    final firstAmount = await showDialog<double>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              title: const Text('Split Expense'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total: ₹${total.toStringAsFixed(2)}'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: firstCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'First split amount'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final parsed = double.tryParse(firstCtrl.text.trim());
                    if (parsed == null || parsed <= 0 || parsed >= total) {
                      setLocalState(() => error = 'Enter a value > 0 and < total.');
                      return;
                    }
                    Navigator.of(ctx).pop(parsed);
                  },
                  child: const Text('Split'),
                ),
              ],
            );
          },
        );
      },
    );
    if (firstAmount == null) return;
    final secondAmount = total - firstAmount;
    if (secondAmount <= 0) return;

    final category = (tx['category'] ?? 'Other').toString();
    final baseDesc = (tx['description'] ?? category).toString().trim();
    final ok1 = await ApiService.addExpense(firstAmount, category, '$baseDesc (Split 1/2)');
    final ok2 = await ApiService.addExpense(secondAmount, category, '$baseDesc (Split 2/2)');
    var okDelete = true;
    final id = (tx['id'] ?? '').toString();
    if (id.isNotEmpty) okDelete = await ApiService.deleteExpense(id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok1 && ok2 && okDelete
            ? 'Transaction split into two entries.'
            : 'Split partially failed. Please review.'),
      ),
    );
    load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: expenses.length,
          separatorBuilder: (_, separatorIndex) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final e = expenses[i] as Map<String, dynamic>;
            final amount = (e['amount'] as num?)?.toDouble() ?? 0;
            final category = (e['category'] ?? '').toString();
            final description = (e['description'] ?? '').toString();
            final date = _date((e['date'] ?? '').toString());
            final income = _isIncome(e);
            final id = (e['id'] ?? i.toString()).toString();

            return Dismissible(
              key: ValueKey('exp_$id'),
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                child: const Row(
                  children: [
                    Icon(Icons.repeat, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Repeat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              secondaryBackground: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerRight,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    SizedBox(width: 6),
                    Icon(Icons.delete, color: Colors.white),
                  ],
                ),
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  await _repeatTx(e);
                } else {
                  await _deleteTx(e);
                }
                return false;
              },
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  onLongPress: () => _splitTx(e),
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade50,
                    child: Icon(_icon(category)),
                  ),
                  title: Text('${income ? '+' : '-'}₹${amount.abs().toStringAsFixed(2)} • $category'),
                  subtitle: Text(description),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(date),
                      PopupMenuButton<String>(
                        tooltip: 'Actions',
                        onSelected: (value) {
                          if (value == 'repeat') {
                            _repeatTx(e);
                          } else if (value == 'split') {
                            _splitTx(e);
                          } else if (value == 'delete') {
                            _deleteTx(e);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'repeat', child: Text('Repeat')),
                          PopupMenuItem(value: 'split', child: Text('Split')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );
          load();
        },
      ),
    );
  }
}
