import 'package:flutter/material.dart';
import 'package:hive/hive.dart';           // for TypeAdapter + registerAdapter<T>
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

// Models (limit symbols to avoid clashes)
import 'models/meal_template.dart';
import 'models/meal_log.dart' show MealLog, MealLogAdapter;
import 'models/food_component.dart';
import 'models/meal_component_line.dart'; // provides both line + snapshot
import 'models/calorie_entry.dart';
import 'models/workout_plan.dart' show PlanExerciseState, PlanExerciseStateAdapter, WorkoutPlan, WorkoutPlanAdapter; // scoped
import 'models/workout_log.dart' show WorkoutLog, WorkoutLogAdapter;     // scoped

// Services
import 'services/notification_service.dart';
import 'services/meal_service.dart';

// App + Health
import 'app.dart';
import 'health_singleton.dart';
import 'database/database_provider.dart';

class HealthBootstrapper extends StatefulWidget {
  final Widget child;
  const HealthBootstrapper({super.key, required this.child});

  @override
  State<HealthBootstrapper> createState() => _HealthBootstrapperState();
}

class _HealthBootstrapperState extends State<HealthBootstrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await health.configure();
        final status = await health.getHealthConnectSdkStatus();
        debugPrint('HC status: $status');
      } catch (e, st) {
        debugPrint('Health bootstrap error: $e\n$st');
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(dir.path);

  // ---------- Register Hive adapters (explicit generics; no dynamic) ----------
  void registerAdapterSafely<T>(TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter<T>(adapter);
    }
  }

  registerAdapterSafely<CalorieEntry>(CalorieEntryAdapter());\n  registerAdapterSafely<PlanExerciseState>(PlanExerciseStateAdapter());
  registerAdapterSafely<WorkoutPlan>(WorkoutPlanAdapter());
  registerAdapterSafely<WorkoutLog>(WorkoutLogAdapter());        // NEW
  registerAdapterSafely<MealTemplate>(MealTemplateAdapter());
  registerAdapterSafely<MealLog>(MealLogAdapter());
  registerAdapterSafely<FoodComponent>(FoodComponentAdapter());
  registerAdapterSafely<MealComponentLine>(MealComponentLineAdapter());
  registerAdapterSafely<MealComponentSnapshot>(MealComponentSnapshotAdapter());

  // ---------- Open boxes ----------
  await Future.wait([
    Hive.openBox<CalorieEntry>('calories'),
    Hive.openBox<WorkoutPlan>('plans'),
    Hive.openBox<WorkoutLog>('plan_logs'), // unambiguous
    Hive.openBox('settings'),
    Hive.openBox<MealTemplate>('meal_templates'),
    Hive.openBox<MealLog>('meal_logs'),
    Hive.openBox<FoodComponent>('food_components'),
    Hive.openBox('health_cache'),
    NotificationService.init(),
  ]);

  // ---------- Seed defaults ----------
  await MealService().seedDefaultsIfEmpty();

  // ---------- Initialize Drift (SQLite) ----------
  await initDriftDatabase();
}

void main() async {
  try {
    await bootstrap();
  } catch (e, st) {
    debugPrint('Bootstrap error: $e\n$st');
  }

  runApp(
    HealthBootstrapper(
      child: const App(),
    ),
  );
}


