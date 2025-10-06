import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'models/meal_template.dart';
import 'models/meal_log.dart' show MealLog, MealLogAdapter;
import 'models/food_component.dart';
import 'models/meal_component_line.dart'; // provides both line + snapshot

import 'app.dart'; // ✅ Use App (which defines routes & home)
import 'models/calorie_entry.dart';
import 'models/workout_plan.dart';
import 'services/notification_service.dart';
import 'services/meal_service.dart';

// enums & types
import 'health_singleton.dart';            // shared health instance

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
    // After first frame so plugin is attached to Activity.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await health.configure();

        // ✅ Stop prompting on app startup; diagnostics/service will handle prompts.
        final status = await health.getHealthConnectSdkStatus();
        debugPrint('HC status: $status');

        // 🔕 COMMENTED OUT: no permission prompts here during debugging
        // if (status == HealthConnectSdkStatus.sdkAvailable) {
        //   ...
        // }
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

  // Register adapters safely (avoid "already registered" crashes)
  final calorieAdapter = CalorieEntryAdapter();
  if (!Hive.isAdapterRegistered(calorieAdapter.typeId)) {
    Hive.registerAdapter(calorieAdapter);
  }

  final workoutPlanAdapter = WorkoutPlanAdapter();
  if (!Hive.isAdapterRegistered(workoutPlanAdapter.typeId)) {
    Hive.registerAdapter(workoutPlanAdapter);
  }

  final workoutLogAdapter = WorkoutLogAdapter();
  if (!Hive.isAdapterRegistered(workoutLogAdapter.typeId)) {
    Hive.registerAdapter(workoutLogAdapter);
  }

  final mealTemplateAdapter = MealTemplateAdapter();
  if (!Hive.isAdapterRegistered(mealTemplateAdapter.typeId)) {
    Hive.registerAdapter(mealTemplateAdapter);
  }

  final mealLogAdapter = MealLogAdapter();
  if (!Hive.isAdapterRegistered(mealLogAdapter.typeId)) {
    Hive.registerAdapter(mealLogAdapter);
  }

  // 🔸 NEW: Register FoodComponent + MealComponentLine + MealComponentSnapshot
  final foodComponentAdapter = FoodComponentAdapter();
  if (!Hive.isAdapterRegistered(foodComponentAdapter.typeId)) {
    Hive.registerAdapter(foodComponentAdapter);
  }
  final mealComponentLineAdapter = MealComponentLineAdapter();
  if (!Hive.isAdapterRegistered(mealComponentLineAdapter.typeId)) {
    Hive.registerAdapter(mealComponentLineAdapter);
  }
  final mealComponentSnapshotAdapter = MealComponentSnapshotAdapter();
  if (!Hive.isAdapterRegistered(mealComponentSnapshotAdapter.typeId)) {
    Hive.registerAdapter(mealComponentSnapshotAdapter);
  }

  await Future.wait([
    Hive.openBox<CalorieEntry>('calories'),
    Hive.openBox<WorkoutPlan>('plans'),
    Hive.openBox<WorkoutLog>('plan_logs'),
    Hive.openBox('settings'),
    Hive.openBox<MealTemplate>('meal_templates'),
    Hive.openBox<MealLog>('meal_logs'),
    Hive.openBox<FoodComponent>('food_components'), // 🔸 NEW
    Hive.openBox('health_cache'),
    NotificationService.init(),
  ]);

  // ⭐ Seed default meals/components once (after Hive boxes are open)
  await MealService().seedDefaultsIfEmpty();
}

void main() async {
  try {
    await bootstrap();
  } catch (e, st) {
    debugPrint('Bootstrap error: $e\n$st');
  }
  // ✅ Use App as the root so its routes (including '/settings' -> TargetsPage) are active
  runApp(
    HealthBootstrapper(
      child: const App(),
    ),
  );
}
