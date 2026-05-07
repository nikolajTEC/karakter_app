// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/class_provider.dart';
import 'screens/grading_screen.dart';
import 'screens/overview_screen.dart';
import 'screens/complaints_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted data before the first frame
  final provider = ClassProvider();
  await provider.load();

  // If no saved data exists, seed demo students so the app isn't empty
  provider.seedDemoData();

  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const GradeWheelApp(),
    ),
  );
}

class GradeWheelApp extends StatelessWidget {
  const GradeWheelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Karakterhjulet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const _screens = [
    GradingScreen(),
    OverviewScreen(),
    ComplaintsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.casino_outlined),
            selectedIcon: Icon(Icons.casino),
            label: 'Karakterer',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Overblik',
          ),
          NavigationDestination(
            icon: Icon(Icons.gavel_outlined),
            selectedIcon: Icon(Icons.gavel),
            label: 'Klager',
          ),
        ],
      ),
    );
  }
}