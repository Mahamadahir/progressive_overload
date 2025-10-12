// lib/screens/session_page.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/models/workout_plan.dart';
import 'package:fitness_app/repositories/drift_repository.dart';
import 'package:fitness_app/services/workout_service.dart';
import 'health_connect_diagnostics_page.dart'; // centralized permission helpers

class SessionPage extends StatefulWidget {
  final String planId;
  const SessionPage({super.key, required this.planId});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  final service = WorkoutService();
  late WorkoutPlan plan;
  String? _activeExerciseId;

  final _setsCtrl = TextEditingController(text: '3');
  final _achievedRepsCtrl = TextEditingController();
  bool _targetMet = false;
  bool _saving = false;
  String? _result;

  // permission banner / checks
  bool _checkingPerms = true;
  bool _authorized = true;
  bool _authBusy =
      false; // local UX lock (global guard may be in HealthService)

  // per-session MET override
  double? _overrideMets;
  final List<double?> _metOptions = [null, 2.5, 3.0, 5.0];
  final Map<double, String> _labels = {
    2.5: 'Light',
    3.0: 'Moderate',
    5.0: 'Vigorous',
  };

  PlanExerciseState? _stateFor(String? exerciseId) {
    if (exerciseId == null) return null;
    for (final state in plan.exercises) {
      if (state.exerciseId == exerciseId) {
        return state;
      }
    }
    return null;
  }

  PlanExerciseState? get _activeState {
    final explicit = _stateFor(_activeExerciseId);
    if (explicit != null) return explicit;
    return plan.exercises.isEmpty ? null : plan.exercises.first;
  }

  void _ensureActiveExercise() {
    if (plan.exercises.isEmpty) {
      _activeExerciseId = null;
      return;
    }
    if (_activeExerciseId != null &&
        plan.exercises.any((s) => s.exerciseId == _activeExerciseId)) {
      return;
    }
    _activeExerciseId =
        plan.defaultExerciseId ?? plan.exercises.first.exerciseId;
  }

  @override
  void initState() {
    super.initState();
    plan = Hive.box<WorkoutPlan>('plans').get(widget.planId)!;
    _ensureActiveExercise();
    _checkPermissions(); // passive check (no prompts)
  }

  /// Passive check: Delegated to HealthConnectDiagnostics helper (no UI prompts).
  Future<void> _checkPermissions() async {
    setState(() {
      _checkingPerms = true;
      _authorized = false;
    });

    try {
      final ok = await HealthConnectDiagnosticsHelper.checkPermissionsPassive();
      setState(() {
        _authorized = ok;
      });
    } catch (_) {
      setState(() => _authorized = false);
    } finally {
      setState(() => _checkingPerms = false);
    }
  }

  /// Active fix: Request permissions via centralized diagnostics helper to avoid races.
  Future<void> _fixPermissions() async {
    if (_authBusy) return;
    setState(() => _authBusy = true);
    try {
      final ok =
          await HealthConnectDiagnosticsHelper.requestPermissionsSerial();
      setState(() => _authorized = ok);
    } finally {
      setState(() => _authBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExerciseDetail>>(
      stream: driftRepository.watchExercises(),
      builder: (context, snapshot) {
        final details = {
          for (final detail in snapshot.data ?? const [])
            detail.exercise.id: detail,
        };
        final activeState = _activeState;
        final defaultMets = activeState?.mets ?? plan.mets;
        final expectedWeight =
            activeState?.currentWeightKg ?? plan.currentWeightKg;
        final expectedReps =
            activeState?.expectedReps ?? plan.expectedReps;
        final activeName = activeState == null
            ? null
            : details[activeState.exerciseId]?.exercise.name;
        final canLog = _authorized && activeState != null;

        return Scaffold(
          appBar: AppBar(title: Text(plan.name)),
          body: _saving || _checkingPerms
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      if (!_authorized)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Health Connect permissions needed',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Tap Fix to request or re-enable permissions.',
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton(
                                        onPressed: _authBusy
                                            ? null
                                            : () async {
                                                await _fixPermissions();
                                                await _checkPermissions(); // re-evaluate silently
                                              },
                                        child: _authBusy
                                            ? const Text('Requesting...')
                                            : const Text('Fix'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (plan.exercises.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'No exercises assigned to this workout. Edit the plan to add exercises.',
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: DropdownButtonFormField<String>(
                            value: activeState?.exerciseId,
                            decoration: const InputDecoration(
                              labelText: 'Exercise',
                            ),
                            items: plan.exercises
                                .map(
                                  (state) => DropdownMenuItem<String>(
                                    value: state.exerciseId,
                                    child: Text(
                                      details[state.exerciseId]?.exercise.name ??
                                          'Exercise',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _activeExerciseId = value;
                              });
                            },
                          ),
                        ),
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
                          final labels =
                              plan.targetMuscleGroupIds
                                  .map((id) => map[id] ?? 'Unknown')
                                  .toList()
                                ..sort();

                          if (labels.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Target muscle group(s)',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: labels
                                      .map(
                                        (name) => Chip(
                                          label: Text(name),
                                          visualDensity:
                                              VisualDensity.compact,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (activeName != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Logging: $activeName',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      const Text(
                        'Expected',
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Weight: ${expectedWeight.toStringAsFixed(1)} kg'),
                      Text('Reps (per set): $expectedReps'),
                      Text(
                        'Exercise intensity: ${defaultMets.toStringAsFixed(1)} METs',
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text(
                        'Achieved',
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _setsCtrl,
                        decoration: const InputDecoration(labelText: 'Sets'),
                        keyboardType: TextInputType.number,
                      ),
                      TextField(
                        controller: _achievedRepsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Reps per set (achieved)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Did you meet your target?'),
                        value: _targetMet,
                        onChanged: (v) => setState(() => _targetMet = v),
                      ),
                      const SizedBox(height: 16),
                      const Text('Intensity override (optional)'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _metOptions.map((m) {
                          final selected = _overrideMets == m;
                          final label = m == null
                              ? 'Use exercise default (${defaultMets.toStringAsFixed(1)} METs)'
                              : '${_labels[m]!} (${m.toStringAsFixed(1)})';
                          return ChoiceChip(
                            label: Text(label),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _overrideMets = m),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: !canLog
                            ? null
                            : () async {
                                final sets = int.tryParse(_setsCtrl.text) ?? 0;
                                final reps =
                                    int.tryParse(_achievedRepsCtrl.text) ?? 0;
                                if (sets <= 0 || reps <= 0) {
                                  setState(
                                    () => _result =
                                        'Enter valid sets/reps.',
                                  );
                                  return;
                                }
                                setState(() {
                                  _saving = true;
                                  _result = null;
                                });
                                try {
                                  final log = await service.logSession(
                                    plan: plan,
                                    sets: sets,
                                    achievedReps: reps,
                                    targetMet: _targetMet,
                                    overrideMets: _overrideMets,
                                    exerciseId: activeState!.exerciseId,
                                  );
                                  final refreshedPlan =
                                      Hive.box<WorkoutPlan>('plans')
                                          .get(plan.id)!;
                                  setState(() {
                                    plan = refreshedPlan;
                                    _ensureActiveExercise();
                                    final updatedState =
                                        _stateFor(activeState.exerciseId);
                                    final nextWeight =
                                        updatedState?.currentWeightKg ??
                                        plan.currentWeightKg;
                                    final nextReps =
                                        updatedState?.expectedReps ??
                                        plan.expectedReps;
                                    _result =
                                        'Saved!\nEnergy: ${log.energyKcal.toStringAsFixed(1)} kcal\nNext: ${nextWeight.toStringAsFixed(1)} kg x $nextReps reps';
                                  });
                                } catch (e) {
                                  setState(() => _result = 'Error: $e');
                                } finally {
                                  setState(() => _saving = false);
                                }
                              },
                        child: const Text(
                          'Save session (writes to Health Connect)',
                        ),
                      ),
                      if (_result != null) ...[
                        const SizedBox(height: 16),
                        Text(_result!, style: const TextStyle(fontSize: 16)),
                      ],
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () async {
                          final logs = service.getLogsForPlan(plan.id);
                          await showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Recent Sessions'),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: logs.length,
                                  itemBuilder: (_, i) {
                                    final l = logs[i];
                                    return ListTile(
                                      title: Text(
                                        '${l.date.toLocal()} | ${l.expectedWeightKg.toStringAsFixed(1)}kg x ${l.expectedReps} (exp)',
                                      ),
                                      subtitle: Text(
                                        'Sets ${l.sets}, Reps ${l.achievedReps}, TargetMet ${l.targetMet ? "Yes" : "No"}, '
                                        '${l.energyKcal.toStringAsFixed(0)} kcal, ${l.metsUsed.toStringAsFixed(1)} METs',
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                        child: const Text('View local session logs'),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}





