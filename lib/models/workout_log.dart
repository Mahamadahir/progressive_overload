import 'package:hive/hive.dart';

part 'workout_log.g.dart';

@HiveType(typeId: 2) // <-- pick a unique typeId not used elsewhere
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
  int achievedReps;

  @HiveField(6)
  bool targetMet;

  @HiveField(7)
  double energyKcal;

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
