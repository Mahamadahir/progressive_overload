// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_component_line.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MealComponentLineAdapter extends TypeAdapter<MealComponentLine> {
  @override
  final int typeId = 34;

  @override
  MealComponentLine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealComponentLine(
      componentId: fields[0] as String,
      grams: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, MealComponentLine obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.componentId)
      ..writeByte(1)
      ..write(obj.grams);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealComponentLineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MealComponentSnapshotAdapter extends TypeAdapter<MealComponentSnapshot> {
  @override
  final int typeId = 35;

  @override
  MealComponentSnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealComponentSnapshot(
      name: fields[0] as String,
      kcalPer100g: fields[1] as double,
      grams: fields[2] as double,
      kcal: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, MealComponentSnapshot obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.kcalPer100g)
      ..writeByte(2)
      ..write(obj.grams)
      ..writeByte(3)
      ..write(obj.kcal);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealComponentSnapshotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
