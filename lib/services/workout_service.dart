import 'package:hive/hive.dart';

// Alias imports to avoid the WorkoutLog name clash
import 'package:fitness_app/models/workout_plan.dart' as wp show WorkoutPlan;
import 'package:fitness_app/models/workout_log.dart' as wl show WorkoutLog;

import 'health_service.dart'; // getLatestWeight(), writeStrengthWorkout()

class WorkoutService {
  // Explicit generic types + aliases
  final Box<wp.WorkoutPlan> _planBox = Hive.box<wp.WorkoutPlan>('plans');
  final Box<wl.WorkoutLog> _logBox = Hive.box<wl.WorkoutLog>('plan_logs');

  List<wp.WorkoutPlan> getPlans() => _planBox.values.toList();

  Future<void> createPlan({
    required String name,
    required double startWeightKg,
    int minReps = 6,
    int maxReps = 12,
    double incrementKg = 2.0,
    double? defaultMets,
    @Deprecated('Use defaultMets instead') double? mets,
  }) async {
    final resolvedMets = defaultMets ?? mets ?? 3.0;

    final plan = wp.WorkoutPlan(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      currentWeightKg: startWeightKg,
      minReps: minReps,
      maxReps: maxReps,
      incrementKg: incrementKg,
      mets: resolvedMets,
    );

    await _planBox.put(plan.id, plan);
  }

  Future<void> deletePlan(String id) async => _planBox.delete(id);

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
  }) async {
    // Decide which METs to use (override > plan default)
    final metsUsed = overrideMets ?? plan.mets;

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
    final log = wl.WorkoutLog(
      planId: plan.id,
      date: now,
      expectedWeightKg: plan.currentWeightKg,
      expectedReps: plan.expectedReps,
      sets: sets,
      achievedReps: achievedReps,
      targetMet: targetMet,
      energyKcal: energy,
      metsUsed: metsUsed, // record what we actually used
    );
    await _logBox.add(log);

    // 4) Update plan progression
    if (targetMet && achievedReps >= plan.maxReps) {
      plan.currentWeightKg = plan.currentWeightKg + plan.incrementKg;
      plan.expectedReps = plan.minReps; // reset to floor
    } else {
      // stay at same weight; nudge target reps upward (bounded)
      final next = (plan.expectedReps + 1).clamp(plan.minReps, plan.maxReps);
      // clamp returns num; ensure int
      plan.expectedReps = next is int ? next : next.toInt();
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
