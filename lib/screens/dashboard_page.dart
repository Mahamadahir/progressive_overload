import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:health/health.dart';

import 'package:fitness_app/services/workout_service.dart';
import 'package:fitness_app/services/health_service.dart';
import 'package:fitness_app/services/meal_service.dart';
import 'package:fitness_app/theme_controller.dart';

import 'create_workout_page.dart';
import 'plan_detail_page.dart';
import 'calorie_summary_page.dart';
import 'log_calories_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _workouts = WorkoutService();
  final _meals = MealService();
  final _health = HealthService();

  bool _checking = true;
  bool _authorized = true;
  int _stepsToday = 0;
  int _stepsGoal = 8000;
  double _intakeToday = 0;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _workouts.checkAndNotifyMuscleInactivity();
    });
  }

  Future<void> _load() async {
    final authorized = await HealthService.ensureAuthorized(
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

    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    var steps = 0;
    try {
      final byDay = await _health.getStepsByDayCached(startToday, now);
      steps = byDay.values.fold(0, (sum, v) => sum + v);
    } catch (_) {
      steps = 0;
    }

    if (!mounted) return;
    setState(() {
      _authorized = authorized;
      _stepsToday = steps;
      _stepsGoal = Hive.box('settings').get('steps_goal', defaultValue: 8000) as int;
      _intakeToday = _meals.todayIntakeKcal();
      _checking = false;
    });
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plans = _workouts.getPlans();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Progressive Overload',
          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
        ),
        actions: [
          AnimatedBuilder(
            animation: themeController,
            builder: (context, _) {
              final isDark = themeController.isDarkModeEnabled;
              return IconButton(
                tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                onPressed: themeController.toggle,
                icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
              );
            },
          ),
          IconButton(
            tooltip: 'Targets',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateWorkoutPage()),
          );
          if (mounted) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Start Workout'),
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  Text(
                    _greeting,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Ready to crush your goals today?',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),

                  if (!_authorized) ...[
                    _PermissionAlert(onFix: _load),
                    const SizedBox(height: 16),
                  ],

                  _StepsRingCard(steps: _stepsToday, goal: _stepsGoal),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.restaurant,
                          label: 'Calories today',
                          value: '${_intakeToday.round()}',
                          unit: 'kcal',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.event_note,
                          label: 'Active plans',
                          value: '${plans.length}',
                          unit: plans.length == 1 ? 'plan' : 'plans',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Quick actions',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.restaurant,
                          label: 'Log Nutrition',
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => LogCaloriesPage()),
                            );
                            if (mounted) _load();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.bar_chart,
                          label: 'View Analytics',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CalorieSummaryPage()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Your plans',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (plans.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No plans yet. Tap Start Workout to create one.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    ...plans.map((p) {
                      final state = p.defaultExerciseState;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          title: Text(p.name),
                          subtitle: Text(
                            state == null
                                ? 'No exercises configured yet'
                                : 'Next up: ${state.currentWeightKg.toStringAsFixed(1)} kg '
                                      'x ${state.expectedReps} reps',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlanDetailPage(planId: p.id),
                              ),
                            );
                            if (mounted) _load();
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _StepsRingCard extends StatelessWidget {
  final int steps;
  final int goal;
  const _StepsRingCard({required this.steps, required this.goal});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = goal <= 0 ? 0.0 : (steps / goal).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.directions_walk, color: scheme.primary, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Steps',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$steps',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'of $goal goal',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 64,
              width: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 64,
                    width: 64,
                    child: CircularProgressIndicator(
                      value: fraction,
                      strokeWidth: 6,
                      backgroundColor: scheme.primary.withValues(alpha: 0.12),
                      color: scheme.primary,
                    ),
                  ),
                  Text(
                    '${(fraction * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary, size: 20),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionAlert extends StatelessWidget {
  final VoidCallback onFix;
  const _PermissionAlert({required this.onFix});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Connect permission needed',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Grant access to sync steps, calories, and workouts.',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 8),
                FilledButton(onPressed: onFix, child: const Text('Fix')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
