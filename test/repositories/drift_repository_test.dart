import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_app/database/app_database.dart';
import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/repositories/drift_repository.dart';

void main() {
  group('DriftRepository', () {
    test(
      'createExercise persists an exercise with linked muscle groups',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        configureTestDatabase(db);
        final repository = driftRepository;
        expect(repository, isNotNull);
        // TODO(Mrmah): Seed sample muscle groups + call createExercise.
        await db.close();
        resetDatabaseOverrides();
      },
      skip:
          'TODO(Mrmah): verify createExercise persistence and muscle group links',
    );

    test(
      'createExercise validates required muscle groups',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        configureTestDatabase(db);
        final repository = driftRepository;
        expect(repository, isNotNull);
        // TODO(Mrmah): Expect RepositoryException when createExercise is invoked with an empty groupIds list.
        await db.close();
        resetDatabaseOverrides();
      },
      skip: 'TODO(Mrmah): enforce group validation in createExercise',
    );

    test(
      'deleteExercise removes stored exercises',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        configureTestDatabase(db);
        final repository = driftRepository;
        expect(repository, isNotNull);
        // TODO(Mrmah): Create an exercise, delete it, then assert repository.getExercise returns null.
        await db.close();
        resetDatabaseOverrides();
      },
      skip: 'TODO(Mrmah): cover deleteExercise behavior',
    );
  });
}
