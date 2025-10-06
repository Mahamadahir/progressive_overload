import 'package:hive/hive.dart';

part 'calorie_entry.g.dart';

@HiveType(typeId: 0)
class CalorieEntry extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final int calories;

  CalorieEntry({required this.date, required this.calories});

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'calories': calories,
      };

  factory CalorieEntry.fromMap(Map<String, dynamic> map) => CalorieEntry(
        date: DateTime.parse(map['date']),
        calories: map['calories'],
      );
}
