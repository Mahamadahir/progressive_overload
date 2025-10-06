import 'package:hive/hive.dart';
part 'food_component.g.dart';

@HiveType(typeId: 33) // new, unused id
class FoodComponent extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// kcal per 100g (e.g., chicken breast ~165)
  @HiveField(2)
  double kcalPer100g;

  FoodComponent({
    required this.id,
    required this.name,
    required this.kcalPer100g,
  });
}
