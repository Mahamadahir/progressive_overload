import 'package:flutter/material.dart';

// Existing pages
import 'screens/calorie_summary_page.dart';
import 'screens/log_calories_page.dart';
import 'screens/trends_page.dart';
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

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness Tracker',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),

      // Dashboard is the default home
      home: const DashboardPage(),

      // Named routes for screens that DON'T need arguments
      routes: {
        '/plans': (context) => const PlanListPage(),
        '/calories': (context) => CalorieSummaryPage(),
        '/log_calories': (context) => LogCaloriesPage(),
        '/trends': (context) => TrendsPage(),
        '/workout': (context) => WorkoutSessionPage(),
        '/workout_history': (context) => WorkoutHistoryPage(),
        '/create_workout': (context) => const CreateWorkoutPage(),
        '/create_plan': (context) => const CreateWorkoutPage(), // backward compatibility
        '/exercises': (context) => const ExerciseListPage(),
        '/exercises/new': (context) => const CreateExercisePage(),
        // Settings renamed to Targets
        '/settings': (context) => const TargetsPage(),
      },

      // For screens that DO need arguments (e.g., planId), use onGenerateRoute
      onGenerateRoute: (settings) {
        switch (settings.name) {
        // SessionPage expects a String planId
          case '/session': {
            final planId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => SessionPage(planId: planId),
              settings: settings,
            );
          }

        // PlanDetailPage expects a String planId
          case '/plan_detail': {
            final planId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => PlanDetailPage(planId: planId),
              settings: settings,
            );
          }

        // PlanChartsPage expects a String planId
          case '/plan_charts': {
            final planId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => PlanChartsPage(planId: planId),
              settings: settings,
            );
          }
        }
        return null;
      },
    );
  }
}
