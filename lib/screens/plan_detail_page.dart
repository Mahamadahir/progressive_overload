import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/models/workout_plan.dart';
import 'package:fitness_app/repositories/drift_repository.dart';
import 'package:fitness_app/services/workout_service.dart';
import 'edit_plan_page.dart';
import 'plan_charts_page.dart';
import 'session_page.dart';

class PlanDetailPage extends StatefulWidget {
  final String planId;
  const PlanDetailPage({super.key, required this.planId});

  @override
  State<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends State<PlanDetailPage> {
  final service = WorkoutService();
  late WorkoutPlan plan;

  @override
  void initState() {
    super.initState();
    plan = Hive.box<WorkoutPlan>('plans').get(widget.planId)!;
  }

  @override
  Widget build(BuildContext context) {
    final logs = service.getLogsForPlan(plan.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(plan.name),
        actions: [
          IconButton(
            tooltip: 'Edit workout',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditPlanPage(planId: plan.id),
                ),
              );
              if (!mounted) return;
              setState(() {
                plan = Hive.box<WorkoutPlan>('plans').get(widget.planId)!;
              });
            },
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            tooltip: 'Delete workout',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete workout?'),
                  content: const Text(
                    'This removes the workout (logs remain). Continue?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await service.deletePlan(plan.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.delete),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SessionPage(planId: plan.id)),
          );
          if (!mounted) return;
          setState(() {
            plan = Hive.box<WorkoutPlan>('plans').get(widget.planId)!;
          });
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start workout'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<List<MuscleGroupNode>>(
            stream: driftRepository.watchMuscleGroupsTree(),
            builder: (context, snapshot) {
              final nodes = snapshot.data ?? const [];
              final map = <String, String>{};
              void visit(List<MuscleGroupNode> items) {
                for (final node in items) {
                  map[node.group.id] = node.group.name;
                  if (node.children.isNotEmpty) {
                    visit(node.children);
                  }
                }
              }

              visit(nodes);
              final targets =
                  plan.targetMuscleGroupIds
                      .map((id) => map[id] ?? 'Unknown')
                      .toList()
                    ..sort();
              final label = targets.isEmpty
                  ? 'No muscle groups selected'
                  : targets.join(', ');

              return Card(
                child: ListTile(
                  title: const Text('Target muscle group(s)'),
                  subtitle: Text(label),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<ExerciseDetail>>(
            stream: driftRepository.watchExercises(),
            builder: (context, snapshot) {
              final details = {
                for (final detail in snapshot.data ?? const [])
                  detail.exercise.id: detail,
              };

              final tiles = <Widget>[];
              if (plan.exercises.isEmpty) {
                tiles.add(
                  const ListTile(
                    title: Text('Exercises'),
                    subtitle: Text('No exercises linked to this workout.'),
                  ),
                );
              } else {
                tiles.add(const ListTile(title: Text('Exercises')));
                tiles.add(const Divider(height: 1));
                for (var i = 0; i < plan.exercises.length; i++) {
                  final state = plan.exercises[i];
                  final detail = details[state.exerciseId];
                  final name = detail?.exercise.name ?? 'Exercise';
                  final groupNames = detail?.groups
                      .map((g) => g.name)
                      .join(', ');
                  final info =
                      'Start: ${state.startWeightKg.toStringAsFixed(1)} kg  '
                      'Current: ${state.currentWeightKg.toStringAsFixed(1)} kg  '
                      'Reps: ${state.minReps}-${state.maxReps} (target ${state.expectedReps})  '
                      'Increment: ${state.incrementKg.toStringAsFixed(1)} kg  '
                      'METs: ${state.mets.toStringAsFixed(1)}';
                  tiles.add(
                    ListTile(
                      title: Text(name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(info),
                          if (groupNames != null && groupNames.isNotEmpty)
                            Text(
                              groupNames,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  );
                  if (i != plan.exercises.length - 1) {
                    tiles.add(const Divider(height: 1));
                  }
                }
              }

              final defaultId =
                  plan.defaultExerciseId ??
                  (plan.exercises.isNotEmpty
                      ? plan.exercises.first.exerciseId
                      : null);
              final defaultName = defaultId == null
                  ? null
                  : details[defaultId]?.exercise.name ?? 'Exercise';
              final defaultState = plan.defaultExerciseState;

              tiles.add(const Divider(height: 1));
              tiles.add(
                ListTile(
                  title: const Text('Next up'),
                  subtitle: Text(() {
                    final parts = <String>[];
                    if (defaultName != null) {
                      parts.add('Exercise: $defaultName');
                    }
                    if (defaultState != null) {
                      parts.add(
                        'Weight: ${defaultState.currentWeightKg.toStringAsFixed(1)} kg',
                      );
                      parts.add(
                        'Reps: ${defaultState.expectedReps} (min ${defaultState.minReps}-${defaultState.maxReps})',
                      );
                      parts.add(
                        'Increment: ${defaultState.incrementKg.toStringAsFixed(1)} kg',
                      );
                      parts.add(
                        'METs: ${defaultState.mets.toStringAsFixed(1)}',
                      );
                    } else {
                      parts.add('No exercises configured yet');
                    }
                    return parts.join(' - ');
                  }()),
                ),
              );

              return Card(child: Column(children: tiles));
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlanChartsPage(planId: plan.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.show_chart),
                  label: const Text('Charts'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionPage(planId: plan.id),
                      ),
                    );
                    if (!mounted) return;
                    setState(() {
                      plan = Hive.box<WorkoutPlan>('plans').get(widget.planId)!;
                    });
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start workout'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Recent sessions',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (logs.isEmpty)
            const Text('No sessions yet.')
          else
            ...logs
                .take(10)
                .map(
                  (l) => Card(
                    child: ListTile(
                      title: Text(
                        "${l.date.toLocal()}  ${l.expectedWeightKg.toStringAsFixed(1)}kg x ${l.expectedReps} (exp)",
                      ),
                      subtitle: Text(
                        "Sets ${l.sets}, Reps ${l.achievedReps}, Target ${l.targetMet ? "met" : "missed"}, "
                        "Energy ${l.energyKcal.toStringAsFixed(0)} kcal, ${l.metsUsed.toStringAsFixed(1)} METs",
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
