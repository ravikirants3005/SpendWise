import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
      setState(() {
        expenses = result;
        loading = false;
      });
    } catch (e) {
      debugPrint('load expenses err $e');
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: expenses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final e = expenses[i];
          final amount = (e['amount'] as num).toDouble();
          final category = e['category'] ?? '';
          final description = e['description'] ?? '';
          final date = e['date'] ?? '';
          return Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: Colors.deepPurple.shade50, child: const Icon(Icons.food_bank)),
              title: Text('₹${amount.toStringAsFixed(2)} • $category'),
              subtitle: Text(description),
              trailing: Text(date),
              onTap: () {},
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const _DummyAdd())).then((_) => load());
        },
      ),
    );
  }
}

class _DummyAdd extends StatelessWidget {
  const _DummyAdd({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Use bottom Add button instead')));
}
