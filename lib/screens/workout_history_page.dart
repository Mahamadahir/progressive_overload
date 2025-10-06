import 'package:flutter/material.dart';
import 'package:health/health.dart';        // enums & types
import '../../health_singleton.dart';       // shared instance
import '../../services/health_service.dart';

class WorkoutHistoryPage extends StatefulWidget {
  const WorkoutHistoryPage({super.key});

  @override
  State<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage> {
  List<HealthDataPoint> _workouts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWorkoutHistory();
  }

  Future<void> _loadWorkoutHistory() async {
    setState(() { _loading = true; _error = null; });

    try {
      // Request READ for workouts via centralized service
      final ok = await HealthService.ensureAuthorized(
        types: const [HealthDataType.WORKOUT],
        permissions: const [HealthDataAccess.READ],
      );
      if (!ok) throw Exception('Authorization failed');

      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 30));

      final points = await health.getHealthDataFromTypes(
        startTime: from,
        endTime: now,
        types: const [HealthDataType.WORKOUT],
      );

      final strength = points.where((p) {
        final v = p.value;
        if (v is! WorkoutHealthValue) return false;
        return v.workoutActivityType == HealthWorkoutActivityType.STRENGTH_TRAINING;
      }).toList()
        ..sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

      setState(() { _workouts = strength; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _formatDateTime(DateTime dt) {
    final m = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return "$d/$mo/${dt.year} ${dt.hour}:$m";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
        actions: [
          IconButton(
            onPressed: _loadWorkoutHistory,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _workouts.isEmpty
          ? const Center(child: Text('No strength workouts found in the last 30 days.'))
          : RefreshIndicator(
        onRefresh: _loadWorkoutHistory,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _workouts.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (context, index) {
            final p = _workouts[index];
            final v = p.value as WorkoutHealthValue;

            final durationMin = p.dateTo.difference(p.dateFrom).inMinutes;
            final kcal = v.totalEnergyBurned; // int? (kcal)
            final meters = v.totalDistance;   // double? (meters)

            final subtitle = StringBuffer()
              ..write("📅 ${_formatDateTime(p.dateFrom)}\n")
              ..write("⏱️ $durationMin min");

            if (kcal != null) {
              subtitle.write("  |  🔥 $kcal kcal");
            }
            if (meters != null) {
              final km = (meters / 1000).toStringAsFixed(2);
              subtitle.write("  |  📏 $km km");
            }

            return ListTile(
              leading: const Icon(Icons.fitness_center),
              title: Text(
                v.workoutActivityType.name
                    .replaceAll('_', ' ')
                    .toLowerCase()
                    .split(' ')
                    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
                    .join(' '),
              ),
              subtitle: Text(subtitle.toString()),
              isThreeLine: true,
            );
          },
        ),
      ),
    );
  }
}
