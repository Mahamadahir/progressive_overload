import 'package:fitness_app/database/app_database.dart';
import 'package:fitness_app/repositories/drift_repository.dart';
import 'package:meta/meta.dart';

AppDatabase? _appDatabaseOverride;
AppDatabase? _appDatabaseInstance;
DriftRepository? _repositoryOverride;
DriftRepository? _repositoryInstance;

AppDatabase get appDatabase =>
    _appDatabaseOverride ?? (_appDatabaseInstance ??= AppDatabase());

DriftRepository get driftRepository =>
    _repositoryOverride ??
    (_repositoryInstance ??= DriftRepository(appDatabase));

Future<void> initDriftDatabase() async {
  await appDatabase.customSelect('SELECT 1').get();
}

@visibleForTesting
void configureTestDatabase(AppDatabase database) {
  _appDatabaseOverride = database;
  _repositoryOverride = DriftRepository(database);
}

@visibleForTesting
void resetDatabaseOverrides() {
  _appDatabaseOverride = null;
  _repositoryOverride = null;
  _appDatabaseInstance = null;
  _repositoryInstance = null;
}
