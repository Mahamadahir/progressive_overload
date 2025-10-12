// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutLogAdapter extends TypeAdapter<WorkoutLog> {
  @override
  final int typeId = 2;

  @override
  WorkoutLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutLog(
      planId: fields[0] as String,
      date: fields[1] as DateTime,
      expectedWeightKg: fields[2] as double,
      expectedReps: fields[3] as int,
      sets: fields[4] as int,
      achievedReps: fields[5] as int,
      targetMet: fields[6] as bool,
      energyKcal: fields[7] as double,
      metsUsed: fields[8] as double,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutLog obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.planId)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.expectedWeightKg)
      ..writeByte(3)
      ..write(obj.expectedReps)
      ..writeByte(4)
      ..write(obj.sets)
      ..writeByte(5)
      ..write(obj.achievedReps)
      ..writeByte(6)
      ..write(obj.targetMet)
      ..writeByte(7)
      ..write(obj.energyKcal)
      ..writeByte(8)
      ..write(obj.metsUsed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
