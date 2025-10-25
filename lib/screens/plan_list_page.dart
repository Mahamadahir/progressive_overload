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
        title: const Text('Workouts'),
        actions: [
          IconButton(
            tooltip: 'Exercises',
            icon: const Icon(Icons.fitness_center),
            onPressed: () => Navigator.pushNamed(context, '/exercises'),
          ),
          IconButton(
            tooltip: 'Targets',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateWorkoutPage()),
          );
          setState(() {});
        },
        child: const Icon(Icons.add),
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
                return const Center(
                  child: Text('No workouts yet. Tap + to create one.'),
                );
              }

              return ListView.builder(
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  final targets =
                      plan.targetMuscleGroupIds
                          .map((id) => groupMap[id]?.name ?? 'Unknown')
                          .toList()
                        ..sort();
                  final targetLabel = targets.isEmpty
                      ? 'No muscle groups selected'
                      : targets.join(', ');

                  final exerciseCount = plan.exercises.length;
                  final defaultId =
                      plan.defaultExerciseId ??
                      (plan.exercises.isNotEmpty
                          ? plan.exercises.first.exerciseId
                          : null);
                  final defaultName = defaultId == null
                      ? null
                      : exerciseNames[defaultId] ?? 'Exercise';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(plan.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Targets: $targetLabel'),
                          Text(
                            'Exercises: $exerciseCount${defaultName == null ? '' : '  Default: $defaultName'}',
                          ),
                          Text(() {
                            final defaultState = plan.defaultExerciseState;
                            if (defaultState == null) {
                              return 'Next: No exercises configured yet';
                            }
                            return 'Next: ${defaultState.currentWeightKg.toStringAsFixed(1)} kg x ${defaultState.expectedReps} reps - ${defaultState.mets.toStringAsFixed(1)} METs';
                          }()),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                            icon: const Icon(Icons.more_vert),
                          ),
                          IconButton(
                            tooltip: 'Start workout',
                            icon: const Icon(Icons.play_arrow),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SessionPage(planId: plan.id),
                                ),
                              );
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlanDetailPage(planId: plan.id),
                          ),
                        );
                        setState(() {});
                      },
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
