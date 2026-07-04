import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/services/health_service.dart';
import 'package:fitness_app/services/workout_service.dart';
import 'package:fitness_app/repositories/drift_repository.dart';

part 'vitality_hub_widgets.dart';

class VitalityHubPage extends StatefulWidget {
  const VitalityHubPage({super.key});

  @override
  State<VitalityHubPage> createState() => _VitalityHubPageState();
}

class _VitalityHubPageState extends State<VitalityHubPage> {
  final _health = HealthService();
  final _workouts = WorkoutService();
  final DriftRepository _repository = driftRepository;

  late Future<_VitalityData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_VitalityData> _load() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 6));

    final hasPerms = await HealthService.hasAllPrioritizedPermissions();
    final plans = _workouts.getPlans();
    final logs = await _repository.getRecentWorkoutLogs(limit: 5);
    Map<String, int> steps = const {};
    Map<String, Duration> sleep = const {};
    if (hasPerms) {
      steps = await _health.getStepsByDayCached(start, now);
      sleep = await _health.getSleepByDay(start, now);
    }
    final fetchedAt = DateTime.now();

    return _VitalityData(
      stepsByDay: steps,
      sleepByDay: sleep,
      recentWorkouts: logs,
      plans: plans,
      fetchedAt: fetchedAt,
      hasPermissions: hasPerms,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vitality Hub'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _future = _load();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<_VitalityData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _future = _load();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!data.hasPermissions)
                _PermissionBanner(onRequest: _requestPermissions),
              _LastUpdatedLabel(timestamp: data.fetchedAt),
              const SizedBox(height: 8),
              _NextSessionCard(
                plans: data.plans,
                recentWorkouts: data.recentWorkouts,
              ),
              const SizedBox(height: 12),
              _StepsChart(stepsByDay: data.stepsByDay),
              const SizedBox(height: 16),
              _SleepChart(sleepByDay: data.sleepByDay),
              const SizedBox(height: 16),
              if (data.recentWorkouts.isNotEmpty)
                _RecentWorkoutCard(recentWorkouts: data.recentWorkouts),
              if (data.recentWorkouts.isEmpty)
                const Text('No recent workouts', textAlign: TextAlign.center),
            ],
          );
        },
      ),
    );
  }

  Future<void> _requestPermissions() async {
    await HealthService.requestAllPrioritizedPermissions();
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }
}
