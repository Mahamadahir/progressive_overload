import 'package:flutter/material.dart';

import 'screens/dashboard_page.dart';
import 'screens/plan_list_page.dart';
import 'screens/log_calories_page.dart';
import 'screens/trends_calendar_page.dart';
import 'screens/vitality_hub_page.dart';

/// Root navigation shell. Holds the primary destinations behind a bottom
/// navigation bar and keeps their state alive across tab switches.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    DashboardPage(),
    PlanListPage(),
    LogCaloriesPage(),
    TrendsCalendarPage(),
    VitalityHubPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _destinations),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Plans',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up),
            label: 'Trends',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Vitality',
          ),
        ],
      ),
    );
  }
}
