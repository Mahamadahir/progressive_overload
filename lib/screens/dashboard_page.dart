import 'package:flutter/material.dart';
import 'package:health/health.dart';

import 'package:fitness_app/services/workout_service.dart';
import 'package:fitness_app/services/health_service.dart';

// Screens
import 'create_workout_page.dart';
import 'plan_detail_page.dart';
import 'plan_list_page.dart';
import 'calorie_summary_page.dart';
import 'log_calories_page.dart';
import 'workout_history_page.dart';
import 'trends_calendar_page.dart';

import 'health_connect_diagnostics_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final service = WorkoutService();
  bool _checking = true;
  bool _authorized = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Use TOTAL_CALORIES_BURNED (READ) instead of ACTIVE_ENERGY_BURNED
    final ok = await HealthService.ensureAuthorized(
      types: const [
        HealthDataType.WORKOUT,
        HealthDataType.WEIGHT,
        HealthDataType.TOTAL_CALORIES_BURNED,
      ],
      permissions: const [
        HealthDataAccess.READ,
        HealthDataAccess.READ,
        HealthDataAccess.READ,
      ],
    );
    setState(() {
      _authorized = ok;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final plans = service.getPlans();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness Tracker'),
        actions: [
          IconButton(
            tooltip: 'All Workouts',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlanListPage()),
              );
              if (context.mounted) setState(() {});
            },
            icon: const Icon(Icons.view_list),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            tooltip: 'Diagnostics',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const HealthConnectDiagnosticsPage(),
              ),
            ),
            icon: const Icon(Icons.build),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateWorkoutPage()),
          );
          if (context.mounted) setState(() {});
        },
        child: const Icon(Icons.add),
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_authorized)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Health Connect permission needed. Tap Fix to re-request.',
                          ),
                        ),
                        TextButton(
                          onPressed: _checkPermissions,
                          child: const Text('Fix'),
                        ),
                      ],
                    ),
                  ),

                // Quick Links
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Quick links',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _QuickLink(
                        icon: Icons.local_fire_department,
                        label: 'Calorie Summary',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CalorieSummaryPage(),
                          ),
                        ),
                      ),
                      _QuickLink(
                        icon: Icons.restaurant,
                        label: 'Log Calories',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => LogCaloriesPage()),
                        ),
                      ),
                      _QuickLink(
                        icon: Icons.calendar_month,
                        label: 'Trends Calendar',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TrendsCalendarPage(),
                          ),
                        ),
                      ),
                      _QuickLink(
                        icon: Icons.history,
                        label: 'Workout History',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkoutHistoryPage(),
                          ),
                        ),
                      ),
                      _QuickLink(
                        icon: Icons.view_list,
                        label: 'Plans',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PlanListPage(),
                          ),
                        ),
                      ),
                      _QuickLink(
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () => Navigator.pushNamed(context, '/settings'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Plans list
                Expanded(
                  child: plans.isEmpty
                      ? const Center(
                          child: Text('No plans yet. Tap + to create one.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: plans.length,
                          itemBuilder: (_, i) {
                            final p = plans[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(p.name),
                                subtitle: Text(
                                  "Next up: ${p.currentWeightKg.toStringAsFixed(1)} kg × ${p.expectedReps} reps"
                                  "  •  ${p.mets.toStringAsFixed(1)} METs",
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PlanDetailPage(planId: p.id),
                                    ),
                                  );
                                  if (context.mounted) setState(() {});
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}
