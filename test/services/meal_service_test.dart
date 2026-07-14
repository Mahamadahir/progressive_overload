import 'package:fitness_app/models/meal_component_line.dart';
import 'package:fitness_app/models/meal_log.dart';
import 'package:fitness_app/services/meal_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../helpers/test_harness.dart';

void main() {
  setUpAll(initialiseHive);

  setUp(openCoreHiveBoxes);

  tearDown(clearCoreHiveBoxes);

  tearDownAll(closeHive);

  test('meal logs snapshot component nutrition at log time', () async {
    final service = MealService();
    await service.createOrUpdateComponent(
      id: 'rice',
      name: 'Rice',
      kcalPer100g: 100,
    );

    final log = await service.logMealFromLines(
      name: 'Lunch',
      lines: [MealComponentLine(componentId: 'rice', grams: 50)],
      when: DateTime.utc(2026, 1, 2, 12),
    );
    await service.createOrUpdateComponent(
      id: 'rice',
      name: 'Rice',
      kcalPer100g: 200,
    );

    final stored = Hive.box<MealLog>('meal_logs').get(log.id)!;
    expect(stored.kcal, 50);
    expect(stored.snapshot!.single.kcalPer100g, 100);
    expect(stored.snapshot!.single.kcal, 50);
  });

  test(
    'todayIntakeKcal includes local midnight and excludes either side',
    () async {
      final service = MealService();
      final logs = Hive.box<MealLog>('meal_logs');
      final localDay = DateTime(2026, 1, 2);
      final startUtc = DateTime(
        localDay.year,
        localDay.month,
        localDay.day,
      ).toUtc();

      await logs.put(
        'before',
        MealLog(
          id: 'before',
          loggedAt: startUtc.subtract(const Duration(milliseconds: 1)),
          templateId: null,
          name: 'Before',
          components: const [],
          massGrams: 0,
          kcal: 10,
        ),
      );
      await logs.put(
        'exact',
        MealLog(
          id: 'exact',
          loggedAt: startUtc,
          templateId: null,
          name: 'Exact',
          components: const [],
          massGrams: 0,
          kcal: 20,
        ),
      );
      await logs.put(
        'after',
        MealLog(
          id: 'after',
          loggedAt: startUtc.add(const Duration(milliseconds: 1)),
          templateId: null,
          name: 'After',
          components: const [],
          massGrams: 0,
          kcal: 30,
        ),
      );
      await logs.put(
        'end',
        MealLog(
          id: 'end',
          loggedAt: startUtc.add(const Duration(days: 1)),
          templateId: null,
          name: 'End',
          components: const [],
          massGrams: 0,
          kcal: 40,
        ),
      );

      expect(
        service.todayIntakeKcal(now: localDay.add(const Duration(hours: 12))),
        50,
      );
    },
  );
}
