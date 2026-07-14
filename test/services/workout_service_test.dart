import 'package:drift/native.dart';
import 'package:fitness_app/database/app_database.dart';
import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/models/workout_log.dart' as workout_log;
import 'package:fitness_app/models/workout_plan.dart';
import 'package:fitness_app/services/workout_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../helpers/test_harness.dart';

void main() {
  late AppDatabase db;

  setUpAll(initialiseHive);

  setUp(() async {
    await openCoreHiveBoxes();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    configureTestDatabase(db);
    await db.customSelect('SELECT 1').get();
  });

  tearDown(() async {
    resetDatabaseOverrides();
    await db.close();
    await clearCoreHiveBoxes();
  });

  WorkoutService service({bool healthWriteSucceeds = true}) => WorkoutService(
    latestWeightReader: () async => 80,
    strengthWorkoutWriter:
        ({
          required start,
          required end,
          required energyKcal,
          required title,
        }) async => healthWriteSucceeds,
    workoutNotification:
        ({required id, required title, required body}) async {},
  );

  Future<WorkoutPlan> planForExercise({
    required String exerciseId,
    int expectedReps = 8,
    double currentWeightKg = 100,
  }) async {
    final plan = WorkoutPlan(
      id: 'plan-$exerciseId-$expectedReps',
      name: 'Plan',
      currentWeightKg: currentWeightKg,
      minReps: 6,
      maxReps: 12,
      incrementKg: 2,
      expectedReps: expectedReps,
      defaultExerciseId: exerciseId,
      exercises: [
        PlanExerciseState(
          exerciseId: exerciseId,
          startWeightKg: currentWeightKg,
          currentWeightKg: currentWeightKg,
          minReps: 6,
          maxReps: 12,
          expectedReps: expectedReps,
          incrementKg: 2,
          mets: 6,
        ),
      ],
    );
    await Hive.box<WorkoutPlan>('plans').put(plan.id, plan);
    return plan;
  }

  Future<String> createExercise() async {
    final groupId = await driftRepository.createMuscleGroup('Push');
    return driftRepository.createExercise(
      name: 'Bench press',
      groupIds: [groupId],
      startWeightKg: 100,
      minReps: 6,
      maxReps: 12,
      incrementKg: 2,
      defaultMets: 6,
    );
  }

  test(
    'advances weight and resets expected reps when target reps are met',
    () async {
      final exerciseId = await createExercise();
      final plan = await planForExercise(
        exerciseId: exerciseId,
        expectedReps: 8,
      );

      await service().logExercise(
        plan: plan,
        exerciseId: exerciseId,
        exerciseName: 'Bench press',
        sets: const [ExerciseSetEntry(reps: 8, weightKg: 100)],
      );

      final state = plan.defaultExerciseState!;
      expect(state.currentWeightKg, 102);
      expect(state.expectedReps, 6);
    },
  );

  test('uses double increment when logged reps reach max reps', () async {
    final exerciseId = await createExercise();
    final plan = await planForExercise(exerciseId: exerciseId, expectedReps: 8);

    await service().logExercise(
      plan: plan,
      exerciseId: exerciseId,
      exerciseName: 'Bench press',
      sets: const [ExerciseSetEntry(reps: 12, weightKg: 100)],
    );

    final state = plan.defaultExerciseState!;
    expect(state.currentWeightKg, 104);
    expect(state.expectedReps, 6);
  });

  test(
    'below target reps keep weight and advance expected reps from achieved reps',
    () async {
      final exerciseId = await createExercise();
      final plan = await planForExercise(
        exerciseId: exerciseId,
        expectedReps: 10,
      );

      await service().logExercise(
        plan: plan,
        exerciseId: exerciseId,
        exerciseName: 'Bench press',
        sets: const [ExerciseSetEntry(reps: 8, weightKg: 100)],
      );

      final state = plan.defaultExerciseState!;
      expect(state.currentWeightKg, 100);
      expect(state.expectedReps, 9);
    },
  );

  test(
    'deload fires after exactly three consecutive below-minimum logs',
    () async {
      final exerciseId = await createExercise();
      final plan = await planForExercise(
        exerciseId: exerciseId,
        expectedReps: 8,
      );

      for (var i = 0; i < 3; i++) {
        await service().logExercise(
          plan: plan,
          exerciseId: exerciseId,
          exerciseName: 'Bench press',
          sets: const [ExerciseSetEntry(reps: 5, weightKg: 100)],
        );
      }

      final state = plan.defaultExerciseState!;
      expect(state.currentWeightKg, 90);
      expect(state.expectedReps, 6);
    },
  );

  test(
    'deload does not fire after two consecutive below-minimum logs',
    () async {
      final exerciseId = await createExercise();
      final plan = await planForExercise(
        exerciseId: exerciseId,
        expectedReps: 8,
      );

      for (var i = 0; i < 2; i++) {
        await service().logExercise(
          plan: plan,
          exerciseId: exerciseId,
          exerciseName: 'Bench press',
          sets: const [ExerciseSetEntry(reps: 5, weightKg: 100)],
        );
      }

      final state = plan.defaultExerciseState!;
      expect(state.currentWeightKg, 100);
      expect(state.expectedReps, 6);
    },
  );

  test('rejects invalid logExercise inputs', () async {
    final exerciseId = await createExercise();
    final plan = await planForExercise(exerciseId: exerciseId);

    expect(
      () => service().logExercise(
        plan: plan,
        exerciseId: exerciseId,
        exerciseName: 'Bench',
        sets: const [],
      ),
      throwsArgumentError,
    );
    expect(
      () => service().logExercise(
        plan: plan,
        exerciseId: exerciseId,
        exerciseName: 'Bench',
        sets: const [ExerciseSetEntry(reps: 0, weightKg: 100)],
      ),
      throwsArgumentError,
    );
    expect(
      () => service().logExercise(
        plan: plan,
        exerciseId: exerciseId,
        exerciseName: 'Bench',
        sets: const [ExerciseSetEntry(reps: 8, weightKg: -1)],
      ),
      throwsArgumentError,
    );
    expect(
      () => service().logExercise(
        plan: plan,
        exerciseId: exerciseId,
        exerciseName: 'Bench',
        sets: const [ExerciseSetEntry(reps: 8, weightKg: double.nan)],
      ),
      throwsArgumentError,
    );
    expect(
      () => service().logExercise(
        plan: plan,
        exerciseId: 'other',
        exerciseName: 'Bench',
        sets: const [ExerciseSetEntry(reps: 8, weightKg: 100)],
      ),
      throwsArgumentError,
    );
  });

  test('MET calorie estimate uses weight, METs and duration', () async {
    final exerciseId = await createExercise();
    final plan = await planForExercise(exerciseId: exerciseId);

    final log = await service().logExercise(
      plan: plan,
      exerciseId: exerciseId,
      exerciseName: 'Bench press',
      sets: const [
        ExerciseSetEntry(reps: 10, weightKg: 100),
        ExerciseSetEntry(reps: 10, weightKg: 100),
        ExerciseSetEntry(reps: 10, weightKg: 100),
      ],
    );

    expect(log.energyKcal, closeTo(21, 0.001));
  });

  test(
    'failed health write rejects the workout before local logging',
    () async {
      final exerciseId = await createExercise();
      final plan = await planForExercise(exerciseId: exerciseId);

      await expectLater(
        service(healthWriteSucceeds: false).logExercise(
          plan: plan,
          exerciseId: exerciseId,
          exerciseName: 'Bench press',
          sets: const [ExerciseSetEntry(reps: 8, weightKg: 100)],
        ),
        throwsStateError,
      );
      expect(Hive.box<workout_log.WorkoutLog>('plan_logs').isEmpty, isTrue);
    },
  );

  tearDownAll(closeHive);
}
