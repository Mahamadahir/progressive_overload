import 'package:flutter/material.dart';

import 'package:fitness_app/database/app_database.dart';
import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/repositories/drift_repository.dart';
import 'package:fitness_app/services/workout_service.dart';

class CreateWorkoutPage extends StatefulWidget {
  const CreateWorkoutPage({super.key});

  @override
  State<CreateWorkoutPage> createState() => _CreateWorkoutPageState();
}

class _CreateWorkoutPageState extends State<CreateWorkoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _service = WorkoutService();

  final Set<String> _selectedGroupIds = <String>{};
  final Set<String> _selectedExerciseIds = <String>{};
  String? _defaultExerciseId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    try {
      await _service.createPlan(
        name: _nameCtrl.text.trim(),
        exerciseIds: _selectedExerciseIds.toList(growable: false),
        targetMuscleGroupIds: _selectedGroupIds.isEmpty
            ? null
            : _selectedGroupIds.toList(growable: false),
        defaultExerciseId: _resolveDefaultExerciseId(),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create workout: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
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

  String? _resolveDefaultExerciseId() {
    if (_defaultExerciseId != null &&
        _selectedExerciseIds.contains(_defaultExerciseId)) {
      return _defaultExerciseId;
    }
    return _selectedExerciseIds.isEmpty ? null : _selectedExerciseIds.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Workout')),
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
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Workout name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
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
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: CircularProgressIndicator.adaptive(),
                                  );
                                }
                                final groups = snapshot.data ?? const [];
                                if (groups.isEmpty) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'No muscle groups available yet.',
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
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/settings'),
                                icon: const Icon(Icons.settings),
                                label: const Text('Manage muscle groups'),
                              ),
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

                          final byId = {
                            for (final detail in exercises)
                              detail.exercise.id: detail
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
                                    final groupNames = detail.groups
                                        .map((g) => g.name)
                                        .join(' � ');
                                    final secondary = [
                                      'Start ${exercise.startWeightKg.toStringAsFixed(1)} kg',
                                      '${exercise.minReps}-${exercise.maxReps} reps',
                                      '${exercise.incrementKg.toStringAsFixed(1)} kg inc',
                                    ].join(' � ');
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
                                              style: theme
                                                  .textTheme.bodySmall,
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
                                            byId[id]?.exercise.name ?? id,
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
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
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
                      icon: const Icon(Icons.check),
                      label: const Text('Create workout'),
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


