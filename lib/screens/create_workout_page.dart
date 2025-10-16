import 'package:flutter/material.dart';

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
  final Set<String> _expandedGroupIds = <String>{};
  Map<String, Set<String>> _descendantsByGroup = {};
  Map<String, Set<String>> _groupToExerciseIds = {};

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

  String? _resolveDefaultExerciseId() {
    if (_defaultExerciseId != null &&
        _selectedExerciseIds.contains(_defaultExerciseId)) {
      return _defaultExerciseId;
    }
    return _selectedExerciseIds.isEmpty ? null : _selectedExerciseIds.first;
  }

  Map<String, Set<String>> _computeDescendants(List<MuscleGroupNode> nodes) {
    final map = <String, Set<String>>{};
    void visit(MuscleGroupNode node) {
      final ids = <String>{node.group.id};
      for (final child in node.children) {
        visit(child);
        ids.addAll(map[child.group.id] ?? <String>{child.group.id});
      }
      map[node.group.id] = ids;
    }

    for (final node in nodes) {
      visit(node);
    }
    return map;
  }

  Set<String> _descendantsFor(String groupId) =>
      _descendantsByGroup[groupId] ?? <String>{groupId};

  void _onGroupToggle(String groupId, bool selected) {
    setState(() {
      if (selected) {
        _selectedGroupIds.add(groupId);
        final autoIds = _descendantsFor(
          groupId,
        ).expand((id) => _groupToExerciseIds[id] ?? const <String>{});
        _selectedExerciseIds.addAll(autoIds);
      } else {
        _selectedGroupIds.remove(groupId);
        final removalCandidates = _descendantsFor(
          groupId,
        ).expand((id) => _groupToExerciseIds[id] ?? const <String>{}).toSet();
        if (removalCandidates.isNotEmpty) {
          final remainingGroups = _selectedGroupIds
              .expand((id) => _descendantsFor(id))
              .toSet();
          final protected = remainingGroups
              .expand((id) => _groupToExerciseIds[id] ?? const <String>{})
              .toSet();
          removalCandidates.removeWhere(protected.contains);
          _selectedExerciseIds.removeAll(removalCandidates);
        }
      }
      _defaultExerciseId = _resolveDefaultExerciseId();
    });
  }

  List<Widget> _buildGroupSelector(
    List<MuscleGroupNode> nodes,
    FormFieldState<Set<String>> field, {
    int depth = 0,
  }) {
    final tiles = <Widget>[];
    for (final node in nodes) {
      final id = node.group.id;
      final selected = _selectedGroupIds.contains(id);
      final hasChildren = node.children.isNotEmpty;
      final expanded = _expandedGroupIds.contains(id);
      tiles.add(
        Card(
          margin: EdgeInsets.only(left: depth * 12.0, bottom: 6),
          child: Column(
            children: [
              ListTile(
                leading: Checkbox(
                  value: selected,
                  onChanged: (value) {
                    _onGroupToggle(id, value ?? false);
                    field.didChange(_selectedGroupIds);
                  },
                ),
                title: Text(node.group.name),
                onTap: hasChildren
                    ? () => setState(() {
                        if (expanded) {
                          _expandedGroupIds.remove(id);
                        } else {
                          _expandedGroupIds.add(id);
                        }
                      })
                    : null,
                trailing: hasChildren
                    ? IconButton(
                        icon: Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                        ),
                        onPressed: () => setState(() {
                          if (expanded) {
                            _expandedGroupIds.remove(id);
                          } else {
                            _expandedGroupIds.add(id);
                          }
                        }),
                      )
                    : null,
              ),
              if (hasChildren && expanded)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 8),
                  child: Column(
                    children: _buildGroupSelector(
                      node.children,
                      field,
                      depth: depth + 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return tiles;
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
                                _descendantsByGroup = _computeDescendants(
                                  groups,
                                );

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _buildGroupSelector(groups, field),
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

                        _groupToExerciseIds = {};
                        for (final detail in exercises) {
                          for (final group in detail.groups) {
                            _groupToExerciseIds
                                .putIfAbsent(group.id, () => <String>{})
                                .add(detail.exercise.id);
                          }
                        }
                        if (_selectedGroupIds.isNotEmpty &&
                            _groupToExerciseIds.isNotEmpty) {
                          final autoIds = _selectedGroupIds
                              .expand((id) => _descendantsFor(id))
                              .expand(
                                (id) =>
                                    _groupToExerciseIds[id] ?? const <String>{},
                              )
                              .toSet();
                          final missing = autoIds
                              .where((id) => !_selectedExerciseIds.contains(id))
                              .toSet();
                          if (missing.isNotEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              setState(() {
                                _selectedExerciseIds.addAll(missing);
                                _defaultExerciseId =
                                    _resolveDefaultExerciseId();
                              });
                            });
                          }
                        }

                        final byId = {
                          for (final detail in exercises)
                            detail.exercise.id: detail,
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
                                  final checked = _selectedExerciseIds.contains(
                                    id,
                                  );
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
                                            style: theme.textTheme.bodySmall,
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
