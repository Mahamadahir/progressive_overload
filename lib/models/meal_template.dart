import 'package:hive/hive.dart';
import 'meal_component_line.dart';
part 'meal_template.g.dart';

@HiveType(typeId: 31)
class MealTemplate extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// Legacy fields (kept for backwards compatibility)
  @HiveField(2)
  double baseMassGrams;

  @HiveField(3)
  double baseKcal;

  /// Free-form components (legacy UI)
  @HiveField(4)
  List<String> components;

  /// NEW: structured composition (preferred)
  @HiveField(5)
  List<MealComponentLine> lines;

  MealTemplate({
    required this.id,
    required this.name,
    this.baseMassGrams = 0,
    this.baseKcal = 0,
    this.components = const [],
    this.lines = const [],
  });
}
