import 'package:hive/hive.dart';

part 'workout_plan.g.dart';

@HiveType(typeId: 20)
class WorkoutPlan extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double currentWeightKg;

  @HiveField(3)
  int minReps; // default 6

  @HiveField(4)
  int maxReps; // default 12

  @HiveField(5)
  double incrementKg; // default +2.0

  @HiveField(6)
  int expectedReps; // between min..max (start at min)

  @HiveField(7)
  DateTime createdAt;

  /// NEW: default METs (intensity) for this plan, e.g. 2.5 (light), 3.0 (moderate), 5.0 (vigorous)
  @HiveField(8)
  double mets;

  WorkoutPlan({
    required this.id,
    required this.name,
    required this.currentWeightKg,
    this.minReps = 6,
    this.maxReps = 12,
    this.incrementKg = 2.0,
    int? expectedReps,
    DateTime? createdAt,
    this.mets = 3.0,
  })  : expectedReps = expectedReps ?? minReps,
        createdAt = createdAt ?? DateTime.now();
}

@HiveType(typeId: 21)
class WorkoutLog extends HiveObject {
  @HiveField(0)
  String planId;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  double expectedWeightKg;

  @HiveField(3)
  int expectedReps;

  @HiveField(4)
  int sets;

  @HiveField(5)
  int achievedReps; // per set (simple model)

  @HiveField(6)
  bool targetMet;

  @HiveField(7)
  double energyKcal; // estimated & saved to HC

  /// NEW: METs used for this session (so history shows the exact assumption)
  @HiveField(8)
  double metsUsed;

  WorkoutLog({
    required this.planId,
    required this.date,
    required this.expectedWeightKg,
    required this.expectedReps,
    required this.sets,
    required this.achievedReps,
    required this.targetMet,
    required this.energyKcal,
    required this.metsUsed,
  });
}
