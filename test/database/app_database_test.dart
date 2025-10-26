import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_app/database/app_database.dart';

void main() {
  group('AppDatabase', () {
    test(
      'runAfterOpenMigrations seeds default muscle groups',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        // TODO(Mrmah): Execute db.runAfterOpenMigrations() and assert seed data exists.
        await db.close();
      },
      skip: 'TODO(Mrmah): verify seed data',
    );

    test(
      'runAfterOpenMigrations is idempotent',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        // TODO(Mrmah): Call runAfterOpenMigrations multiple times and assert no duplicates.
        await db.close();
      },
      skip: 'TODO(Mrmah): verify idempotency',
    );

    test(
      'exerciseDao persists exercise metadata',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        // TODO(Mrmah): Insert an exercise via ExercisesCompanion and assert persistence.
        await db.close();
      },
      skip: 'TODO(Mrmah): persist exercise metadata',
    );
  });
}
