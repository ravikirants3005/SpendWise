import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/all_expenses_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const SpendWiseApp());
}

class SpendWiseApp extends StatefulWidget {
  const SpendWiseApp({super.key});

  @override
  State<SpendWiseApp> createState() => _SpendWiseAppState();
}

class _SpendWiseAppState extends State<SpendWiseApp> {
  ThemeMode _mode = ThemeMode.light;

  void toggleTheme() {
    setState(() => _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpendWise',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.tealAccent,
        useMaterial3: true,
      ),
      home: MainShell(
        onToggleTheme: toggleTheme,
        initialThemeMode: _mode,
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode initialThemeMode;
  const MainShell({required this.onToggleTheme, required this.initialThemeMode, super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _homeReloadSignal = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(reloadSignal: _homeReloadSignal),
      const AllExpensesScreen(),
      const AnalyticsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SpendWise Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              if (changed == true && mounted) {
                setState(() => _homeReloadSignal++);
              }
            },
          ),
          IconButton(
            tooltip: 'Toggle theme',
            icon: const Icon(Icons.dark_mode_outlined),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // refresh visible page by sending a notification or similar
              // For simplicity: rebuild shell (rebuild children)
              setState(() {});
            },
          ),
        ],
        elevation: 0,
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Expenses'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Analytics'),
        ],
      ),
    );
  }
}
