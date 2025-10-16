import 'package:flutter/material.dart';
import 'package:health/health.dart' as hc; // new API uses Health (not HealthFactory)
import 'package:fitness_app/services/health_service.dart';
import '../services/health_history_permission.dart';

class WorkoutHistoryPage extends StatefulWidget {
  const WorkoutHistoryPage({super.key});

  @override
  State<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage> {
  // Up to 6 months; we’ll clamp to 30 days if history permission isn’t granted.
  static const Duration _historySpan = Duration(days: 180);

  late final hc.Health _health; // new plugin main class
  bool _configured = false;

  List<hc.HealthDataPoint> _workouts = [];
  bool _loading = true;
  String? _error;
  bool _distanceRequested = false;
  bool _historyGranted = false;

  @override
  void initState() {
    super.initState();
    _health = hc.Health();
    _loadWorkoutHistory();
  }

  /// Resolve a HealthDataType across plugin versions by enum name.
  hc.HealthDataType? _resolveType(List<String> candidateNames) {
    for (final name in candidateNames) {
      try { return hc.HealthDataType.values.byName(name); } catch (_) {}
    }
    return null;
  }

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure(); // required in the new API
    _configured = true;
  }

  Future<void> _loadWorkoutHistory() async {
    setState(() { _loading = true; _error = null; });

    try {
      await _ensureConfigured();

      // 1) Ask for history (>30d). If denied, we will clamp the query to 30 days.
      _historyGranted = await HealthHistoryPermission.ensureHistoryPermission();

      // 2) Build the permission set (handles old/new enum names)
      final distanceType = _resolveType([
        'DISTANCE_DELTA',            // newer plugin
        'DISTANCE_WALKING_RUNNING',  // older plugin
      ]);
      final energyType = _resolveType([
        'TOTAL_ENERGY_BURNED',       // newer plugin
        'ACTIVE_ENERGY_BURNED',      // older plugin
      ]);

      final types = <hc.HealthDataType>[
        hc.HealthDataType.WORKOUT,
        if (distanceType != null) distanceType,
        if (energyType != null) energyType,
      ];
      final perms = List<hc.HealthDataAccess>.filled(types.length, hc.HealthDataAccess.READ);

      _distanceRequested = distanceType != null;

      // Centralized auth (wraps plugin’s requestAuthorization)
      final ok = await HealthService.ensureAuthorized(types: types, permissions: perms);
      if (!ok) {
        throw Exception('Authorization failed (workout/distance/energy not granted).');
      }

      // Optional: confirm distance really granted to avoid plugin throwing
      if (_distanceRequested) {
        final hasDistance = await _health.hasPermissions(
          [distanceType!],
          permissions: const [hc.HealthDataAccess.READ],
        );
        if (hasDistance != true) {
          throw Exception('Distance permission not granted. Enable it to view workout distance.');
        }
      }

      // 3) Time range (clamp to 30d if history permission not granted)
      final now = DateTime.now();
      final from = now.subtract(_historyGranted ? _historySpan : const Duration(days: 30));

      // 4) Fetch workouts (via your service wrapper)
      final points = await HealthService.getWorkoutsInRange(start: from, end: now);

      // 5) Filter to Strength Training (keep your behavior)
      final strength = points.where((p) {
        final v = p.value;
        return v is hc.WorkoutHealthValue &&
            v.workoutActivityType == hc.HealthWorkoutActivityType.STRENGTH_TRAINING;
      }).toList()
        ..sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

      if (!mounted) return;
      setState(() { _workouts = strength; _loading = false; });

      if (!_historyGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History permission not granted — showing last 30 days only.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
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
    final subtitleWarning = (!_distanceRequested)
        ? ' (distance not requested — plugin version?)'
        : '';

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
                  ? Center(
                      child: Text(
                        'No strength workouts found in the last '
                        '${_historyGranted ? _historySpan.inDays : 30} days$subtitleWarning.',
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadWorkoutHistory,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _workouts.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (_, index) {
                          final p = _workouts[index];
                          final v = p.value as hc.WorkoutHealthValue;

                          final durationMin = p.dateTo.difference(p.dateFrom).inMinutes;
                          final kcal = v.totalEnergyBurned; // int? (kcal)
                          final meters = v.totalDistance;   // double? (meters)

                          final sb = StringBuffer()
                            ..write('📅 ${_formatDateTime(p.dateFrom)}\n')
                            ..write('⏱️ $durationMin min');

                          if (kcal != null) sb.write('  |  🔥 $kcal kcal');
                          if (meters != null) {
                            final km = (meters / 1000).toStringAsFixed(2);
                            sb.write('  |  📏 $km km');
                          }

                          final title = v.workoutActivityType.name
                              .replaceAll('_', ' ')
                              .toLowerCase()
                              .split(' ')
                              .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
                              .join(' ');

                          return ListTile(
                            leading: const Icon(Icons.fitness_center),
                            title: Text(title),
                            subtitle: Text(sb.toString()),
                            isThreeLine: true,
                          );
                        },
                      ),
                    ),
    );
  }
}
