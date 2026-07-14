import 'package:drift/native.dart';
import 'package:fitness_app/database/app_database.dart';
import 'package:fitness_app/repositories/drift_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  setUpAll(configureSqliteForTests);

  late AppDatabase db;
  late DriftRepository repository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftRepository(db);
    await db.customSelect('SELECT 1').get();
  });

  tearDown(() => db.close());

  Future<String> group() => repository.createMuscleGroup('Test Chest');

  test('rejects invalid exercise inputs', () async {
    final groupId = await group();

    Future<void> create({
      String name = 'Bench press',
      List<String>? groupIds,
      double startWeightKg = 20,
      int minReps = 6,
      int maxReps = 12,
      double incrementKg = 2,
      double defaultMets = 3,
    }) async {
      await repository.createExercise(
        name: name,
        groupIds: groupIds ?? [groupId],
        startWeightKg: startWeightKg,
        minReps: minReps,
        maxReps: maxReps,
        incrementKg: incrementKg,
        defaultMets: defaultMets,
      );
    }

    await expectLater(
      create(groupIds: const []),
      throwsA(isA<RepositoryException>()),
    );
    await expectLater(
      create(groupIds: const ['']),
      throwsA(isA<RepositoryException>()),
    );
    await expectLater(
      create(groupIds: const ['missing']),
      throwsA(isA<RepositoryException>()),
    );
    await expectLater(create(name: '   '), throwsA(isA<RepositoryException>()));
    await expectLater(create(minReps: 0), throwsA(isA<RepositoryException>()));
    await expectLater(create(maxReps: 0), throwsA(isA<RepositoryException>()));
    await expectLater(
      create(minReps: 12, maxReps: 6),
      throwsA(isA<RepositoryException>()),
    );
    await expectLater(
      create(startWeightKg: -1),
      throwsA(isA<RepositoryException>()),
    );
    await expectLater(
      create(incrementKg: 0),
      throwsA(isA<RepositoryException>()),
    );
    await expectLater(
      create(defaultMets: 0),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('enforces unique muscle group and exercise names', () async {
    final groupId = await repository.createMuscleGroup('Test Chest');
    await expectLater(
      repository.createMuscleGroup('Test Chest'),
      throwsA(isA<RepositoryException>()),
    );

    await repository.createExercise(
      name: 'Bench press',
      groupIds: [groupId],
      startWeightKg: 20,
      minReps: 6,
      maxReps: 12,
      incrementKg: 2,
      defaultMets: 3,
    );
    await expectLater(
      repository.createExercise(
        name: 'Bench press',
        groupIds: [groupId],
        startWeightKg: 20,
        minReps: 6,
        maxReps: 12,
        incrementKg: 2,
        defaultMets: 3,
      ),
      throwsA(isA<RepositoryException>()),
    );
  });

  test(
    'cascades exercise delete to join rows and nulls child parent on group delete',
    () async {
      final parentId = await repository.createMuscleGroup('Parent');
      final childId = await repository.createMuscleGroup(
        'Child',
        parentId: parentId,
      );
      final exerciseId = await repository.createExercise(
        name: 'Bench press',
        groupIds: [parentId],
        startWeightKg: 20,
        minReps: 6,
        maxReps: 12,
        incrementKg: 2,
        defaultMets: 3,
      );

      await db.exerciseDao.deleteExercise(exerciseId);
      final joinRows = await db.select(db.exerciseMuscleGroups).get();
      expect(joinRows, isEmpty);

      await (db.delete(
        db.muscleGroups,
      )..where((tbl) => tbl.id.equals(parentId))).go();
      final child = await db.muscleGroupDao.findById(childId);
      expect(child!.parentId, isNull);
    },
  );
}
