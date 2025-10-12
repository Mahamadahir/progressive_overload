import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class MuscleGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();

  TextColumn get parentId => text().nullable().customConstraint(
    'REFERENCES muscle_groups(id) ON DELETE SET NULL',
  )();

  IntColumn get createdAt =>
      integer().clientDefault(() => DateTime.now().millisecondsSinceEpoch)();

  IntColumn get updatedAt =>
      integer().clientDefault(() => DateTime.now().millisecondsSinceEpoch)();

  @override
  Set<Column> get primaryKey => {id};
}

class Exercises extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get notes => text().nullable()();

  RealColumn get startWeightKg => real().withDefault(const Constant(0.0))();
  IntColumn get minReps => integer().withDefault(const Constant(6))();
  IntColumn get maxReps => integer().withDefault(const Constant(12))();
  RealColumn get incrementKg => real().withDefault(const Constant(2.0))();
  RealColumn get defaultMets => real().withDefault(const Constant(3.0))();

  IntColumn get createdAt =>
      integer().clientDefault(() => DateTime.now().millisecondsSinceEpoch)();

  IntColumn get updatedAt =>
      integer().clientDefault(() => DateTime.now().millisecondsSinceEpoch)();

  @override
  Set<Column> get primaryKey => {id};
}

class ExerciseMuscleGroups extends Table {
  TextColumn get exerciseId =>
      text().references(Exercises, #id, onDelete: KeyAction.cascade)();

  TextColumn get groupId =>
      text().references(MuscleGroups, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {exerciseId, groupId};
}

class Workouts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().nullable()();

  IntColumn get createdAt =>
      integer().clientDefault(() => DateTime.now().millisecondsSinceEpoch)();

  TextColumn get planId => text().nullable()();

  IntColumn get updatedAt =>
      integer().clientDefault(() => DateTime.now().millisecondsSinceEpoch)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {planId},
  ];
}

class WorkoutLogs extends Table {
  TextColumn get id => text()();
  TextColumn get workoutId =>
      text().references(Workouts, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId => text().nullable().references(
    Exercises,
    #id,
    onDelete: KeyAction.setNull,
  )();

  IntColumn get performedAt =>
      integer().clientDefault(() => DateTime.now().millisecondsSinceEpoch)();
  IntColumn get sets => integer()();
  IntColumn get reps => integer()();

  RealColumn get weightKg => real().nullable()();
  RealColumn get energyKcal => real()();
  RealColumn get metsUsed => real()();

  @override
  Set<Column> get primaryKey => {id};
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(
  tables: [
    MuscleGroups,
    Exercises,
    ExerciseMuscleGroups,
    Workouts,
    WorkoutLogs,
  ],
  daos: [MuscleGroupDao, ExerciseDao, WorkoutDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  late final MuscleGroupDao muscleGroupDao = MuscleGroupDao(this);
  late final ExerciseDao exerciseDao = ExerciseDao(this);
  late final WorkoutDao workoutDao = WorkoutDao(this);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await runAfterOpenMigrations();
    },
  );

  Future<void> runAfterOpenMigrations() async {
    await _seedInitialMuscleGroups();
  }

  Future<void> _seedInitialMuscleGroups() async {
    const seedGroups = [
      _PresetGroup(
        id: '00000000-0000-4000-8000-000000000001',
        name: 'Upper Body',
      ),
      _PresetGroup(
        id: '00000000-0000-4000-8000-000000000002',
        name: 'Lower Body',
      ),
    ];

    for (final preset in seedGroups) {
      final exists = await (select(
        muscleGroups,
      )..where((tbl) => tbl.name.equals(preset.name))).getSingleOrNull();

      if (exists == null) {
        await into(muscleGroups).insert(
          MuscleGroupsCompanion.insert(
            id: preset.id,
            name: preset.name,
            parentId: const Value.absent(),
          ),
        );
      }
    }
  }
}

class _PresetGroup {
  final String id;
  final String name;

  const _PresetGroup({required this.id, required this.name});
}

@DriftAccessor(tables: [MuscleGroups])
class MuscleGroupDao extends DatabaseAccessor<AppDatabase>
    with _$MuscleGroupDaoMixin {
  MuscleGroupDao(AppDatabase db) : super(db);

  Stream<List<MuscleGroup>> watchAll() => select(muscleGroups).watch();

  Future<List<MuscleGroup>> getAll() => select(muscleGroups).get();

  Future<MuscleGroup?> findById(String id) => (select(
    muscleGroups,
  )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<int> insertGroup(MuscleGroupsCompanion entry) =>
      into(muscleGroups).insert(entry);

  Future<bool> updateGroup(MuscleGroup entity) =>
      update(muscleGroups).replace(entity);

  Future<int> deleteGroup(String id) =>
      (delete(muscleGroups)..where((tbl) => tbl.id.equals(id))).go();
}

@DriftAccessor(tables: [Exercises, ExerciseMuscleGroups])
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin {
  ExerciseDao(AppDatabase db) : super(db);

  Stream<List<Exercise>> watchAll() => select(exercises).watch();

  Future<List<Exercise>> getAll() => select(exercises).get();

  Future<Exercise?> findById(String id) =>
      (select(exercises)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<int> insertExercise(ExercisesCompanion entry) =>
      into(exercises).insert(entry);

  Future<bool> updateExercise(Exercise entity) =>
      update(exercises).replace(entity);

  Future<int> deleteExercise(String id) =>
      (delete(exercises)..where((tbl) => tbl.id.equals(id))).go();

  Future<void> replaceExerciseGroups({
    required String exerciseId,
    required List<String> groupIds,
  }) async {
    await (delete(
      exerciseMuscleGroups,
    )..where((tbl) => tbl.exerciseId.equals(exerciseId))).go();

    if (groupIds.isEmpty) {
      return;
    }

    await batch((batch) {
      batch.insertAll(
        exerciseMuscleGroups,
        groupIds
            .map(
              (groupId) => ExerciseMuscleGroupsCompanion.insert(
                exerciseId: exerciseId,
                groupId: groupId,
              ),
            )
            .toList(),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  Future<List<String>> groupIdsForExercise(String exerciseId) async {
    final query = select(exerciseMuscleGroups)
      ..where((tbl) => tbl.exerciseId.equals(exerciseId));
    final rows = await query.get();
    return rows.map((row) => row.groupId).toList();
  }
}

@DriftAccessor(tables: [Workouts, WorkoutLogs])
class WorkoutDao extends DatabaseAccessor<AppDatabase> with _$WorkoutDaoMixin {
  WorkoutDao(AppDatabase db) : super(db);

  Stream<List<Workout>> watchAllWorkouts() => select(workouts).watch();

  Future<Workout?> findById(String id) =>
      (select(workouts)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<Workout?> findByPlanId(String planId) => (select(
    workouts,
  )..where((tbl) => tbl.planId.equals(planId))).getSingleOrNull();

  Future<int> insertWorkout(WorkoutsCompanion entry) =>
      into(workouts).insert(entry);

  Future<bool> updateWorkout(Workout entity) =>
      update(workouts).replace(entity);

  Future<int> deleteWorkout(String id) =>
      (delete(workouts)..where((tbl) => tbl.id.equals(id))).go();

  Stream<List<WorkoutLog>> watchLogsForWorkout(String workoutId) => (select(
    workoutLogs,
  )..where((tbl) => tbl.workoutId.equals(workoutId))).watch();

  Future<List<WorkoutLog>> logsForWorkout(String workoutId) => (select(
    workoutLogs,
  )..where((tbl) => tbl.workoutId.equals(workoutId))).get();

  Future<int> insertLog(WorkoutLogsCompanion entry) =>
      into(workoutLogs).insert(entry);

  Future<int> deleteLog(String id) =>
      (delete(workoutLogs)..where((tbl) => tbl.id.equals(id))).go();
}
