import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_app/database/app_database.dart';
import 'package:fitness_app/repositories/drift_repository.dart';

void main() {
  late AppDatabase db;
  late DriftRepository repository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftRepository(db);
    await db.customSelect('SELECT 1').get();
  });

  tearDown(() async {
    await db.close();
  });

  test('createMuscleGroup adds nested group', () async {
    final parentId = await repository.createMuscleGroup('Core');
    final childId = await repository.createMuscleGroup(
      'Abs',
      parentId: parentId,
    );

    expect(childId, isNotEmpty);

    final tree = await repository.getMuscleGroupsTree();
    final coreNode = tree.firstWhere((node) => node.group.name == 'Core');
    expect(coreNode.children.map((n) => n.group.name), contains('Abs'));
  });

  test('createExercise persists groups and details', () async {
    final groups = await repository.getMuscleGroupsTree();
    final groupId = groups.first.group.id;

    final exerciseId = await repository.createExercise(\n      name: 'Push-up',\n      notes: 'Bodyweight',\n      groupIds: [groupId],\n      startWeightKg: 20,\n      minReps: 6,\n      maxReps: 12,\n      incrementKg: 2,\n      defaultMets: 3.0,\n    );

    final detail = await repository.getExercise(exerciseId);
    expect(detail, isNotNull);
    expect(detail!.groups.single.id, equals(groupId));\n    expect(detail.exercise.startWeightKg, equals(20));\n    expect(detail.exercise.minReps, equals(6));\n    expect(detail.exercise.maxReps, equals(12));\n    expect(detail.exercise.incrementKg, equals(2));\n    expect(detail.exercise.defaultMets, equals(3.0));
  });

  test('logWorkout inserts workout logs', () async {
    final workout = await repository.createWorkout(
      name: 'Test Workout',
      planId: 'plan-1',
    );

    final logId = await repository.logWorkout(
      workoutId: workout.id,
      exerciseId: null,
      sets: 3,
      reps: 10,
      weightKg: 50,
      energyKcal: 120,
      metsUsed: 3.0,
      performedAt: DateTime.now(),
    );

    final logs = await repository.getLogsForWorkout(workout.id);
    expect(logs, hasLength(1));
    expect(logs.first.log.id, equals(logId));
  });
}


