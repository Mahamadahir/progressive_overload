import 'package:flutter/material.dart';
import 'package:fitness_app/database/app_database.dart';
import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/repositories/drift_repository.dart';
import 'package:fitness_app/services/workout_service.dart';

import 'create_workout_page.dart';
import 'edit_plan_page.dart';
import 'plan_detail_page.dart';
import 'session_page.dart';

class PlanListPage extends StatefulWidget {
  const PlanListPage({super.key});

  @override
  State<PlanListPage> createState() => _PlanListPageState();
}

class _PlanListPageState extends State<PlanListPage> {
  final WorkoutService _service = WorkoutService();

  Map<String, MuscleGroup> _flattenGroups(List<MuscleGroupNode> nodes) {
    final map = <String, MuscleGroup>{};
    void visit(List<MuscleGroupNode> items) {
      for (final node in items) {
        map[node.group.id] = node.group;
        if (node.children.isNotEmpty) {
          visit(node.children);
        }
      }
    }

    visit(nodes);
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Plans'),
        actions: [
          IconButton(
            tooltip: 'Exercises',
            icon: const Icon(Icons.fitness_center),
            onPressed: () => Navigator.pushNamed(context, '/exercises'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateWorkoutPage()),
          );
          setState(() {});
        },
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
      body: StreamBuilder<List<MuscleGroupNode>>(
        stream: driftRepository.watchMuscleGroupsTree(),
        builder: (context, groupSnapshot) {
          final plans = _service.getPlans();
          final groupMap = _flattenGroups(groupSnapshot.data ?? const []);

          return StreamBuilder<List<ExerciseDetail>>(
            stream: driftRepository.watchExercises(),
            builder: (context, exerciseSnapshot) {
              final exerciseNames = {
                for (final detail in exerciseSnapshot.data ?? const [])
                  detail.exercise.id: detail.exercise.name,
              };

              if (plans.isEmpty) {
                return _EmptyPlans();
              }

              final scheme = Theme.of(context).colorScheme;
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  final targets =
                      plan.targetMuscleGroupIds
                          .map((id) => groupMap[id]?.name ?? 'Unknown')
                          .toList()
                        ..sort();

                  final exerciseCount = plan.exercises.length;
                  final defaultId =
                      plan.defaultExerciseId ??
                      (plan.exercises.isNotEmpty
                          ? plan.exercises.first.exerciseId
                          : null);
                  final defaultName = defaultId == null
                      ? null
                      : exerciseNames[defaultId] ?? 'Exercise';
                  final defaultState = plan.defaultExerciseState;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlanDetailPage(planId: plan.id),
                          ),
                        );
                        setState(() {});
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    plan.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Start workout',
                                  icon: Icon(
                                    Icons.play_circle_fill,
                                    color: scheme.primary,
                                  ),
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SessionPage(planId: plan.id),
                                      ),
                                    );
                                    setState(() {});
                                  },
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              EditPlanPage(planId: plan.id),
                                        ),
                                      );
                                      setState(() {});
                                    } else if (value == 'delete') {
                                      await _service.deletePlan(plan.id);
                                      setState(() {});
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                  icon: const Icon(Icons.more_vert),
                                ),
                              ],
                            ),
                            if (targets.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, right: 8),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: targets
                                      .map(
                                        (t) => Chip(
                                          label: Text(t),
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              '$exerciseCount exercise${exerciseCount == 1 ? '' : 's'}'
                              '${defaultName == null ? '' : '  •  Default: $defaultName'}',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              defaultState == null
                                  ? 'Next: no exercises configured yet'
                                  : 'Next: ${defaultState.currentWeightKg.toStringAsFixed(1)} kg '
                                        'x ${defaultState.expectedReps} reps',
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyPlans extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_note_outlined, size: 56, color: scheme.primary),
          const SizedBox(height: 12),
          const Text('No plans yet'),
          const SizedBox(height: 4),
          Text(
            'Tap New Plan to build your first workout.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
