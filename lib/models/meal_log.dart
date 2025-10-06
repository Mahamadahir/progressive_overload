import 'package:hive/hive.dart';
import 'meal_component_line.dart';
part 'meal_log.g.dart';

@HiveType(typeId: 32)
class MealLog extends HiveObject {
  @HiveField(0)
  String id;

  /// UTC timestamp of when the meal was logged
  @HiveField(1)
  DateTime loggedAt;

  /// Optional link to a template
  @HiveField(2)
  String? templateId;

  /// Snapshot name when logged (templates can change later)
  @HiveField(3)
  String name;

  /// Legacy free-text tags (kept for backwards compatibility)
  @HiveField(4)
  List<String> components;

  /// Total mass actually eaten (g) — legacy field, keep filled
  @HiveField(5)
  double massGrams;

  /// Kcal computed at log time
  @HiveField(6)
  double kcal;

  /// NEW: snapshot of the structured lines used when logged
  @HiveField(7)
  List<MealComponentSnapshot>? snapshot;

  /// NEW: total mass from structured composition (if used)
  @HiveField(8)
  double? totalMassGrams;

  MealLog({
    required this.id,
    required this.loggedAt,
    required this.templateId,
    required this.name,
    required this.components,
    required this.massGrams,
    required this.kcal,
    this.snapshot,
    this.totalMassGrams,
  });
}
