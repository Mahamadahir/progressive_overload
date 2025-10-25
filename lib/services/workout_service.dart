import 'dart:developer' as developer;

import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/models/workout_log.dart' as wl show WorkoutLog;
import 'package:fitness_app/models/workout_plan.dart'
    as wp
    show PlanExerciseState, WorkoutPlan;
import 'package:hive/hive.dart';

import 'package:fitness_app/repositories/drift_repository.dart';
import 'health_service.dart'; // getLatestWeight(), writeStrengthWorkout()
import 'notification_service.dart';

class ExerciseSetEntry {
  final int reps;
  final double weightKg;
  const ExerciseSetEntry({required this.reps, required this.weightKg});
}

class WorkoutService {
  // Explicit generic types + aliases
  final Box<wp.WorkoutPlan> _planBox = Hive.box<wp.WorkoutPlan>('plans');
  final Box<wl.WorkoutLog> _logBox = Hive.box<wl.WorkoutLog>('plan_logs');

  List<wp.WorkoutPlan> getPlans() => _planBox.values.toList();

  Future<void> checkAndNotifyMuscleInactivity({
    Duration threshold = const Duration(days: 4),
  }) async {
    final plans = getPlans();
    if (plans.isEmpty) return;

    final targetGroups = <String>{};
    final groupPlanCreatedAt = <String, DateTime>{};
    for (final plan in plans) {
      for (final groupId in plan.targetMuscleGroupIds) {
        targetGroups.add(groupId);
        final existing = groupPlanCreatedAt[groupId];
        if (existing == null || plan.createdAt.isBefore(existing)) {
          groupPlanCreatedAt[groupId] = plan.createdAt;
        }
      }
    }
    if (targetGroups.isEmpty) return;

    final tree = await driftRepository.getMuscleGroupsTree();
    final descendantsByGroup = <String, Set<String>>{};
    final nameByGroup = <String, String>{};

    Set<String> visit(MuscleGroupNode node) {
      nameByGroup[node.group.id] = node.group.name;
      final descendants = <String>{node.group.id};
      for (final child in node.children) {
        descendants.addAll(visit(child));
      }
      descendantsByGroup[node.group.id] = descendants;
      return descendants;
    }

    for (final node in tree) {
      visit(node);
    }

    final scopeGroupIds = targetGroups
        .expand(
          (id) =>
              descendantsByGroup[id] ??
              (nameByGroup.containsKey(id) ? <String>{id} : const <String>{}),
        )
        .toSet()
        .toList();

    final lastPerf = await driftRepository.lastPerformedAtByMuscleGroup(
      groupIds: scopeGroupIds.isEmpty ? null : scopeGroupIds,
    );

    final settings = Hive.box('settings');
    final stored = Map<String, dynamic>.from(
      settings.get('inactivity_notified_at', defaultValue: const {}) as Map,
    );

    final now = DateTime.now();
    var updated = false;

    for (final groupId in targetGroups) {
      final allIds = descendantsByGroup[groupId] ?? <String>{groupId};
      DateTime? latest;
      for (final id in allIds) {
        final candidate = lastPerf[id];
        if (candidate != null &&
            (latest == null || candidate.isAfter(latest))) {
          latest = candidate;
        }
      }

      final fallback = groupPlanCreatedAt[groupId];
      if (fallback == null) {
        continue;
      }
      final reference = latest ?? fallback;
      final duration = now.difference(reference);
      if (duration < threshold) {
        continue;
      }

      final lastNotifiedMillis = stored[groupId] as int?;
      final lastNotified = lastNotifiedMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastNotifiedMillis);
      final shouldNotify =
          lastNotified == null ||
          now.difference(lastNotified) >= threshold ||
          (latest != null && lastNotified.isBefore(latest));
      if (!shouldNotify) {
        continue;
      }

      final name = nameByGroup[groupId] ?? 'a target muscle';
      final notificationId = 5000 + (groupId.hashCode & 0x7fffffff);
      await NotificationService.showNow(
        id: notificationId,
        title: 'Time to train $name',
        body:
            "It's been ${duration.inDays} day${duration.inDays == 1 ? '' : 's'} since your last $name session. Let's schedule one!",
      );
      stored[groupId] = now.millisecondsSinceEpoch;
      updated = true;
    }

    if (updated) {
      await settings.put('inactivity_notified_at', stored);
    }
  }

  Future<void> createPlan({
    required String name,
    required List<String> exerciseIds,
    List<String>? targetMuscleGroupIds,
    String? defaultExerciseId,
  }) async {
    final uniqueExerciseIds = exerciseIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueExerciseIds.isEmpty) {
      throw ArgumentError('exerciseIds cannot be empty');
    }

    final states = <wp.PlanExerciseState>[];
    final groupsFromExercises = <String>{};
    for (final id in uniqueExerciseIds) {
      final detail = await driftRepository.getExercise(id);
      final exercise = detail?.exercise;
      if (detail == null || exercise == null) {
        throw ArgumentError('Exercise $id not found');
      }
      for (final group in detail.groups) {
        groupsFromExercises.add(group.id);
      }
      states.add(
        wp.PlanExerciseState(
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
    }

    if (states.isEmpty) {
      throw ArgumentError('Unable to build plan without exercises');
    }

    final primaryState = states.first;
    final sanitizedGroups =
        (targetMuscleGroupIds == null
                ? groupsFromExercises
                : targetMuscleGroupIds.toSet())
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

    final plan = wp.WorkoutPlan(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      currentWeightKg: primaryState.currentWeightKg,
      minReps: primaryState.minReps,
      maxReps: primaryState.maxReps,
      incrementKg: primaryState.incrementKg,
      expectedReps: primaryState.expectedReps,
      mets: primaryState.mets,
      targetMuscleGroupIds: sanitizedGroups,
      defaultExerciseId: defaultExerciseId ?? primaryState.exerciseId,
      exercises: states,
    );

    await _planBox.put(plan.id, plan);

    try {
      await driftRepository.createWorkout(name: name, planId: plan.id);
    } catch (e, st) {
      developer.log(
        'Failed to create Drift workout for plan ${plan.id}: $e',
        name: 'WorkoutService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> updatePlan({
    required wp.WorkoutPlan plan,
    required String name,
    required List<String> exerciseIds,
    List<String>? targetMuscleGroupIds,
    String? defaultExerciseId,
  }) async {
    final uniqueExerciseIds = exerciseIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueExerciseIds.isEmpty) {
      throw ArgumentError('exerciseIds cannot be empty');
    }

    final existingStates = {
      for (final state in plan.exercises) state.exerciseId: state,
    };

    final states = <wp.PlanExerciseState>[];
    final groupsFromExercises = <String>{};

    for (final id in uniqueExerciseIds) {
      final existing = existingStates[id];
      if (existing != null) {
        states.add(existing);
        final detail = await driftRepository.getExercise(id);
        if (detail != null) {
          for (final group in detail.groups) {
            groupsFromExercises.add(group.id);
          }
        }
        continue;
      }

      final detail = await driftRepository.getExercise(id);
      final exercise = detail?.exercise;
      if (detail == null || exercise == null) {
        throw ArgumentError('Exercise  not found');
      }
      for (final group in detail.groups) {
        groupsFromExercises.add(group.id);
      }
      states.add(
        wp.PlanExerciseState(
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
    }

    final sanitizedGroups =
        (targetMuscleGroupIds == null
                ? groupsFromExercises
                : targetMuscleGroupIds.toSet())
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

    final resolvedDefault =
        (defaultExerciseId != null &&
            uniqueExerciseIds.contains(defaultExerciseId))
        ? defaultExerciseId
        : uniqueExerciseIds.first;

    plan
      ..name = name
      ..exercises = List<wp.PlanExerciseState>.from(states)
      ..targetMuscleGroupIds = sanitizedGroups
      ..defaultExerciseId = resolvedDefault;

    if (plan.exercises.isNotEmpty) {
      final primaryState = plan.exercises.firstWhere(
        (state) => state.exerciseId == resolvedDefault,
        orElse: () => plan.exercises.first,
      );
      plan.updatePrimaryFromState(primaryState);
    }

    await plan.save();
    await driftRepository.ensureWorkoutForPlan(plan.id, name: plan.name);
  }

  Future<void> deletePlan(String id) async {
    try {
      await driftRepository.deleteWorkoutForPlan(id);
    } catch (e, st) {
      developer.log(
        'Failed to delete Drift workout for plan $id: $e',
        name: 'WorkoutService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    await _planBox.delete(id);
  }

  /// Compute kcal via METs using time under tension.
  Future<double> _estimateEnergyKcal({
    required int sets,
    required int totalReps,
    double mets = 3.0,
  }) async {
    final bodyWeight = await HealthService.getLatestWeight();
    if (bodyWeight == null) return 0;
    final minutesUnderTension = totalReps * 5 / 60.0;
    final kcal = mets * 3.5 * bodyWeight / 200.0 * minutesUnderTension;
    return kcal;
  }

  /// Saves the exercise to Health Connect/Apple Health and updates plan progression
  Future<wl.WorkoutLog> logExercise({
    required wp.WorkoutPlan plan,
    required String exerciseId,
    required String exerciseName,
    required List<ExerciseSetEntry> sets,
    required bool targetMet,
    double? overrideMets, // optional per-session override
  }) async {
    if (sets.isEmpty) {
      throw ArgumentError('At least one set is required.');
    }

    final totalSets = sets.length;
    final totalReps = sets.fold<int>(0, (sum, entry) => sum + entry.reps);
    if (totalSets <= 0 || totalReps <= 0) {
      throw ArgumentError('Sets and reps must be greater than zero.');
    }
    if (sets.any((entry) => entry.weightKg.isNaN || entry.weightKg < 0)) {
      throw ArgumentError('Weight must be >= 0 for all sets.');
    }

    final state = plan.exercises.firstWhere(
      (entry) => entry.exerciseId == exerciseId,
      orElse: () => throw ArgumentError(
        'Exercise $exerciseId is not assigned to this plan.',
      ),
    );

    // Decide which METs to use (override > per-exercise default)
    final metsUsed = overrideMets ?? state.mets;

    // 1) Estimate calories
    final energy = await _estimateEnergyKcal(
      sets: totalSets,
      totalReps: totalReps,
      mets: metsUsed,
    );

    // 2) Write workout via HealthService helper
    final now = DateTime.now();
    final durationSec = totalReps * 5;
    final start = now.subtract(Duration(seconds: durationSec));

    await HealthService.writeStrengthWorkout(
      start: start,
      end: now,
      energyKcal: energy.round().toDouble(),
      title: exerciseName,
    );

    // 3) Save local log
    final avgReps = (totalReps / totalSets)
        .ceil(); // preserve legacy per-set expectation
    final lastWeight = sets.last.weightKg;
    final log = wl.WorkoutLog(
      planId: plan.id,
      date: now,
      expectedWeightKg: state.currentWeightKg,
      expectedReps: state.expectedReps,
      sets: totalSets,
      achievedReps: avgReps,
      targetMet: targetMet,
      energyKcal: energy,
      metsUsed: metsUsed, // record what we actually used
    );
    await _logBox.add(log);

    // 3b) Ensure Drift workout + log for analytics
    try {
      final driftWorkout = await driftRepository.ensureWorkoutForPlan(
        plan.id,
        name: plan.name,
      );
      await driftRepository.logWorkout(
        workoutId: driftWorkout.id,
        exerciseId: state.exerciseId,
        sets: totalSets,
        reps: totalReps,
        weightKg: lastWeight,
        energyKcal: energy,
        metsUsed: metsUsed,
        performedAt: now,
      );
    } catch (e, st) {
      developer.log(
        'Failed to log workout in Drift for plan ${plan.id}: $e',
        name: 'WorkoutService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    // 4) Update plan progression
    state.currentWeightKg = lastWeight;
    if (targetMet && sets.last.reps >= state.maxReps) {
      state.currentWeightKg = lastWeight + state.incrementKg;
      state.expectedReps = state.minReps; // reset to floor
    } else {
      // stay at same weight; nudge target reps upward (bounded)
      final next = (state.expectedReps + 1)
          .clamp(state.minReps, state.maxReps)
          .toInt();
      state.expectedReps = next;
    }

    if (plan.primaryExercise?.exerciseId == state.exerciseId ||
        plan.defaultExerciseId == state.exerciseId) {
      plan.updatePrimaryFromState(state);
    }
    await plan.save();

    return log;
  }

  List<wl.WorkoutLog> getLogsForPlan(String planId) =>
      _logBox.values
          .whereType<wl.WorkoutLog>() // guards against any null/dynamic entries
          .where((l) => l.planId == planId)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
}
