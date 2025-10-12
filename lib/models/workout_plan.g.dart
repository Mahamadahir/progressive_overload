// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_plan.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlanExerciseStateAdapter extends TypeAdapter<PlanExerciseState> {
  @override
  final int typeId = 22;

  @override
  PlanExerciseState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlanExerciseState(
      exerciseId: fields[0] as String,
      startWeightKg: fields[1] as double,
      currentWeightKg: fields[2] as double,
      minReps: fields[3] as int,
      maxReps: fields[4] as int,
      expectedReps: fields[5] as int,
      incrementKg: fields[6] as double,
      mets: fields[7] as double,
    );
  }

  @override
  void write(BinaryWriter writer, PlanExerciseState obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.exerciseId)
      ..writeByte(1)
      ..write(obj.startWeightKg)
      ..writeByte(2)
      ..write(obj.currentWeightKg)
      ..writeByte(3)
      ..write(obj.minReps)
      ..writeByte(4)
      ..write(obj.maxReps)
      ..writeByte(5)
      ..write(obj.expectedReps)
      ..writeByte(6)
      ..write(obj.incrementKg)
      ..writeByte(7)
      ..write(obj.mets);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanExerciseStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutPlanAdapter extends TypeAdapter<WorkoutPlan> {
  @override
  final int typeId = 20;

  @override
  WorkoutPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutPlan(
      id: fields[0] as String,
      name: fields[1] as String,
      currentWeightKg: fields[2] as double,
      minReps: fields[3] as int,
      maxReps: fields[4] as int,
      incrementKg: fields[5] as double,
      expectedReps: fields[6] as int?,
      createdAt: fields[7] as DateTime?,
      mets: fields[8] as double,
      targetMuscleGroupIds: (fields[9] as List?)?.cast<String>(),
      defaultExerciseId: fields[10] as String?,
      exercises: (fields[11] as List?)?.cast<PlanExerciseState>(),
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutPlan obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.currentWeightKg)
      ..writeByte(3)
      ..write(obj.minReps)
      ..writeByte(4)
      ..write(obj.maxReps)
      ..writeByte(5)
      ..write(obj.incrementKg)
      ..writeByte(6)
      ..write(obj.expectedReps)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.mets)
      ..writeByte(9)
      ..write(obj.targetMuscleGroupIds)
      ..writeByte(10)
      ..write(obj.defaultExerciseId)
      ..writeByte(11)
      ..write(obj.exercises);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutPlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutLogAdapter extends TypeAdapter<WorkoutLog> {
  @override
  final int typeId = 21;

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
