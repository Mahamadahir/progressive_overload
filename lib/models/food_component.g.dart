// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_component.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FoodComponentAdapter extends TypeAdapter<FoodComponent> {
  @override
  final int typeId = 33;

  @override
  FoodComponent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FoodComponent(
      id: fields[0] as String,
      name: fields[1] as String,
      kcalPer100g: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, FoodComponent obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.kcalPer100g);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodComponentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
