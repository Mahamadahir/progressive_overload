import 'package:fitness_app/models/food_component.dart';
import 'package:fitness_app/services/ai_food_log_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('existing component names are reused case-insensitively', () async {
    final service = AiFoodLogService();
    final rice = FoodComponent(id: 'rice', name: 'Rice', kcalPer100g: 130);
    final draft = AiMealDraft.fromJson({
      'kind': 'meal',
      'mealName': 'Lunch',
      'lines': [
        {'name': 'rice', 'grams': 120, 'kcalPer100g': 130, 'confidence': 0.9},
      ],
      'warnings': <String>[],
    });

    final mapped = service.mapMealDraft(
      draft: draft,
      existingComponents: [rice],
    );

    expect(mapped.lines.single.component, same(rice));
    expect(mapped.lines.single.isPendingComponent, isFalse);
  });

  test('new AI meal rows become pending draft components', () {
    final service = AiFoodLogService();
    final draft = AiMealDraft.fromJson({
      'kind': 'meal',
      'mealName': 'Snack',
      'lines': [
        {
          'name': 'Protein bar',
          'grams': 60,
          'kcalPer100g': 350,
          'confidence': 0.6,
        },
      ],
      'warnings': ['estimated calories'],
    });

    final mapped = service.mapMealDraft(
      draft: draft,
      existingComponents: const [],
    );

    expect(mapped.lines.single.isPendingComponent, isTrue);
    expect(
      mapped.lines.single.component.id,
      startsWith(aiDraftComponentIdPrefix),
    );
    expect(mapped.warnings, ['estimated calories']);
  });

  test('invalid Gemini numbers are rejected', () {
    expect(
      () => AiMealDraft.fromJson({
        'kind': 'meal',
        'mealName': 'Lunch',
        'lines': [
          {'name': 'Rice', 'grams': -1, 'kcalPer100g': 130, 'confidence': 0.9},
        ],
        'warnings': <String>[],
      }),
      throwsA(isA<AiFoodLogException>()),
    );
  });

  test('label extraction maps to editable component draft only', () async {
    final service = AiFoodLogService(
      invoker: (_) async => {
        'kind': 'component',
        'name': 'Cereal',
        'kcalPer100g': 380,
        'servingSizeGrams': 40,
        'kcalPerServing': 152,
        'confidence': 0.7,
        'warnings': ['serving inferred'],
      },
    );

    final draft = await service.parseLabelPhoto(
      base64: 'YWJjZA==',
      mimeType: 'image/png',
    );

    expect(draft.name, 'Cereal');
    expect(draft.kcalPer100g, 380);
    expect(draft.warnings, ['serving inferred']);
  });
}
