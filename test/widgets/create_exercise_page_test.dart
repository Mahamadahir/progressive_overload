import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_app/screens/create_exercise_page.dart';

void main() {
  group('CreateExercisePage', () {
    testWidgets('renders creation form fields', (tester) async {
      // TODO(Mrmah): Pump CreateExercisePage inside a MaterialApp and assert required fields exist.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    }, skip: true);

    testWidgets('prefills fields when editing an exercise', (tester) async {
      // TODO(Mrmah): Seed a fixture exercise via DriftRepository, pump the edit screen, and verify text fields populate.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    }, skip: true);

    testWidgets('submits a valid exercise definition', (tester) async {
      // TODO(Mrmah): Enter form data, submit, and assert DriftRepository.createExercise is invoked.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    }, skip: true);
  });
}
