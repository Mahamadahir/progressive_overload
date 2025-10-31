import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

// Existing pages
import 'screens/calorie_summary_page.dart';
import 'screens/log_calories_page.dart';
import 'screens/workout_session_page.dart';
import 'screens/workout_history_page.dart';
import 'screens/plan_list_page.dart';
import 'screens/create_workout_page.dart';
import 'screens/session_page.dart';
import 'screens/targets_page.dart';
// NEW pages
import 'screens/dashboard_page.dart';
import 'screens/plan_detail_page.dart';
import 'screens/plan_charts_page.dart';
import 'screens/exercise_list_page.dart';
import 'screens/create_exercise_page.dart';
import 'theme_controller.dart';

class App extends StatelessWidget {
  const App({super.key});

  @visibleForTesting
  ThemeData buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      iconTheme: const IconThemeData(color: Colors.blueAccent),
      useMaterial3: true,
    );
  }

  @visibleForTesting
  ThemeData buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blueAccent,
        brightness: Brightness.dark,
      ).copyWith(surface: Colors.black, surfaceTint: Colors.transparent),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.black,
      ),
      iconTheme: const IconThemeData(color: Colors.blueAccent),
      useMaterial3: true,
    );
  }

  @visibleForTesting
  Map<String, WidgetBuilder> buildRoutes() {
    return {
      '/plans': (context) => const PlanListPage(),
      '/calories': (context) => CalorieSummaryPage(),
      '/log_calories': (context) => LogCaloriesPage(),
      '/workout': (context) => WorkoutSessionPage(),
      '/workout_history': (context) => WorkoutHistoryPage(),
      '/create_workout': (context) => const CreateWorkoutPage(),
      // Backward compatibility for legacy entry point.
      '/create_plan': (context) => const CreateWorkoutPage(),
      '/exercises': (context) => const ExerciseListPage(),
      '/exercises/new': (context) => const CreateExercisePage(),
      // Settings renamed to Targets.
      '/settings': (context) => const TargetsPage(),
    };
  }

  @visibleForTesting
  Route<dynamic>? handleGeneratedRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/session':
        final planId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => SessionPage(planId: planId),
          settings: settings,
        );
      case '/plan_detail':
        final planId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => PlanDetailPage(planId: planId),
          settings: settings,
        );
      case '/plan_charts':
        final planId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => PlanChartsPage(planId: planId),
          settings: settings,
        );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Fitness Tracker',
          themeMode: themeController.mode,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          home: const DashboardPage(),
          routes: buildRoutes(),
          onGenerateRoute: handleGeneratedRoute,
        );
      },
    );
  }
}
