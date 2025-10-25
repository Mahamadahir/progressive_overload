// lib/screens/session_page.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/models/workout_plan.dart';
import 'package:fitness_app/repositories/drift_repository.dart';

import 'exercise_log_page.dart';
import 'health_connect_diagnostics_page.dart';

class SessionPage extends StatefulWidget {
  final String planId;
  const SessionPage({super.key, required this.planId});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  WorkoutPlan? _plan;

  final Map<String, LoggedExerciseSummary> _completedThisSession =
      <String, LoggedExerciseSummary>{};

  bool _checkingPerms = true;
  bool _authorized = true;
  bool _authBusy = false;

  @override
  void initState() {
    super.initState();
    _plan = Hive.box<WorkoutPlan>('plans').get(widget.planId);
    Future.microtask(() async {
      await _syncPlanExercisesWithTargets();
      await _checkPermissions();
    });
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _checkingPerms = true;
      _authorized = false;
    });

    try {
      final ok = await HealthConnectDiagnosticsHelper.checkPermissionsPassive();
      setState(() => _authorized = ok);
    } catch (_) {
      setState(() => _authorized = false);
    } finally {
      if (mounted) {
        setState(() => _checkingPerms = false);
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

  Future<void> _syncPlanExercisesWithTargets() async {
    final plan = _plan;
    if (plan == null || plan.targetMuscleGroupIds.isEmpty) return;

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
      if (mounted) {
        setState(() {
          _plan = Hive.box<WorkoutPlan>('plans').get(plan.id);
        });
      }
    }
  }

  Future<void> _refreshPlan() async {
    setState(() {
      _plan = Hive.box<WorkoutPlan>('plans').get(widget.planId);
    });
  }

  Future<void> _openExerciseLog(
    PlanExerciseState state,
    ExerciseDetail? detail,
  ) async {
    if (!_authorized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health Connect permissions required to log.'),
          ),
        );
      }
      return;
    }
    final summary = await Navigator.push<LoggedExerciseSummary>(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseLogPage(
          planId: widget.planId,
          exerciseId: state.exerciseId,
        ),
      ),
    );
    await _refreshPlan();
    if (!mounted) return;
    if (summary != null) {
      setState(() {
        _completedThisSession[state.exerciseId] = summary;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    if (plan == null) {
      return const Scaffold(body: Center(child: Text('Workout not found.')));
    }

    return StreamBuilder<List<ExerciseDetail>>(
      stream: driftRepository.watchExercises(),
      builder: (context, snapshot) {
        final details = {
          for (final detail in snapshot.data ?? const <ExerciseDetail>[])
            detail.exercise.id: detail,
        };
        final incompleteExercises = plan.exercises
            .where(
              (state) => !_completedThisSession.containsKey(state.exerciseId),
            )
            .toList();

        return Scaffold(
          appBar: AppBar(title: Text(plan.name)),
          body: _checkingPerms
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      if (!_authorized) _buildPermissionBanner(),
                      if (_completedThisSession.isNotEmpty)
                        _buildCompletedSummaryCard(),
                      StreamBuilder<List<MuscleGroupNode>>(
                        stream: driftRepository.watchMuscleGroupsTree(),
                        builder: (context, groupSnapshot) {
                          final labels = _resolveTargetLabels(
                            plan,
                            groupSnapshot.data ?? const [],
                          );
                          if (labels.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: labels
                                  .map((name) => Chip(label: Text(name)))
                                  .toList(),
                            ),
                          );
                        },
                      ),
                      _buildExercisesCard(
                        context: context,
                        plan: plan,
                        incompleteStates: incompleteExercises,
                        details: details,
                      ),
                      const SizedBox(height: 24),
                      if (incompleteExercises.isEmpty)
                        _buildAllDoneMessage(context),
                    ],
                  ),
                ),
        );
      },
    );
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

  Widget _buildExercisesCard({
    required BuildContext context,
    required WorkoutPlan plan,
    required List<PlanExerciseState> incompleteStates,
    required Map<String, ExerciseDetail> details,
  }) {
    final theme = Theme.of(context);
    return Card(
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
                _buildExerciseTile(
                  plan,
                  incompleteStates[i],
                  details[incompleteStates[i].exerciseId],
                ),
                if (i != incompleteStates.length - 1) const Divider(height: 16),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseTile(
    WorkoutPlan plan,
    PlanExerciseState state,
    ExerciseDetail? detail,
  ) {
    final exerciseName = detail?.exercise.name ?? 'Exercise';
    final info =
        '${state.currentWeightKg.toStringAsFixed(1)} kg x ${state.expectedReps} reps - '
        '${state.mets.toStringAsFixed(1)} METs';
    final groupNames = detail?.groups.map((g) => g.name).join(', ');

    return ListTile(
      title: Text(exerciseName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(info),
          if (groupNames != null && groupNames.isNotEmpty)
            Text(groupNames, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openExerciseLog(state, detail),
    );
  }

  Widget _buildCompletedSummaryCard() {
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
    LoggedExerciseSummary summary,
  ) {
    final totalSets = summary.sets.length;
    final totalReps = summary.sets.fold<int>(
      0,
      (sum, entry) => sum + entry.reps,
    );
    final lastWeight = summary.sets.isEmpty
        ? 0
        : summary.sets.last.weightKg.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                summary.exerciseName,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$totalSets set${totalSets == 1 ? '' : 's'} - '
          '$totalReps reps - '
          'Last set ${lastWeight.toStringAsFixed(1)} kg - '
          '${summary.energyKcal.toStringAsFixed(1)} kcal',
          style: theme.textTheme.bodyMedium,
        ),
        Text(
          'Target ${summary.targetMet ? 'met' : 'missed'} - '
          '${summary.metsUsed.toStringAsFixed(1)} METs',
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
                'Set $index: ${set.weightKg.toStringAsFixed(1)} kg × ${set.reps}',
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAllDoneMessage(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'All exercises are logged for this session. Great work!',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }

  List<String> _resolveTargetLabels(
    WorkoutPlan plan,
    List<MuscleGroupNode> nodes,
  ) {
    if (plan.targetMuscleGroupIds.isEmpty) return const [];
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
            .map((id) => map[id])
            .whereType<String>()
            .toList()
          ..sort();
    return labels;
  }
}
