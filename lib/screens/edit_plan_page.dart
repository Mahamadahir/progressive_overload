import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:fitness_app/database/app_database.dart';
import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/models/workout_plan.dart';
import 'package:fitness_app/repositories/drift_repository.dart';
import 'package:fitness_app/services/workout_service.dart';

class EditPlanPage extends StatefulWidget {
  const EditPlanPage({super.key, required this.planId});

  final String planId;

  @override
  State<EditPlanPage> createState() => _EditPlanPageState();
}

class _EditPlanPageState extends State<EditPlanPage> {
  late WorkoutPlan plan;
  final WorkoutService _service = WorkoutService();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final Set<String> _selectedGroupIds = <String>{};
  final Set<String> _selectedExerciseIds = <String>{};
  String? _defaultExerciseId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    plan = Hive.box<WorkoutPlan>('plans').get(widget.planId)!;
    _nameCtrl.text = plan.name;
    _selectedGroupIds.addAll(plan.targetMuscleGroupIds);
    _selectedExerciseIds
        .addAll(plan.exercises.map((state) => state.exerciseId));
    _defaultExerciseId = plan.defaultExerciseId ??
        (plan.exercises.isNotEmpty ? plan.exercises.first.exerciseId : null);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String? _resolveDefaultExerciseId() {
    if (_defaultExerciseId != null &&
        _selectedExerciseIds.contains(_defaultExerciseId)) {
      return _defaultExerciseId;
    }
    return _selectedExerciseIds.isEmpty ? null : _selectedExerciseIds.first;
  }

  List<_SelectableGroup> _flattenGroups(
    List<MuscleGroupNode> nodes, {
    int depth = 0,
  }) {
    final result = <_SelectableGroup>[];
    for (final node in nodes) {
      result.add(_SelectableGroup(node.group, depth));
      result.addAll(_flattenGroups(node.children, depth: depth + 1));
    }
    return result;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedExerciseIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one exercise')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _service.updatePlan(
        plan: plan,
        name: _nameCtrl.text.trim(),
        exerciseIds: _selectedExerciseIds.toList(growable: false),
        targetMuscleGroupIds: _selectedGroupIds.toList(growable: false),
        defaultExerciseId: _resolveDefaultExerciseId(),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } on RepositoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save changes: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Workout')),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Workout name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Target muscle group(s)',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    FormField<Set<String>>(
                      validator: (_) => _selectedGroupIds.isEmpty
                          ? 'Select at least one muscle group'
                          : null,
                      builder: (field) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StreamBuilder<List<MuscleGroupNode>>(
                              stream: driftRepository.watchMuscleGroupsTree(),
                              builder: (context, snapshot) {
                                final groups = snapshot.data ?? const [];
                                if (groups.isEmpty) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'No muscle groups available.',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pushNamed(
                                          context,
                                          '/settings',
                                        ),
                                        child: const Text(
                                          'Manage muscle groups',
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                final flattened = _flattenGroups(groups);
                                return Column(
                                  children: flattened.map((item) {
                                    final selected = _selectedGroupIds.contains(
                                      item.group.id,
                                    );
                                    return CheckboxListTile(
                                      value: selected,
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked ?? false) {
                                            _selectedGroupIds.add(
                                              item.group.id,
                                            );
                                          } else {
                                            _selectedGroupIds.remove(
                                              item.group.id,
                                            );
                                          }
                                        });
                                        field.didChange(_selectedGroupIds);
                                      },
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.only(
                                        left: item.depth * 16.0,
                                      ),
                                      title: Text(item.group.name),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                            if (field.hasError)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  field.errorText!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    StreamBuilder<List<ExerciseDetail>>(
                      stream: driftRepository.watchExercises(),
                      builder: (context, snapshot) {
                        final exercises = snapshot.data ?? const [];
                        if (exercises.isEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Exercises',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Create an exercise to link detailed logs.',
                                style: theme.textTheme.bodySmall,
                              ),
                              TextButton.icon(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  '/exercises/new',
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('Create exercise'),
                              ),
                            ],
                          );
                        }

                        final existingStates = {
                          for (final state in plan.exercises)
                            state.exerciseId: state,
                        };

                        return FormField<Set<String>>(
                          validator: (_) => _selectedExerciseIds.isEmpty
                              ? 'Select at least one exercise'
                              : null,
                          builder: (field) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Exercises',
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                ...exercises.map((detail) {
                                  final exercise = detail.exercise;
                                  final id = exercise.id;
                                  final checked =
                                      _selectedExerciseIds.contains(id);
                                  final state = existingStates[id];
                                  final groupNames = detail.groups
                                      .map((g) => g.name)
                                      .join(', ');
                                  final secondary = state == null
                                      ? 'Start ${exercise.startWeightKg.toStringAsFixed(1)} kg · ${exercise.minReps}-${exercise.maxReps} reps · ${exercise.incrementKg.toStringAsFixed(1)} kg inc'
                                      : 'Current ${state.currentWeightKg.toStringAsFixed(1)} kg · target ${state.expectedReps} reps · ${state.incrementKg.toStringAsFixed(1)} kg inc';
                                  return CheckboxListTile(
                                    value: checked,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value ?? false) {
                                          _selectedExerciseIds.add(id);
                                        } else {
                                          _selectedExerciseIds.remove(id);
                                        }
                                        _defaultExerciseId =
                                            _resolveDefaultExerciseId();
                                      });
                                      field.didChange(_selectedExerciseIds);
                                    },
                                    title: Text(exercise.name),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(secondary),
                                        if (groupNames.isNotEmpty)
                                          Text(
                                            groupNames,
                                            style:
                                                theme.textTheme.bodySmall,
                                          ),
                                      ],
                                    ),
                                  );
                                }),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      '/exercises/new',
                                    ),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Create exercise'),
                                  ),
                                ),
                                if (_selectedExerciseIds.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    initialValue: _resolveDefaultExerciseId(),
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Default exercise',
                                    ),
                                    items: _selectedExerciseIds
                                        .map(
                                          (id) => DropdownMenuItem<String>(
                                            value: id,
                                            child: Text(
                                              exercises
                                                  .firstWhere(
                                                    (detail) =>
                                                        detail.exercise.id ==
                                                        id,
                                                  )
                                                  .exercise
                                                  .name,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setState(
                                        () => _defaultExerciseId = value,
                                      );
                                    },
                                  ),
                                ],
                                if (field.hasError)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      field.errorText!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('Save changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SelectableGroup {
  final MuscleGroup group;
  final int depth;

  _SelectableGroup(this.group, this.depth);
}












