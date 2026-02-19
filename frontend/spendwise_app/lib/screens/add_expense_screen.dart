import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});
  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amount = TextEditingController();
  final _category = TextEditingController();
  final _desc = TextEditingController();
  bool loading = false;

  Future<void> submit() async {
    final amt = double.tryParse(_amount.text);
    if (amt == null || _category.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter amount & category')));
      return;
    }
    setState(() => loading = true);
    final ok = await ApiService.addExpense(amt, _category.text, _desc.text);
    setState(() => loading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense saved')));
      Navigator.pop(context, true); // return true -> caller refreshes
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed saving')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
          TextField(controller: _category, decoration: const InputDecoration(labelText: 'Category')),
          TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: loading ? null : submit,
            child: loading ? const CircularProgressIndicator() : const Text('Save Expense'),
          ),
        ]),
      ),
    );
  }
}
