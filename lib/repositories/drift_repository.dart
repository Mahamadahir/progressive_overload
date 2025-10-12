import 'dart:async';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:fitness_app/database/app_database.dart';
import 'package:uuid/uuid.dart';

class RepositoryException implements Exception {
  final String message;
  RepositoryException(this.message);

  @override
  String toString() => message;
}

class DriftRepository {
  DriftRepository(this._db);

  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  AppDatabase get db => _db;

  // --- Muscle Groups ---

  Stream<List<MuscleGroupNode>> watchMuscleGroupsTree() =>
      _db.muscleGroupDao.watchAll().map(_buildTree);

  Future<List<MuscleGroupNode>> getMuscleGroupsTree() async {
    final groups = await _db.muscleGroupDao.getAll();
    return _buildTree(groups);
  }

  Future<String> createMuscleGroup(String name, {String? parentId}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw RepositoryException('Name is required.');
    }

    if (parentId != null && parentId.isNotEmpty) {
      final parent = await _db.muscleGroupDao.findById(parentId);
      if (parent == null) {
        throw RepositoryException('Parent muscle group not found.');
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    final entry = MuscleGroupsCompanion(
      id: Value(id),
      name: Value(trimmed),
      parentId: parentId == null ? const Value.absent() : Value(parentId),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    try {
      await _db.muscleGroupDao.insertGroup(entry);
    } catch (e) {
      if (e is Exception && e.toString().contains('UNIQUE')) {
        throw RepositoryException(
          'A muscle group with that name already exists.',
        );
      }
      rethrow;
    }
    return id;
  }

  Future<void> updateMuscleGroup({
    required String id,
    required String name,
    String? parentId,
  }) async {
    final current = await _db.muscleGroupDao.findById(id);
    if (current == null) {
      throw RepositoryException('Muscle group not found.');
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw RepositoryException('Name is required.');
    }

    if (parentId == id) {
      throw RepositoryException('A muscle group cannot be its own parent.');
    }

    if (parentId != null && parentId.isNotEmpty) {
      final parent = await _db.muscleGroupDao.findById(parentId);
      if (parent == null) {
        throw RepositoryException('Parent muscle group not found.');
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final companion = MuscleGroupsCompanion(
      name: Value(trimmed),
      parentId: parentId == null ? const Value<String?>(null) : Value(parentId),
      updatedAt: Value(now),
    );

    try {
      await (_db.update(
        _db.muscleGroups,
      )..where((tbl) => tbl.id.equals(id))).write(companion);
    } catch (e) {
      if (e is Exception && e.toString().contains('UNIQUE')) {
        throw RepositoryException(
          'A muscle group with that name already exists.',
        );
      }
      rethrow;
    }
  }

  Future<void> deleteMuscleGroup(String id) async {
    final refs = await (_db.select(
      _db.exerciseMuscleGroups,
    )..where((tbl) => tbl.groupId.equals(id))).get();
    if (refs.isNotEmpty) {
      throw RepositoryException(
        'Cannot delete. This muscle group is used by ${refs.length} exercise(s). Update or reassign those exercises first.',
      );
    }

    await _db.muscleGroupDao.deleteGroup(id);
  }

  // --- Exercises ---

  Stream<List<ExerciseDetail>> watchExercises({List<String>? groupIds}) {
    final query = _exerciseQuery(groupIds);
    return query.watch().map(_mapExerciseRows);
  }

  Future<List<ExerciseDetail>> getExercises({List<String>? groupIds}) async {
    final query = _exerciseQuery(groupIds);
    final rows = await query.get();
    return _mapExerciseRows(rows);
  }

  Future<String> createExercise({
    required String name,
    String? notes,
    required List<String> groupIds,
    required double startWeightKg,
    required int minReps,
    required int maxReps,
    required double incrementKg,
    required double defaultMets,
  }) async {
    if (groupIds.isEmpty) {
      throw RepositoryException('Select at least one muscle group.');
    }

    await _ensureGroupsExist(groupIds);

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw RepositoryException('Name is required.');
    }

    if (minReps <= 0 || maxReps <= 0) {
      throw RepositoryException('Repetition targets must be greater than zero.');
    }

    if (minReps > maxReps) {
      throw RepositoryException('Min reps cannot be greater than max reps.');
    }

    if (startWeightKg < 0) {
      throw RepositoryException('Starting weight cannot be negative.');
    }

    if (incrementKg <= 0) {
      throw RepositoryException('Increment must be greater than zero.');
    }

    if (defaultMets <= 0) {
      throw RepositoryException('Default METs must be greater than zero.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    final entry = ExercisesCompanion(
      id: Value(id),
      name: Value(trimmed),
      notes: notes == null || notes.trim().isEmpty
          ? const Value.absent()
          : Value(notes.trim()),
      createdAt: Value(now),
      updatedAt: Value(now),
      startWeightKg: Value(startWeightKg),
      minReps: Value(minReps),
      maxReps: Value(maxReps),
      incrementKg: Value(incrementKg),
      defaultMets: Value(defaultMets),
    );

    try {
      await _db.exerciseDao.insertExercise(entry);
    } catch (e) {
      if (e is Exception && e.toString().contains('UNIQUE')) {
        throw RepositoryException('An exercise with that name already exists.');
      }
      rethrow;
    }

    await _db.exerciseDao.replaceExerciseGroups(
      exerciseId: id,
      groupIds: groupIds,
    );

    return id;
  }

  Future<void> updateExercise({
    required String id,
    required String name,
    String? notes,
    required List<String> groupIds,
    required double startWeightKg,
    required int minReps,
    required int maxReps,
    required double incrementKg,
    required double defaultMets,
  }) async {
    if (groupIds.isEmpty) {
      throw RepositoryException('Select at least one muscle group.');
    }

    await _ensureGroupsExist(groupIds);

    final current = await _db.exerciseDao.findById(id);
    if (current == null) {
      throw RepositoryException('Exercise not found.');
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw RepositoryException('Name is required.');
    }

    if (minReps <= 0 || maxReps <= 0) {
      throw RepositoryException('Repetition targets must be greater than zero.');
    }

    if (minReps > maxReps) {
      throw RepositoryException('Min reps cannot be greater than max reps.');
    }

    if (startWeightKg < 0) {
      throw RepositoryException('Starting weight cannot be negative.');
    }

    if (incrementKg <= 0) {
      throw RepositoryException('Increment must be greater than zero.');
    }

    if (defaultMets <= 0) {
      throw RepositoryException('Default METs must be greater than zero.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    final companion = ExercisesCompanion(
      name: Value(trimmed),
      notes: notes == null || notes.trim().isEmpty
          ? const Value<String?>(null)
          : Value(notes.trim()),
      updatedAt: Value(now),
      startWeightKg: Value(startWeightKg),
      minReps: Value(minReps),
      maxReps: Value(maxReps),
      incrementKg: Value(incrementKg),
      defaultMets: Value(defaultMets),
    );

    try {
      await (_db.update(
        _db.exercises,
      )..where((tbl) => tbl.id.equals(id))).write(companion);
    } catch (e) {
      if (e is Exception && e.toString().contains('UNIQUE')) {
        throw RepositoryException('An exercise with that name already exists.');
      }
      rethrow;
    }

    await _db.exerciseDao.replaceExerciseGroups(
      exerciseId: id,
      groupIds: groupIds,
    );
  }

  Future<void> deleteExercise(String id) async {
    await _db.exerciseDao.deleteExercise(id);
  }

  Future<ExerciseDetail?> getExercise(String id) async {
    final exercise = await _db.exerciseDao.findById(id);
    if (exercise == null) return null;
    final groups = await _db.exerciseDao.groupIdsForExercise(id);
    final groupRecords = await (_db.select(
      _db.muscleGroups,
    )..where((tbl) => tbl.id.isIn(groups))).get();
    return ExerciseDetail(exercise: exercise, groups: groupRecords);
  }

  // --- Workouts & Logs ---

  Future<Workout> createWorkout({String? name, String? planId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    final entry = WorkoutsCompanion(
      id: Value(id),
      name: name == null || name.trim().isEmpty
          ? const Value.absent()
          : Value(name.trim()),
      planId: planId == null || planId.isEmpty
          ? const Value.absent()
          : Value(planId),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await _db.workoutDao.insertWorkout(entry);
    return (await _db.workoutDao.findById(id))!;
  }

  Future<Workout> ensureWorkoutForPlan(String planId, {String? name}) async {
    final existing = await _db.workoutDao.findByPlanId(planId);
    if (existing != null) {
      final trimmed = name?.trim();
      if (trimmed != null && trimmed.isNotEmpty && existing.name != trimmed) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await (_db.update(
          _db.workouts,
        )..where((tbl) => tbl.id.equals(existing.id))).write(
          WorkoutsCompanion(name: Value(trimmed), updatedAt: Value(now)),
        );
        return (await _db.workoutDao.findById(existing.id))!;
      }
      return existing;
    }
    return createWorkout(name: name, planId: planId);
  }

  Future<void> deleteWorkoutForPlan(String planId) async {
    final existing = await _db.workoutDao.findByPlanId(planId);
    if (existing != null) {
      await _db.workoutDao.deleteWorkout(existing.id);
    }
  }

  Future<String> logWorkout({
    required String workoutId,
    String? exerciseId,
    required int sets,
    required int reps,
    double? weightKg,
    required double energyKcal,
    required double metsUsed,
    required DateTime performedAt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    final entry = WorkoutLogsCompanion(
      id: Value(id),
      workoutId: Value(workoutId),
      exerciseId: exerciseId == null || exerciseId.isEmpty
          ? const Value.absent()
          : Value(exerciseId),
      performedAt: Value(performedAt.millisecondsSinceEpoch),
      sets: Value(sets),
      reps: Value(reps),
      weightKg: weightKg == null ? const Value.absent() : Value(weightKg),
      energyKcal: Value(energyKcal),
      metsUsed: Value(metsUsed),
    );

    await _db.workoutDao.insertLog(entry);

    await (_db.update(_db.workouts)..where((tbl) => tbl.id.equals(workoutId)))
        .write(WorkoutsCompanion(updatedAt: Value(now)));

    return id;
  }

  Stream<List<WorkoutLogDetail>> watchLogsForWorkout(String workoutId) {
    final query = _workoutLogJoin()
      ..where(_db.workoutLogs.workoutId.equals(workoutId));
    return query.watch().map(_mapWorkoutLogRows);
  }

  Future<List<WorkoutLogDetail>> getLogsForWorkout(String workoutId) async {
    final query = _workoutLogJoin()
      ..where(_db.workoutLogs.workoutId.equals(workoutId));
    final rows = await query.get();
    return _mapWorkoutLogRows(rows);
  }

  Future<List<MuscleGroupVolume>> volumeByMuscleGroup({
    required DateTime start,
    required DateTime end,
  }) async {
    final rows =
        await (_workoutLogJoin()..where(
              _db.workoutLogs.performedAt.isBetweenValues(
                start.millisecondsSinceEpoch,
                end.millisecondsSinceEpoch,
              ),
            ))
            .get();

    final Map<String, _VolumeAccumulator> acc = {};

    for (final row in rows) {
      final log = row.readTable(_db.workoutLogs);
      final group = row.readTableOrNull(_db.muscleGroups);
      if (group == null) continue;

      final weight = log.weightKg ?? 0;
      final volume = (log.sets * log.reps) * weight;

      final entry = acc.putIfAbsent(group.id, () => _VolumeAccumulator(group));
      entry.volume += volume;
    }

    final result = acc.values
        .map(
          (acc) => MuscleGroupVolume(group: acc.group, totalVolume: acc.volume),
        )
        .toList();
    result.sort((a, b) => b.totalVolume.compareTo(a.totalVolume));
    return result;
  }

  Future<List<MuscleGroupWorkoutCount>> workoutsByGroup({
    required DateTime start,
    required DateTime end,
  }) async {
    final rows =
        await (_workoutLogJoin()..where(
              _db.workoutLogs.performedAt.isBetweenValues(
                start.millisecondsSinceEpoch,
                end.millisecondsSinceEpoch,
              ),
            ))
            .get();

    final Map<String, _CountAccumulator> acc = {};

    for (final row in rows) {
      final group = row.readTableOrNull(_db.muscleGroups);
      if (group == null) continue;
      acc.putIfAbsent(group.id, () => _CountAccumulator(group)).count++;
    }

    final result = acc.values
        .map(
          (value) =>
              MuscleGroupWorkoutCount(group: value.group, count: value.count),
        )
        .toList();
    result.sort((a, b) => b.count.compareTo(a.count));
    return result;
  }

  Future<void> close() => _db.close();

  // --- Helpers ---

  Future<void> _ensureGroupsExist(List<String> groupIds) async {
    if (groupIds.isEmpty) return;
    final unique = groupIds.toSet().toList();
    final existing = await (_db.select(
      _db.muscleGroups,
    )..where((tbl) => tbl.id.isIn(unique))).get();
    if (existing.length != unique.length) {
      throw RepositoryException('One or more muscle groups no longer exist.');
    }
  }

  List<MuscleGroupNode> _buildTree(List<MuscleGroup> groups) {
    final builders = <String, _NodeBuilder>{
      for (final group in groups) group.id: _NodeBuilder(group),
    };

    for (final builder in builders.values) {
      final parentId = builder.group.parentId;
      if (parentId != null) {
        final parent = builders[parentId];
        parent?.children.add(builder);
      }
    }

    final roots = builders.values
        .where(
          (builder) =>
              builder.group.parentId == null ||
              !builders.containsKey(builder.group.parentId),
        )
        .toList();

    MuscleGroupNode toNode(_NodeBuilder builder) {
      builder.children.sort((a, b) => a.group.name.compareTo(b.group.name));
      return MuscleGroupNode(
        group: builder.group,
        children: builder.children.map(toNode).toList(),
      );
    }

    roots.sort((a, b) => a.group.name.compareTo(b.group.name));
    return roots.map(toNode).toList();
  }

  JoinedSelectStatement<dynamic, dynamic> _exerciseQuery(
    List<String>? groupIds,
  ) {
    final base = _db.select(_db.exercises);
    final join = base.join([
      leftOuterJoin(
        _db.exerciseMuscleGroups,
        _db.exerciseMuscleGroups.exerciseId.equalsExp(_db.exercises.id),
      ),
      leftOuterJoin(
        _db.muscleGroups,
        _db.muscleGroups.id.equalsExp(_db.exerciseMuscleGroups.groupId),
      ),
    ]);

    if (groupIds != null && groupIds.isNotEmpty) {
      join.where(_db.exerciseMuscleGroups.groupId.isIn(groupIds));
    }

    return join;
  }

  List<ExerciseDetail> _mapExerciseRows(List<TypedResult> rows) {
    final grouped = groupBy<TypedResult, String>(
      rows,
      (row) => row.readTable(_db.exercises).id,
    );

    final details = <ExerciseDetail>[];
    for (final entry in grouped.entries) {
      final exercise = entry.value.first.readTable(_db.exercises);
      final groups =
          entry.value
              .map((row) => row.readTableOrNull(_db.muscleGroups))
              .whereType<MuscleGroup>()
              .toSet()
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      details.add(ExerciseDetail(exercise: exercise, groups: groups));
    }

    details.sort((a, b) => a.exercise.name.compareTo(b.exercise.name));
    return details;
  }

  JoinedSelectStatement<dynamic, dynamic> _workoutLogJoin() {
    final base = _db.select(_db.workoutLogs);
    final join = base.join([
      leftOuterJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.workoutLogs.exerciseId),
      ),
      leftOuterJoin(
        _db.exerciseMuscleGroups,
        _db.exerciseMuscleGroups.exerciseId.equalsExp(_db.exercises.id),
      ),
      leftOuterJoin(
        _db.muscleGroups,
        _db.muscleGroups.id.equalsExp(_db.exerciseMuscleGroups.groupId),
      ),
    ]);
    return join;
  }

  List<WorkoutLogDetail> _mapWorkoutLogRows(List<TypedResult> rows) {
    final grouped = groupBy<TypedResult, String>(
      rows,
      (row) => row.readTable(_db.workoutLogs).id,
    );

    final details = <WorkoutLogDetail>[];
    for (final entry in grouped.entries) {
      final log = entry.value.first.readTable(_db.workoutLogs);
      final exercise = entry.value.first.readTableOrNull(_db.exercises);
      final groups =
          entry.value
              .map((row) => row.readTableOrNull(_db.muscleGroups))
              .whereType<MuscleGroup>()
              .toSet()
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      details.add(
        WorkoutLogDetail(log: log, exercise: exercise, groups: groups),
      );
    }

    details.sort((a, b) => b.log.performedAt.compareTo(a.log.performedAt));
    return details;
  }
}

class MuscleGroupNode {
  final MuscleGroup group;
  final List<MuscleGroupNode> children;
  const MuscleGroupNode({required this.group, this.children = const []});
}

class ExerciseDetail {
  final Exercise exercise;
  final List<MuscleGroup> groups;
  const ExerciseDetail({required this.exercise, required this.groups});
}

class WorkoutLogDetail {
  final WorkoutLog log;
  final Exercise? exercise;
  final List<MuscleGroup> groups;
  const WorkoutLogDetail({
    required this.log,
    required this.exercise,
    required this.groups,
  });
}

class MuscleGroupVolume {
  final MuscleGroup group;
  final double totalVolume;
  const MuscleGroupVolume({required this.group, required this.totalVolume});
}

class MuscleGroupWorkoutCount {
  final MuscleGroup group;
  final int count;
  const MuscleGroupWorkoutCount({required this.group, required this.count});
}

class _NodeBuilder {
  final MuscleGroup group;
  final List<_NodeBuilder> children = [];
  _NodeBuilder(this.group);
}

class _VolumeAccumulator {
  final MuscleGroup group;
  double volume = 0;
  _VolumeAccumulator(this.group);
}

class _CountAccumulator {
  final MuscleGroup group;
  int count = 0;
  _CountAccumulator(this.group);
}
