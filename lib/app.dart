import 'package:flutter/material.dart';

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
import 'screens/plan_detail_page.dart';
import 'screens/plan_charts_page.dart';
import 'screens/exercise_list_page.dart';
import 'screens/create_exercise_page.dart';
import 'home_shell.dart';
import 'theme_controller.dart';

/// Brand amber from the design system. Drives the Material 3 colour scheme.
const Color _brandAmber = Color(0xFFF57C00);

class App extends StatelessWidget {
  const App({super.key});

  @visibleForTesting
  ThemeData buildLightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _brandAmber,
      brightness: Brightness.light,
    ).copyWith(primary: _brandAmber);
    return _themeFrom(scheme, const Color(0xFFFDF8F5));
  }

  @visibleForTesting
  ThemeData buildDarkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _brandAmber,
      brightness: Brightness.dark,
    ).copyWith(primary: _brandAmber, surfaceTint: Colors.transparent);
    return _themeFrom(scheme, const Color(0xFF131313));
  }

  ThemeData _themeFrom(ColorScheme scheme, Color scaffold) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
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
          home: const HomeShell(),
          routes: buildRoutes(),
          onGenerateRoute: handleGeneratedRoute,
        );
      },
    );
  }
}
