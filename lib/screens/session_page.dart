// lib/screens/session_page.dart
import 'dart:async';
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

  final TextEditingController _totalSetsCtrl = TextEditingController(text: '3');
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _repsCtrl = TextEditingController();
  final List<ExerciseSetEntry> _recordedSets = [];
  bool _setCountLocked = false;
  int _plannedSetCount = 3;
  bool _targetMet = false;
  double? _overrideMets;
  bool _saving = false;
  String? _result;
  final Map<String, _LoggedExerciseSummary> _completedThisSession = {};
  int _restTimerSeconds = 180;
  int _restSecondsRemaining = 0;
  Timer? _restTimer;

  // permission banner / checks
  bool _checkingPerms = true;
  bool _authorized = true;
  bool _authBusy =
      false; // local UX lock (global guard may be in HealthService)

  // per-session MET override
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

  Future<void> _syncPlanExercisesWithTargets() async {
    if (plan.targetMuscleGroupIds.isEmpty) return;
    final tree = await driftRepository.getMuscleGroupsTree();
    final descendants = <String, Set<String>>{};

    Set<String> visit(MuscleGroupNode node) {
      final ids = <String>{node.group.id};
      for (final child in node.children) {
        ids.addAll(visit(child));
      }
      descendants[node.group.id] = ids;
      return ids;
    }

    for (final node in tree) {
      visit(node);
    }

    final expandedGroupIds = plan.targetMuscleGroupIds
        .expand((id) => descendants[id] ?? <String>{id})
        .toSet();
    if (expandedGroupIds.isEmpty) return;

    final details = await driftRepository.getExercises(
      groupIds: expandedGroupIds.toList(),
    );
    final existing = {for (final state in plan.exercises) state.exerciseId};
    var modified = false;

    for (final detail in details) {
      final exercise = detail.exercise;
      if (existing.contains(exercise.id)) continue;
      plan.exercises.add(
        PlanExerciseState(
          exerciseId: exercise.id,
          startWeightKg: exercise.startWeightKg,
          currentWeightKg: exercise.startWeightKg,
          minReps: exercise.minReps,
          maxReps: exercise.maxReps,
          expectedReps: exercise.minReps,
          incrementKg: exercise.incrementKg,
          mets: exercise.defaultMets,
        ),
      );
      modified = true;
    }

    if (modified) {
      await plan.save();
      _ensureActiveExercise();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _ensureActiveExercise() {
    if (plan.exercises.isEmpty) {
      _activateExercise(null);
      return;
    }
    final incomplete = plan.exercises
        .where((state) => !_completedThisSession.containsKey(state.exerciseId))
        .toList();
    if (_activeExerciseId != null &&
        incomplete.any((s) => s.exerciseId == _activeExerciseId)) {
      return;
    }
    if (incomplete.isEmpty) {
      _activateExercise(null);
      return;
    }
    final preferredId = plan.defaultExerciseId;
    final nextId =
        preferredId != null &&
            incomplete.any((s) => s.exerciseId == preferredId)
        ? preferredId
        : incomplete.first.exerciseId;
    _activateExercise(nextId);
  }

  void _activateExercise(String? exerciseId) {
    _cancelRestTimer();
    final state = exerciseId == null ? null : _stateFor(exerciseId);
    _totalSetsCtrl.text = '3';
    if (state == null) {
      _weightCtrl.clear();
      _repsCtrl.clear();
    } else {
      _weightCtrl.text = state.currentWeightKg.toStringAsFixed(1);
      _repsCtrl.text = state.expectedReps.toString();
    }
    setState(() {
      _activeExerciseId = state == null ? null : exerciseId;
      _recordedSets.clear();
      _setCountLocked = false;
      _plannedSetCount = 3;
      _targetMet = false;
      _overrideMets = null;
      _result = null;
      _restSecondsRemaining = 0;
    });
  }

  void _cancelRestTimer() {
    _restTimer?.cancel();
    _restTimer = null;
    _restSecondsRemaining = 0;
  }

  void _startRestTimer() {
    _cancelRestTimer();
    setState(() {
      _restSecondsRemaining = _restTimerSeconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_restSecondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _restSecondsRemaining = 0;
        });
      } else {
        setState(() {
          _restSecondsRemaining = _restSecondsRemaining - 1;
        });
      }
    });
  }

  void _skipRestTimer() {
    if (_restSecondsRemaining == 0) return;
    setState(() {
      _restSecondsRemaining = 0;
    });
    _cancelRestTimer();
  }

  String _formatRestTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _saveCurrentSet(PlanExerciseState state) {
    if (_restSecondsRemaining > 0) {
      setState(() {
        _result = 'Rest timer is running. Tap Skip to continue.';
      });
      return;
    }
    final plannedSets = int.tryParse(_totalSetsCtrl.text.trim());
    if (plannedSets == null || plannedSets <= 0) {
      setState(() => _result = 'Sets must be greater than 0.');
      return;
    }
    final reps = int.tryParse(_repsCtrl.text.trim());
    if (reps == null || reps <= 0) {
      setState(() => _result = 'Reps must be greater than 0.');
      return;
    }
    final weight = double.tryParse(_weightCtrl.text.trim());
    if (weight == null || weight < 0) {
      setState(() => _result = 'Weight must be >= 0.');
      return;
    }
    if (_recordedSets.length >= plannedSets) {
      setState(() => _result = 'All sets already saved.');
      return;
    }
    _plannedSetCount = plannedSets;
    _setCountLocked = true;
    final nextCount = _recordedSets.length + 1;
    final isFinalSet = nextCount >= _plannedSetCount;
    setState(() {
      _recordedSets.add(ExerciseSetEntry(reps: reps, weightKg: weight));
      _result = isFinalSet
          ? 'All sets saved. Tap "Complete exercise" to log.'
          : 'Saved set $nextCount of $_plannedSetCount. Rest started.';
    });
    _repsCtrl.clear();
    if (isFinalSet) {
      _cancelRestTimer();
    } else {
      _startRestTimer();
    }
  }

  Future<void> _completeExercise({
    required PlanExerciseState state,
    required String exerciseName,
  }) async {
    if (_recordedSets.isEmpty) {
      setState(() => _result = 'Log at least one set before completing.');
      return;
    }
    if (_recordedSets.length != _plannedSetCount) {
      setState(() => _result = 'Complete all $_plannedSetCount set(s) first.');
      return;
    }
    _cancelRestTimer();
    setState(() {
      _saving = true;
      _result = null;
    });
    final setsToLog = List<ExerciseSetEntry>.from(_recordedSets);
    try {
      final log = await service.logExercise(
        plan: plan,
        exerciseId: state.exerciseId,
        exerciseName: exerciseName,
        sets: setsToLog,
        targetMet: _targetMet,
        overrideMets: _overrideMets,
      );
      final refreshedPlan = Hive.box<WorkoutPlan>('plans').get(plan.id)!;
      final summary = _LoggedExerciseSummary(
        exerciseId: state.exerciseId,
        name: exerciseName,
        sets: setsToLog,
        targetMet: _targetMet,
        energyKcal: log.energyKcal,
        loggedAt: log.date,
        metsUsed: log.metsUsed,
      );
      setState(() {
        plan = refreshedPlan;
        _completedThisSession[state.exerciseId] = summary;
        _result =
            'Logged $exerciseName - ${log.energyKcal.toStringAsFixed(1)} kcal';
      });
      _activateExercise(null);
      _ensureActiveExercise();
    } catch (e) {
      setState(() => _result = 'Error: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    plan = Hive.box<WorkoutPlan>('plans').get(widget.planId)!;
    final settings = Hive.box('settings');
    _restTimerSeconds =
        (settings.get('rest_timer_seconds', defaultValue: 180) as num).toInt();
    _ensureActiveExercise();
    Future.microtask(_syncPlanExercisesWithTargets);
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

  @override
  void dispose() {
    _restTimer?.cancel();
    _totalSetsCtrl.dispose();
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
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
          for (final detail in snapshot.data ?? const <ExerciseDetail>[])
            detail.exercise.id: detail,
        };
        final activeState = _activeState;
        final activeName = activeState == null
            ? null
            : details[activeState.exerciseId]?.exercise.name ?? 'Exercise';
        final incompleteStates = plan.exercises
            .where(
              (state) => !_completedThisSession.containsKey(state.exerciseId),
            )
            .toList();
        final loggingState =
            activeState != null &&
                !_completedThisSession.containsKey(activeState.exerciseId)
            ? activeState
            : null;

        return Scaffold(
          appBar: AppBar(title: Text(plan.name)),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                if (_saving || _checkingPerms) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                ],
                if (!_authorized) _buildPermissionBanner(context),
                if (_completedThisSession.isNotEmpty)
                  _buildCompletedSummaryCard(context),
                if (plan.exercises.isEmpty)
                  _buildNoExercisesMessage(context)
                else
                  _buildExerciseList(
                    context: context,
                    details: details,
                    incompleteStates: incompleteStates,
                    activeState: activeState,
                  ),
                if (loggingState != null)
                  _buildLoggingCard(
                    context: context,
                    state: loggingState,
                    exerciseName: activeName ?? 'Exercise',
                    detail: details[loggingState.exerciseId],
                  )
                else if (plan.exercises.isNotEmpty)
                  _buildAllDoneMessage(context),
                if (_result != null) ...[
                  const SizedBox(height: 12),
                  Text(_result!, style: Theme.of(context).textTheme.bodyLarge),
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
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPermissionBanner(BuildContext context) {
    return Container(
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
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text('Tap Fix to request or re-enable permissions.'),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _authBusy
                        ? null
                        : () async {
                            await _fixPermissions();
                            if (mounted) {
                              await _checkPermissions();
                            }
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
    );
  }

  Widget _buildCompletedSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final summaries = _completedThisSession.values.toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Completed this session',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < summaries.length; i++) ...[
              _buildCompletedSummaryTile(theme, summaries[i]),
              if (i != summaries.length - 1) const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedSummaryTile(
    ThemeData theme,
    _LoggedExerciseSummary summary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(summary.name, style: theme.textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "${summary.totalSets} set${summary.totalSets == 1 ? '' : 's'} - "
          "${summary.totalReps} reps - Last set ${summary.lastWeight.toStringAsFixed(1)} kg - "
          "${summary.energyKcal.toStringAsFixed(1)} kcal",
          style: theme.textTheme.bodyMedium,
        ),
        Text(
          "Target ${summary.targetMet ? 'met' : 'missed'} - ${summary.metsUsed.toStringAsFixed(1)} METs",
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: summary.sets.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final set = entry.value;
            return Chip(
              label: Text(
                'Set $index: ${set.weightKg.toStringAsFixed(1)} kg x ${set.reps}',
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExerciseList({
    required BuildContext context,
    required Map<String, ExerciseDetail> details,
    required List<PlanExerciseState> incompleteStates,
    required PlanExerciseState? activeState,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exercises',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Each exercise can be logged once per session.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (incompleteStates.isEmpty)
              const Text('All exercises have been logged for this session.')
            else
              for (var i = 0; i < incompleteStates.length; i++) ...[
                Builder(
                  builder: (context) {
                    final state = incompleteStates[i];
                    final name =
                        details[state.exerciseId]?.exercise.name ?? 'Exercise';
                    final info =
                        '${state.currentWeightKg.toStringAsFixed(1)} kg x ${state.expectedReps} reps - ${state.mets.toStringAsFixed(1)} METs';
                    final isActive =
                        activeState?.exerciseId == state.exerciseId;
                    return ListTile(
                      title: Text(name),
                      subtitle: Text(info),
                      selected: isActive,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _saving
                          ? null
                          : () => _activateExercise(state.exerciseId),
                    );
                  },
                ),
                if (i != incompleteStates.length - 1) const Divider(height: 1),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoggingCard({
    required BuildContext context,
    required PlanExerciseState state,
    required String exerciseName,
    ExerciseDetail? detail,
  }) {
    final theme = Theme.of(context);
    final groupNames = detail == null
        ? <String>[]
        : (detail.groups.map((g) => g.name).toList()..sort());
    final metLabel = state.mets.toStringAsFixed(1);
    final canSaveSet = !_saving && _restSecondsRemaining == 0;
    final canComplete =
        !_saving &&
        _authorized &&
        _recordedSets.isNotEmpty &&
        _recordedSets.length == _plannedSetCount &&
        _plannedSetCount > 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Log $exerciseName', style: theme.textTheme.titleMedium),
            if (groupNames.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(groupNames.join(', '), style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Text(
              'Target: ${state.currentWeightKg.toStringAsFixed(1)} kg x ${state.expectedReps} reps - $metLabel METs',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _totalSetsCtrl,
                    readOnly: _setCountLocked || _saving,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Total sets',
                      helperText: _setCountLocked
                          ? 'Locked after first set'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _weightCtrl,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _repsCtrl,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reps for this set'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Did you meet your target?'),
              value: _targetMet,
              onChanged: _saving
                  ? null
                  : (v) {
                      setState(() {
                        _targetMet = v;
                        if (v && _recordedSets.isEmpty) {
                          _repsCtrl.text = state.expectedReps.toString();
                        }
                      });
                    },
            ),
            const SizedBox(height: 12),
            const Text('Intensity override (optional)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _metOptions.map((m) {
                final selected = _overrideMets == m;
                final label = m == null
                    ? 'Use exercise default ($metLabel METs)'
                    : '${_labels[m]!} (${m.toStringAsFixed(1)})';
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: _saving
                      ? null
                      : (_) => setState(() => _overrideMets = m),
                );
              }).toList(),
            ),
            if (_recordedSets.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Recorded sets'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _recordedSets.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final set = entry.value;
                  return Chip(
                    label: Text(
                      'Set $index: ${set.weightKg.toStringAsFixed(1)} kg x ${set.reps}',
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            if (_restSecondsRemaining > 0)
              Row(
                children: [
                  Chip(
                    label: Text(
                      'Rest ${_formatRestTime(_restSecondsRemaining)}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _saving ? null : _skipRestTimer,
                    child: const Text('Skip'),
                  ),
                ],
              )
            else
              Text(
                'Rest timer: ${_restTimerSeconds ~/ 60} min',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: canSaveSet ? () => _saveCurrentSet(state) : null,
                    child: const Text('Save set'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: canComplete
                        ? () => _completeExercise(
                            state: state,
                            exerciseName: exerciseName,
                          )
                        : null,
                    child: const Text('Complete exercise'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllDoneMessage(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'All exercises are logged for this session. Great work!',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _buildNoExercisesMessage(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No exercises assigned to this workout. Edit the plan to add exercises.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _LoggedExerciseSummary {
  final String exerciseId;
  final String name;
  final List<ExerciseSetEntry> sets;
  final bool targetMet;
  final double energyKcal;
  final DateTime loggedAt;
  final double metsUsed;

  _LoggedExerciseSummary({
    required this.exerciseId,
    required this.name,
    required this.sets,
    required this.targetMet,
    required this.energyKcal,
    required this.loggedAt,
    required this.metsUsed,
  });

  int get totalSets => sets.length;
  int get totalReps => sets.fold<int>(0, (sum, entry) => sum + entry.reps);
  double get lastWeight => sets.isEmpty ? 0 : sets.last.weightKg;
}
