import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const _base = 'http://127.0.0.1:8000'; // change if needed

  static Future<List<dynamic>> getAllExpenses() async {
    final res = await http.get(Uri.parse('$_base/expenses/all'));
    if (res.statusCode == 200) return json.decode(res.body) as List<dynamic>;
    throw Exception('Failed to load expenses ${res.statusCode}');
  }

  static Future<double> getTodayTotal() async {
    final res = await http.get(Uri.parse('$_base/expenses/today'));
    if (res.statusCode == 200) {
      final map = json.decode(res.body);
      return (map['today_total'] as num).toDouble();
    }
    return 0.0;
  }

  static Future<double> getMonthTotal() async {
    final res = await http.get(Uri.parse('$_base/expenses/month'));
    if (res.statusCode == 200) {
      final map = json.decode(res.body);
      return (map['month_total'] as num).toDouble();
    }
    return 0.0;
  }

  static Future<bool> addExpense(double amount, String category, String description) async {
    final body = json.encode({
      'amount': amount,
      'category': category,
      'description': description,
    });
    final res = await http.post(
      Uri.parse('$_base/expenses'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    return res.statusCode == 201 || res.statusCode == 200;
  }
}
