// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MealLogAdapter extends TypeAdapter<MealLog> {
  @override
  final int typeId = 32;

  @override
  MealLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealLog(
      id: fields[0] as String,
      loggedAt: fields[1] as DateTime,
      templateId: fields[2] as String?,
      name: fields[3] as String,
      components: (fields[4] as List).cast<String>(),
      massGrams: fields[5] as double,
      kcal: fields[6] as double,
      snapshot: (fields[7] as List?)?.cast<MealComponentSnapshot>(),
      totalMassGrams: fields[8] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, MealLog obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.loggedAt)
      ..writeByte(2)
      ..write(obj.templateId)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.components)
      ..writeByte(5)
      ..write(obj.massGrams)
      ..writeByte(6)
      ..write(obj.kcal)
      ..writeByte(7)
      ..write(obj.snapshot)
      ..writeByte(8)
      ..write(obj.totalMassGrams);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
