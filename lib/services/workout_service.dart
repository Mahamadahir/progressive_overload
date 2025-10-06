import 'package:hive/hive.dart';
import '../../models/workout_plan.dart';
import 'health_service.dart'; // for getLatestWeight() and writeStrengthWorkout()

class WorkoutService {
  final _planBox = Hive.box<WorkoutPlan>('plans');
  final _logBox = Hive.box<WorkoutLog>('plan_logs');

  List<WorkoutPlan> getPlans() => _planBox.values.toList();

  Future<void> createPlan({
    required String name,
    required double startWeightKg,
    int minReps = 6,
    int maxReps = 12,
    double incrementKg = 2.0,
  }) async {
    final plan = WorkoutPlan(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      currentWeightKg: startWeightKg,
      minReps: minReps,
      maxReps: maxReps,
      incrementKg: incrementKg,
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
  Future<WorkoutLog> logSession({
    required WorkoutPlan plan,
    required int sets,
    required int achievedReps,
    required bool targetMet,
    double? overrideMets, // <-- NEW: optional per-session override
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
    final log = WorkoutLog(
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
      plan.expectedReps =
          (plan.expectedReps + 1).clamp(plan.minReps, plan.maxReps);
    }
    await plan.save();

    return log;
  }

  List<WorkoutLog> getLogsForPlan(String planId) =>
      _logBox.values.where((l) => l.planId == planId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
}
