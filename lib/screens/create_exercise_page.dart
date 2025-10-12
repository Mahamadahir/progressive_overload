import 'package:flutter/material.dart';

import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/database/app_database.dart';
import 'package:fitness_app/repositories/drift_repository.dart';

class CreateExercisePage extends StatefulWidget {
  const CreateExercisePage({super.key, this.exerciseId});

  final String? exerciseId;

  @override
  State<CreateExercisePage> createState() => _CreateExercisePageState();
}

class _CreateExercisePageState extends State<CreateExercisePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _startWeightCtrl = TextEditingController();
  final _minRepsCtrl = TextEditingController(text: '6');
  final _maxRepsCtrl = TextEditingController(text: '12');
  final _incrementCtrl = TextEditingController(text: '2.0');
  double _defaultMets = 3.0;
  final List<double> _metOptions = const [2.5, 3.0, 5.0];
  final Map<double, String> _metLabels = const {
    2.5: 'Light',
    3.0: 'Moderate',
    5.0: 'Vigorous',
  };
  final Set<String> _selectedGroupIds = <String>{};

  bool _saving = false;
  bool _loadingExisting = false;

  bool get _isEditing => widget.exerciseId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadExercise();
    }
  }

  Future<void> _loadExercise() async {
    setState(() => _loadingExisting = true);
    final detail = await driftRepository.getExercise(widget.exerciseId!);
    if (detail == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Exercise not found.')));
      Navigator.pop(context);
      return;
    }

    _nameCtrl.text = detail.exercise.name;
    _notesCtrl.text = detail.exercise.notes ?? '';
    _startWeightCtrl.text = detail.exercise.startWeightKg.toStringAsFixed(1);
    _minRepsCtrl.text = detail.exercise.minReps.toString();
    _maxRepsCtrl.text = detail.exercise.maxReps.toString();
    _incrementCtrl.text = detail.exercise.incrementKg.toStringAsFixed(1);
    _defaultMets = detail.exercise.defaultMets;
    _selectedGroupIds
      ..clear()
      ..addAll(detail.groups.map((g) => g.id));

    if (mounted) {
      setState(() => _loadingExisting = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    _startWeightCtrl.dispose();
    _minRepsCtrl.dispose();
    _maxRepsCtrl.dispose();
    _incrementCtrl.dispose();
    super.dispose();
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

    setState(() => _saving = true);

    try {
      final name = _nameCtrl.text.trim();
      final notes = _notesCtrl.text.trim();
      final groupIds = _selectedGroupIds.toList(growable: false);
      final startWeight = double.parse(_startWeightCtrl.text.trim());
      final minReps = int.parse(_minRepsCtrl.text.trim());
      final maxReps = int.parse(_maxRepsCtrl.text.trim());
      final increment = double.parse(_incrementCtrl.text.trim());
      final defaultMets = _defaultMets;

      if (_isEditing) {
        await driftRepository.updateExercise(
          id: widget.exerciseId!,
          name: name,
          notes: notes.isEmpty ? null : notes,
          groupIds: groupIds,
          startWeightKg: startWeight,
          minReps: minReps,
          maxReps: maxReps,
          incrementKg: increment,
          defaultMets: defaultMets,
        );
      } else {
        await driftRepository.createExercise(
          name: name,
          notes: notes.isEmpty ? null : notes,
          groupIds: groupIds,
          startWeightKg: startWeight,
          minReps: minReps,
          maxReps: maxReps,
          incrementKg: increment,
          defaultMets: defaultMets,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } on RepositoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save exercise: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadingExisting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Exercise' : 'Create Exercise'),
      ),
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
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Exercise name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Progression defaults',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _startWeightCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Starting weight (kg)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        final trimmed = value?.trim();
                        final parsed = double.tryParse(trimmed ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a starting weight (> 0)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minRepsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Min reps',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final parsed =
                                  int.tryParse(value?.trim() ?? '');
                              if (parsed == null || parsed <= 0) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _maxRepsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Max reps',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final parsed =
                                  int.tryParse(value?.trim() ?? '');
                              if (parsed == null || parsed <= 0) {
                                return 'Required';
                              }
                              final min =
                                  int.tryParse(_minRepsCtrl.text.trim());
                              if (min != null && parsed < min) {
                                return 'Must be ≥ min reps';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _incrementCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Increment (kg)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Enter an increment (> 0)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Default intensity (METs)',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _metOptions.map((met) {
                        final selected = _defaultMets == met;
                        return ChoiceChip(
                          label: Text(
                            '${_metLabels[met]} (${met.toStringAsFixed(1)})',
                          ),
                          selected: selected,
                          onSelected: (_) => setState(() {
                            _defaultMets = met;
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text('Muscle group(s)', style: theme.textTheme.titleSmall),
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
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: Text(
                        _isEditing ? 'Save changes' : 'Create exercise',
                      ),
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
