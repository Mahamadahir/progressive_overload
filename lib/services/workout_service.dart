import 'dart:developer' as developer;

import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/models/workout_log.dart' as wl show WorkoutLog;
import 'package:fitness_app/models/workout_plan.dart' as wp
    show PlanExerciseState, WorkoutPlan;
import 'package:hive/hive.dart';

import 'health_service.dart'; // getLatestWeight(), writeStrengthWorkout()

class WorkoutService {
  // Explicit generic types + aliases
  final Box<wp.WorkoutPlan> _planBox = Hive.box<wp.WorkoutPlan>('plans');
  final Box<wl.WorkoutLog> _logBox = Hive.box<wl.WorkoutLog>('plan_logs');

  List<wp.WorkoutPlan> getPlans() => _planBox.values.toList();

  Future<void> createPlan({
    required String name,
    required List<String> exerciseIds,
    List<String>? targetMuscleGroupIds,
    String? defaultExerciseId,
  }) async {
    final uniqueExerciseIds =
        exerciseIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList();
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
        (targetMuscleGroupIds == null ? groupsFromExercises : targetMuscleGroupIds.toSet())
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
    final uniqueExerciseIds =
        exerciseIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList();
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
        (targetMuscleGroupIds == null ? groupsFromExercises : targetMuscleGroupIds.toSet())
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

    final resolvedDefault =
        (defaultExerciseId != null && uniqueExerciseIds.contains(defaultExerciseId))
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

  /// Compute kcal via METs: (sets*reps*5)/3600 * bodyWeightKg * MET
  Future<double> _estimateEnergyKcal({
    required int sets,
    required int reps,
    double mets = 3.0,
  }) async {
    final bodyWeight = await HealthService.getLatestWeight();
    if (bodyWeight == null) return 0;
    final durationHrs = (sets * reps * 5) / 3600.0;
    return durationHrs * bodyWeight * mets;
  }

  /// Saves the session to Health Connect/Apple Health and updates plan progression
  Future<wl.WorkoutLog> logSession({
    required wp.WorkoutPlan plan,
    required int sets,
    required int achievedReps,
    required bool targetMet,
    double? overrideMets, // optional per-session override
    String? exerciseId,
  }) async {
    final resolvedExerciseId =
        exerciseId ?? plan.defaultExerciseId ?? plan.primaryExercise?.exerciseId;
    if (resolvedExerciseId == null) {
      throw ArgumentError('No exercise available for logging on this plan.');
    }

    final state = plan.exercises.firstWhere(
      (entry) => entry.exerciseId == resolvedExerciseId,
      orElse: () => throw ArgumentError(
        'Exercise $resolvedExerciseId is not assigned to this plan.',
      ),
    );

    // Decide which METs to use (override > per-exercise default)
    final metsUsed = overrideMets ?? state.mets;

    // 1) Estimate calories
    final energy = await _estimateEnergyKcal(
      sets: sets,
      reps: achievedReps,
      mets: metsUsed,
    );

    // 2) Write workout via HealthService helper
    final now = DateTime.now();
    final durationSec = sets * achievedReps * 5;
    final start = now.subtract(Duration(seconds: durationSec));

    await HealthService.writeStrengthWorkout(
      start: start,
      end: now,
      energyKcal: energy.round().toDouble(),
      title: "Plan: ${plan.name}",
    );

    // 3) Save local log
    final performedWeightKg = state.currentWeightKg;
    final log = wl.WorkoutLog(
      planId: plan.id,
      date: now,
      expectedWeightKg: state.currentWeightKg,
      expectedReps: state.expectedReps,
      sets: sets,
      achievedReps: achievedReps,
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
        sets: sets,
        reps: achievedReps,
        weightKg: performedWeightKg,
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
    if (targetMet && achievedReps >= state.maxReps) {
      state.currentWeightKg = state.currentWeightKg + state.incrementKg;
      state.expectedReps = state.minReps; // reset to floor
    } else {
      // stay at same weight; nudge target reps upward (bounded)
      final next = (state.expectedReps + 1).clamp(state.minReps, state.maxReps);
      // clamp returns num; ensure int
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

