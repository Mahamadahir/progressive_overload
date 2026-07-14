import 'dart:ffi';
import 'dart:io';

import 'package:fitness_app/models/food_component.dart';
import 'package:fitness_app/models/meal_component_line.dart';
import 'package:fitness_app/models/meal_log.dart';
import 'package:fitness_app/models/meal_template.dart';
import 'package:fitness_app/models/workout_log.dart' as workout_log;
import 'package:fitness_app/models/workout_plan.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sqlite3/open.dart';

Future<void> initialiseHive() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureSqliteForTests();
  final dir = await Directory.systemTemp.createTemp('fitness_app_test_');
  Hive.init(dir.path);

  void register<T>(TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter<T>(adapter);
    }
  }

  register<PlanExerciseState>(PlanExerciseStateAdapter());
  register<WorkoutPlan>(WorkoutPlanAdapter());
  register<workout_log.WorkoutLog>(workout_log.WorkoutLogAdapter());
  register<MealTemplate>(MealTemplateAdapter());
  register<MealLog>(MealLogAdapter());
  register<FoodComponent>(FoodComponentAdapter());
  register<MealComponentLine>(MealComponentLineAdapter());
  register<MealComponentSnapshot>(MealComponentSnapshotAdapter());
}

void configureSqliteForTests() {
  if (Platform.isLinux &&
      File('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0').existsSync()) {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0'),
    );
  }
}

Future<void> openCoreHiveBoxes() async {
  if (!Hive.isBoxOpen('plans')) {
    await Hive.openBox<WorkoutPlan>('plans');
  }
  if (!Hive.isBoxOpen('plan_logs')) {
    await Hive.openBox<workout_log.WorkoutLog>('plan_logs');
  }
  if (!Hive.isBoxOpen('meal_templates')) {
    await Hive.openBox<MealTemplate>('meal_templates');
  }
  if (!Hive.isBoxOpen('meal_logs')) {
    await Hive.openBox<MealLog>('meal_logs');
  }
  if (!Hive.isBoxOpen('food_components')) {
    await Hive.openBox<FoodComponent>('food_components');
  }
  if (!Hive.isBoxOpen('health_cache')) {
    await Hive.openBox('health_cache');
  }
  if (!Hive.isBoxOpen('settings')) {
    await Hive.openBox('settings');
  }
}

Future<void> clearCoreHiveBoxes() async {
  if (Hive.isBoxOpen('plans')) await Hive.box<WorkoutPlan>('plans').clear();
  if (Hive.isBoxOpen('plan_logs')) {
    await Hive.box<workout_log.WorkoutLog>('plan_logs').clear();
  }
  if (Hive.isBoxOpen('meal_templates')) {
    await Hive.box<MealTemplate>('meal_templates').clear();
  }
  if (Hive.isBoxOpen('meal_logs')) await Hive.box<MealLog>('meal_logs').clear();
  if (Hive.isBoxOpen('food_components')) {
    await Hive.box<FoodComponent>('food_components').clear();
  }
  if (Hive.isBoxOpen('health_cache')) await Hive.box('health_cache').clear();
  if (Hive.isBoxOpen('settings')) await Hive.box('settings').clear();
}

Future<void> closeHive() async {
  await Hive.close();
}

void mockHealthPluginChannels({List<MethodCall>? calls}) {
  const healthChannel = MethodChannel('flutter_health');
  const deviceInfoChannel = MethodChannel(
    'dev.fluttercommunity.plus/device_info',
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(deviceInfoChannel, (call) async {
        if (call.method == 'getDeviceInfo') {
          return <String, Object?>{
            'name': 'test',
            'systemName': 'iOS',
            'systemVersion': '17.0',
            'model': 'test',
            'modelName': 'test',
            'localizedModel': 'test',
            'identifierForVendor': 'test-device',
            'freeDiskSize': 1,
            'totalDiskSize': 1,
            'isPhysicalDevice': false,
            'physicalRamSize': 1,
            'availableRamSize': 1,
            'isiOSAppOnMac': false,
            'utsname': <String, Object?>{
              'sysname': 'Darwin',
              'nodename': 'test',
              'release': 'test',
              'version': 'test',
              'machine': 'test',
            },
          };
        }
        return null;
      });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(healthChannel, (call) async {
        calls?.add(call);
        switch (call.method) {
          case 'hasPermissions':
          case 'requestAuthorization':
          case 'writeWorkoutData':
            return true;
          case 'getData':
            return const <Object?>[];
        }
        return null;
      });
}

void resetPluginChannels() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('flutter_health'), null);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/device_info'),
        null,
      );
}
