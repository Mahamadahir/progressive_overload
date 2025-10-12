import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_app/database/app_database.dart';
import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/screens/create_exercise_page.dart';

void main() {
  testWidgets('CreateExercisePage enforces muscle group selection', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    configureTestDatabase(db);
    await db.customSelect('SELECT 1').get();

    await tester.pumpWidget(const MaterialApp(home: CreateExercisePage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Push-up');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Starting weight (kg)'),
      '20',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Min reps'),
      '6',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Max reps'),
      '12',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Increment (kg)'),
      '2',
    );
    await tester.tap(find.text('Create exercise'));
    await tester.pump();

    expect(find.text('Select at least one muscle group'), findsOneWidget);

    for (
      var i = 0;
      i < 10 && find.byType(CheckboxListTile).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.byType(CheckboxListTile), findsWidgets);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();

    await tester.tap(find.text('Create exercise'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateExercisePage), findsNothing);

    await db.close();
    resetDatabaseOverrides();
  });
}
