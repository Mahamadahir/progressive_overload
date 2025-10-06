import 'package:hive/hive.dart';
part 'meal_component_line.g.dart';

/// Line item used inside MealTemplate
@HiveType(typeId: 34)
class MealComponentLine {
  @HiveField(0)
  String componentId; // points to FoodComponent.id

  @HiveField(1)
  double grams;

  MealComponentLine({required this.componentId, required this.grams});
}

/// Snapshot used inside MealLog (so logs don't change if components/templates change later)
@HiveType(typeId: 35)
class MealComponentSnapshot {
  @HiveField(0)
  String name;

  @HiveField(1)
  double kcalPer100g;

  @HiveField(2)
  double grams;

  @HiveField(3)
  double kcal;

  MealComponentSnapshot({
    required this.name,
    required this.kcalPer100g,
    required this.grams,
    required this.kcal,
  });
}
