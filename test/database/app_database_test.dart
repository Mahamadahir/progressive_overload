import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_app/database/app_database.dart';

void main() {
  late AppDatabase db;

  Future<void> openDb() async {
    await db.customSelect('SELECT 1').get();
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('seeds default muscle groups', () async {
    await openDb();
    final groups = await db.muscleGroupDao.getAll();
    final names = groups.map((g) => g.name).toList();
    expect(names, containsAll(['Upper Body', 'Lower Body']));
  });

  test('exercise DAO stores muscle group relations', () async {
    await openDb();
    const exerciseId = 'exercise-1';

    await db.exerciseDao.insertExercise(
      ExercisesCompanion.insert(
        id: exerciseId,
        name: 'Bench Press',
        notes: const Value('Test notes'),
      ),
    );

    await db.exerciseDao.replaceExerciseGroups(
      exerciseId: exerciseId,
      groupIds: const [
        '00000000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000002',
      ],
    );

    final groupIds = await db.exerciseDao.groupIdsForExercise(exerciseId);
    expect(groupIds, contains('00000000-0000-4000-8000-000000000001'));
    expect(groupIds, contains('00000000-0000-4000-8000-000000000002'));
  });

  test('workout DAO logs are persisted with cascades', () async {
    await openDb();
    const workoutId = 'workout-1';
    const logId = 'log-1';
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await db.workoutDao.insertWorkout(
      WorkoutsCompanion(
        id: const Value(workoutId),
        name: const Value('Test Workout'),
        planId: const Value('plan-123'),
        createdAt: Value(timestamp),
        updatedAt: Value(timestamp),
      ),
    );

    await db.workoutDao.insertLog(
      WorkoutLogsCompanion(
        id: const Value(logId),
        workoutId: const Value(workoutId),
        performedAt: Value(timestamp),
        sets: const Value(3),
        reps: const Value(10),
        energyKcal: const Value(150.0),
        metsUsed: const Value(3.0),
      ),
    );

    final logs = await db.workoutDao.logsForWorkout(workoutId);
    expect(logs, hasLength(1));
    expect(logs.single.id, logId);
  });
}
