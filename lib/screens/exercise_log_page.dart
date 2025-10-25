import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/models/workout_plan.dart';
import 'package:fitness_app/repositories/drift_repository.dart';
import 'package:fitness_app/services/workout_service.dart';
import 'health_connect_diagnostics_page.dart';

class LoggedExerciseSummary {
  final String exerciseId;
  final String exerciseName;
  final String workoutName;
  final List<ExerciseSetEntry> sets;
  final bool targetMet;
  final double energyKcal;
  final DateTime loggedAt;
  final double metsUsed;

  LoggedExerciseSummary({
    required this.exerciseId,
    required this.exerciseName,
    required this.workoutName,
    required this.sets,
    required this.targetMet,
    required this.energyKcal,
    required this.loggedAt,
    required this.metsUsed,
  });
}

class ExerciseLogPage extends StatefulWidget {
  final String planId;
  final String exerciseId;

  const ExerciseLogPage({
    super.key,
    required this.planId,
    required this.exerciseId,
  });

  @override
  State<ExerciseLogPage> createState() => _ExerciseLogPageState();
}

class _ExerciseLogPageState extends State<ExerciseLogPage> {
  final WorkoutService _service = WorkoutService();

  WorkoutPlan? _plan;
  PlanExerciseState? _state;
  ExerciseDetail? _detail;

  final TextEditingController _totalSetsCtrl = TextEditingController(text: '3');
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _repsCtrl = TextEditingController();

  final List<ExerciseSetEntry> _recordedSets = <ExerciseSetEntry>[];
  bool _setCountLocked = false;
  int _plannedSetCount = 3;
  bool _targetMet = false;
  double? _overrideMets;
  bool _saving = false;
  String? _result;

  bool _checkingPerms = true;
  bool _authorized = true;
  bool _authBusy = false;

  int _restTimerSeconds = 180;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plan = Hive.box<WorkoutPlan>('plans').get(widget.planId);
    if (plan == null) {
      setState(() {
        _result = 'Workout not found.';
        _plan = null;
        _state = null;
      });
      return;
    }
    final state = plan.exercises.firstWhere(
      (entry) => entry.exerciseId == widget.exerciseId,
      orElse: () => throw ArgumentError(
        'Exercise ${widget.exerciseId} not assigned to plan ${plan.id}.',
      ),
    );

    final detail = await driftRepository.getExercise(state.exerciseId);

    final settings = Hive.box('settings');
    final restSeconds =
        (settings.get('rest_timer_seconds', defaultValue: 180) as num).toInt();

    setState(() {
      _plan = plan;
      _state = state;
      _detail = detail;
      _weightCtrl.text = state.currentWeightKg.toStringAsFixed(1);
      _repsCtrl.text = state.expectedReps.toString();
      _restTimerSeconds = restSeconds;
    });

    await _checkPermissions();
  }

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
      setState(() {
        _authorized = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingPerms = false;
        });
      }
    }
  }

  Future<void> _fixPermissions() async {
    if (_authBusy) return;
    setState(() => _authBusy = true);
    try {
      final ok =
          await HealthConnectDiagnosticsHelper.requestPermissionsSerial();
      if (mounted) {
        setState(() => _authorized = ok);
      }
    } finally {
      if (mounted) {
        setState(() => _authBusy = false);
      }
    }
  }

  @override
  void dispose() {
    _totalSetsCtrl.dispose();
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  Future<void> _startRestTimer() async {
    if (_restTimerSeconds <= 0) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            RestTimerScreen(initialSeconds: _restTimerSeconds),
      ),
    );
  }

  void _saveCurrentSet() {
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

    if (!isFinalSet) {
      _startRestTimer();
    }
  }

  Future<void> _completeExercise() async {
    final state = _state;
    final plan = _plan;
    if (state == null || plan == null) return;
    if (_recordedSets.isEmpty) {
      setState(() => _result = 'Log at least one set before completing.');
      return;
    }
    if (_recordedSets.length != _plannedSetCount) {
      setState(() => _result = 'Complete all $_plannedSetCount set(s) first.');
      return;
    }
    setState(() {
      _saving = true;
      _result = null;
    });

    final setsToLog = List<ExerciseSetEntry>.from(_recordedSets);

    try {
      final log = await _service.logExercise(
        plan: plan,
        exerciseId: state.exerciseId,
        exerciseName: _detail?.exercise.name ?? 'Exercise',
        sets: setsToLog,
        targetMet: _targetMet,
        overrideMets: _overrideMets,
      );
      final refreshedPlan = Hive.box<WorkoutPlan>('plans').get(plan.id)!;
      final summary = LoggedExerciseSummary(
        exerciseId: state.exerciseId,
        exerciseName: _detail?.exercise.name ?? 'Exercise',
        workoutName: refreshedPlan.name,
        sets: setsToLog,
        targetMet: _targetMet,
        energyKcal: log.energyKcal,
        loggedAt: log.date,
        metsUsed: log.metsUsed,
      );
      if (!mounted) return;
      Navigator.pop(context, summary);
    } catch (e) {
      setState(() => _result = 'Error: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final detail = _detail;
    final theme = Theme.of(context);
    final exerciseName = detail?.exercise.name ?? 'Exercise';
    final groupNames = detail == null
        ? <String>[]
        : (detail.groups.map((g) => g.name).toList()..sort());

    return Scaffold(
      appBar: AppBar(title: Text('Log $exerciseName')),
      body: state == null || _checkingPerms
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  if (!_authorized) _buildPermissionBanner(),
                  if (groupNames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: groupNames
                            .map((name) => Chip(label: Text(name)))
                            .toList(),
                      ),
                    ),
                  Text(
                    'Target: ${state.currentWeightKg.toStringAsFixed(1)} kg × ${state.expectedReps} reps - ${state.mets.toStringAsFixed(1)} METs',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
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
                                : '',
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
                          decoration: const InputDecoration(
                            labelText: 'Weight (kg)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _repsCtrl,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Reps for this set',
                    ),
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
                  Wrap(spacing: 8, children: _buildMetChips(state)),
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
                            'Set $index: ${set.weightKg.toStringAsFixed(1)} kg × ${set.reps}',
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : _saveCurrentSet,
                          child: const Text('Save set'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _saving ? null : _completeExercise,
                          child: const Text('Complete exercise'),
                        ),
                      ),
                    ],
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    Text(_result!, style: theme.textTheme.bodyLarge),
                  ],
                ],
              ),
            ),
    );
  }

  List<Widget> _buildMetChips(PlanExerciseState state) {
    final options = [null, 2.5, 3.0, 5.0];
    final labels = {2.5: 'Light', 3.0: 'Moderate', 5.0: 'Vigorous'};
    final defaultMets = state.mets.toStringAsFixed(1);
    return options.map((value) {
      final selected = _overrideMets == value;
      final text = value == null
          ? 'Use exercise default ($defaultMets METs)'
          : '${labels[value]!} (${value.toStringAsFixed(1)})';
      return ChoiceChip(
        label: Text(text),
        selected: selected,
        onSelected: _saving
            ? null
            : (_) => setState(() => _overrideMets = value),
      );
    }).toList();
  }

  Widget _buildPermissionBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                    onPressed: _authBusy ? null : _fixPermissions,
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
}

class RestTimerScreen extends StatefulWidget {
  final int initialSeconds;

  const RestTimerScreen({super.key, required this.initialSeconds});

  @override
  State<RestTimerScreen> createState() => _RestTimerScreenState();
}

class _RestTimerScreenState extends State<RestTimerScreen> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.initialSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() => _remaining = _remaining - 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Rest',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _format(_remaining),
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Skip'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
