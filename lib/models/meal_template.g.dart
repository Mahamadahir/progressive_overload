// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MealTemplateAdapter extends TypeAdapter<MealTemplate> {
  @override
  final int typeId = 31;

  @override
  MealTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealTemplate(
      id: fields[0] as String,
      name: fields[1] as String,
      baseMassGrams: fields[2] as double,
      baseKcal: fields[3] as double,
      components: (fields[4] as List).cast<String>(),
      lines: (fields[5] as List).cast<MealComponentLine>(),
    );
  }

  @override
  void write(BinaryWriter writer, MealTemplate obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.baseMassGrams)
      ..writeByte(3)
      ..write(obj.baseKcal)
      ..writeByte(4)
      ..write(obj.components)
      ..writeByte(5)
      ..write(obj.lines);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
