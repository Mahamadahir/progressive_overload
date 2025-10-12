import 'package:hive/hive.dart';

part 'workout_plan.g.dart';

@HiveType(typeId: 22)
class PlanExerciseState {
  @HiveField(0)
  String exerciseId;

  @HiveField(1)
  double startWeightKg;

  @HiveField(2)
  double currentWeightKg;

  @HiveField(3)
  int minReps;

  @HiveField(4)
  int maxReps;

  @HiveField(5)
  int expectedReps;

  @HiveField(6)
  double incrementKg;

  @HiveField(7)
  double mets;

  PlanExerciseState({
    required this.exerciseId,
    required this.startWeightKg,
    required this.currentWeightKg,
    required this.minReps,
    required this.maxReps,
    required this.expectedReps,
    required this.incrementKg,
    required this.mets,
  });

  PlanExerciseState copyWith({
    double? currentWeightKg,
    int? expectedReps,
  }) =>
      PlanExerciseState(
        exerciseId: exerciseId,
        startWeightKg: startWeightKg,
        currentWeightKg: currentWeightKg ?? this.currentWeightKg,
        minReps: minReps,
        maxReps: maxReps,
        expectedReps: expectedReps ?? this.expectedReps,
        incrementKg: incrementKg,
        mets: mets,
      );
}

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

  @HiveField(9)
  List<String> targetMuscleGroupIds;

  @HiveField(10)
  String? defaultExerciseId;

  /// Collection of exercises configured for this workout.
  @HiveField(11)
  List<PlanExerciseState> exercises;

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
    List<String>? targetMuscleGroupIds,
    this.defaultExerciseId,
    List<PlanExerciseState>? exercises,
  }) : expectedReps = expectedReps ?? minReps,
       createdAt = createdAt ?? DateTime.now(),
       targetMuscleGroupIds = List<String>.from(
         targetMuscleGroupIds ?? const [],
       ),
       exercises = List<PlanExerciseState>.from(exercises ?? const []) {
    _syncFromPrimaryExercise();
  }

  PlanExerciseState? get primaryExercise =>
      exercises.isEmpty ? null : exercises.first;

  PlanExerciseState? get defaultExerciseState {
    if (exercises.isEmpty) return null;
    if (defaultExerciseId == null) {
      return primaryExercise;
    }
    for (final state in exercises) {
      if (state.exerciseId == defaultExerciseId) {
        return state;
      }
    }
    return primaryExercise;
  }

  void _syncFromPrimaryExercise() {
    final state = defaultExerciseState;
    if (state == null) return;
    currentWeightKg = state.currentWeightKg;
    minReps = state.minReps;
    maxReps = state.maxReps;
    expectedReps = state.expectedReps;
    incrementKg = state.incrementKg;
    mets = state.mets;
  }

  void updatePrimaryFromState(PlanExerciseState state) {
    if (state.exerciseId == defaultExerciseId ||
        defaultExerciseId == null && primaryExercise == state) {
      currentWeightKg = state.currentWeightKg;
      minReps = state.minReps;
      maxReps = state.maxReps;
      expectedReps = state.expectedReps;
      incrementKg = state.incrementKg;
      mets = state.mets;
    }
  }
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

