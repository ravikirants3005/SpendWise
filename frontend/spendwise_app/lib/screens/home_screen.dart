import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'add_expense_screen.dart';
import 'all_expenses_screen.dart';
import 'analytics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double todayTotal = 0;
  double monthTotal = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadTotals();
  }

  // Fetch totals from backend
  Future<void> loadTotals() async {
    setState(() => loading = true);
    try {
      final today = await ApiService.getTodayTotal();
      final month = await ApiService.getMonthTotal();
      setState(() {
        todayTotal = today;
        monthTotal = month;
        loading = false;
      });
    } catch (e) {
      debugPrint("Error loading totals: $e");
      setState(() => loading = false);
    }
  }

  Widget dashboardCard(String title, double amount, Color color) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 10),
          Text(
            "₹${amount.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Bottom nav builder kept simple and consistent with previous UI
  Widget buildBottomNav(int currentIndex) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        // 0 = Home, 1 = Expenses, 2 = Analytics
        if (index == 1) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AllExpensesScreen()))
              .then((_) => loadTotals());
        } else if (index == 2) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()))
              .then((_) => loadTotals());
        }
        // if index==0 we're already on Home
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.list), label: "Expenses"),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Analytics"),
      ],
      selectedItemColor: Colors.deepPurple,
      unselectedItemColor: Colors.black54,
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      elevation: 6,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SpendWise Dashboard")),
      // Square-ish plus button on bottom-left
      floatingActionButton: SizedBox(
        width: 56,
        height: 56,
        child: FloatingActionButton(
          heroTag: 'add_square',
          onPressed: () async {
            // Open Add Expense and refresh totals afterwards
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
            );
            await loadTotals();
          },
          backgroundColor: Colors.deepPurpleAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.add, size: 28),
          tooltip: 'Add Expense',
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      dashboardCard("Today", todayTotal, Colors.green),
                      const SizedBox(width: 20),
                      dashboardCard("This Month", monthTotal, Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Removed the duplicate buttons that were below the totals.
                  // Users can use the bottom nav to go to Expenses/Analytics and the FAB to add expense.

                  const SizedBox(height: 20),
                  const Spacer(),
                ],
              ),
      ),
      bottomNavigationBar: buildBottomNav(0),
    );
  }
}
