part of 'vitality_hub_page.dart';


class _NextSessionCard extends StatelessWidget {
  final List plans;
  final List recentWorkouts;
  const _NextSessionCard({required this.plans, required this.recentWorkouts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (plans.isEmpty) {
      return Card(
        shape: const StadiumBorder(),
        elevation: 3,
        surfaceTintColor: theme.colorScheme.surfaceTint,
        child: ListTile(
          leading: const Icon(Icons.flag),
          title: const Text('No workouts configured'),
          subtitle: const Text('Create a plan to see your next target.'),
        ),
      );
    }
    // Pick the most recently logged exercise if available.
    String? exerciseName;
    double? nextWeight;
    int? nextReps;
    if (recentWorkouts.isNotEmpty) {
      final last = recentWorkouts.first;
      exerciseName = last.exercise?.name;
      final plan = plans.firstWhere(
        (p) => p.id == last.workout?.planId,
        orElse: () => plans.first,
      );
      final state = plan.exercises.firstWhere(
        (s) => s.exerciseId == last.log.exerciseId,
        orElse: () => plan.defaultExerciseState!,
      );
      nextWeight = state.currentWeightKg;
      nextReps = state.expectedReps;
    } else {
      final plan = plans.first;
      final state = plan.defaultExerciseState;
      exerciseName = state?.exerciseId;
      nextWeight = state?.currentWeightKg;
      nextReps = state?.expectedReps;
    }

    final title = exerciseName == null ? 'Next session' : 'Next: $exerciseName';
    final subtitle = nextWeight == null || nextReps == null
        ? 'No exercises configured yet'
        : 'Great work! Next target: ${nextWeight.toStringAsFixed(1)} kg x $nextReps reps.';
    return Card(
      shape: const StadiumBorder(),
      elevation: 3,
      surfaceTintColor: theme.colorScheme.surfaceTint,
      child: ListTile(
        leading: const Icon(Icons.play_arrow),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _StepsChart extends StatelessWidget {
  final Map<String, int> stepsByDay;
  const _StepsChart({required this.stepsByDay});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (stepsByDay.isEmpty) {
      return const _ChartEmptyState(
        icon: Icons.directions_walk,
        headline: 'Start moving to see your trends',
        subhead: 'Sync your steps to unlock insights.',
      );
    }
    final entries = stepsByDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final maxSteps = entries
        .map((e) => e.value.toDouble())
        .fold<double>(0, max)
        .clamp(1, double.infinity);

    List<BarChartGroupData> groups = [];
    for (var i = 0; i < entries.length; i++) {
      final steps = entries[i].value.toDouble();
      final km = steps * 0.0008;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: steps,
              width: 12,
              borderRadius: const BorderRadius.all(Radius.circular(6)),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primaryContainer,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
            BarChartRodData(
              toY: km,
              width: 12,
              borderRadius: const BorderRadius.all(Radius.circular(6)),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.secondary,
                  theme.colorScheme.secondaryContainer,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Steps vs KM (last 7 days)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) => Text(
                          '${(value / 1000).round()}k',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toStringAsFixed(1)} km',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          final label = entries[idx].key.substring(5);
                          return Text(label, style: theme.textTheme.bodySmall);
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  barGroups: groups,
                  maxY: maxSteps * 1.2,
                  groupsSpace: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepChart extends StatelessWidget {
  final Map<String, Duration> sleepByDay;
  const _SleepChart({required this.sleepByDay});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = sleepByDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) {
      return const _ChartEmptyState(
        icon: Icons.bedtime,
        headline: 'Rest fuels progress',
        subhead: 'Log your sleep to see recovery trends.',
      );
    }

    final maxHours = entries
        .map((e) => e.value.inMinutes / 60.0)
        .fold<double>(0, max)
        .clamp(1, double.infinity);

    final bars = <BarChartGroupData>[];
    for (var i = 0; i < entries.length; i++) {
      final hours = entries[i].value.inMinutes / 60.0;
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: hours,
              width: 18,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              rodStackItems: [
                BarChartRodStackItem(0, hours * 0.7, theme.colorScheme.primary),
                BarChartRodStackItem(
                  hours * 0.7,
                  hours,
                  theme.colorScheme.secondary,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sleep (stacked)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toStringAsFixed(0)}h',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          final label = entries[idx].key.substring(5);
                          return Text(label, style: theme.textTheme.bodySmall);
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  barGroups: bars,
                  maxY: maxHours * 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentWorkoutCard extends StatelessWidget {
  final List recentWorkouts;
  const _RecentWorkoutCard({required this.recentWorkouts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text('Recent workouts', style: theme.textTheme.titleMedium),
          ),
          const Divider(height: 1),
          ...recentWorkouts.map((log) {
            final name = log.exercise?.name ?? 'Exercise';
            final performed = DateTime.fromMillisecondsSinceEpoch(
              log.log.performedAt,
            );
            final summary =
                '${log.log.sets} sets x ${log.log.reps} reps x ${log.log.energyKcal.toStringAsFixed(0)} kcal';
            return Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: Text(name),
                  subtitle: Text('${performed.toLocal()} \n$summary'),
                  isThreeLine: true,
                ),
                const Divider(height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _VitalityData {
  final Map<String, int> stepsByDay;
  final Map<String, Duration> sleepByDay;
  final List recentWorkouts;
  final List plans;
  final DateTime fetchedAt;
  final bool hasPermissions;

  _VitalityData({
    required this.stepsByDay,
    required this.sleepByDay,
    required this.recentWorkouts,
    required this.plans,
    required this.fetchedAt,
    required this.hasPermissions,
  });
}

class _LastUpdatedLabel extends StatelessWidget {
  final DateTime timestamp;
  const _LastUpdatedLabel({required this.timestamp});

  String _format(DateTime value) {
    final local = value.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date at $time';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Icon(Icons.access_time, size: 18),
        const SizedBox(width: 6),
        Text(
          'Last updated ${_format(timestamp)}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final Future<void> Function() onRequest;
  const _PermissionBanner({required this.onRequest});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.shield, color: theme.colorScheme.onErrorContainer),
        title: Text(
          'Health permissions needed',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        subtitle: Text(
          'Enable Health Connect to show steps, distance, sleep, and calorie trends.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        trailing: FilledButton.tonal(
          onPressed: () {
            onRequest();
          },
          child: const Text('Grant'),
        ),
      ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  final IconData icon;
  final String headline;
  final String subhead;
  const _ChartEmptyState({
    required this.icon,
    required this.headline,
    required this.subhead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primaryContainer,
              ),
              child: Icon(icon, size: 32, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Text(
              headline,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subhead,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
