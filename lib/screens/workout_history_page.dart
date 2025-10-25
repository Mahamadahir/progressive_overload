import 'package:flutter/material.dart';

import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/repositories/drift_repository.dart';

class WorkoutHistoryPage extends StatefulWidget {
  const WorkoutHistoryPage({super.key});

  @override
  State<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage> {
  static const Duration _historySpan = Duration(days: 180);

  final List<WorkoutLogDetail> _entries = <WorkoutLogDetail>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final end = DateTime.now();
      final start = end.subtract(_historySpan);
      final history = await driftRepository.getWorkoutHistory(
        start: start,
        end: end,
      );
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(history);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDateTime(DateTime dateTime) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(dateTime.day)}/${two(dateTime.month)}/${dateTime.year} '
        '${two(dateTime.hour)}:${two(dateTime.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _entries.isEmpty
          ? Center(
              child: Text(
                'No workouts logged in the last ${_historySpan.inDays} days.',
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _entries.length,
                separatorBuilder: (context, _) => const Divider(height: 0),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  final log = entry.log;
                  final performedAt = DateTime.fromMillisecondsSinceEpoch(
                    log.performedAt,
                  );
                  final exerciseName = entry.exercise?.name ?? 'Exercise';
                  final workoutName = entry.workout?.name;
                  final groupLabel = entry.groups.isEmpty
                      ? null
                      : entry.groups.map((g) => g.name).join(', ');

                  final summaryParts = <String>[
                    '${log.sets} sets',
                    '${log.reps} reps total',
                    if (log.weightKg != null)
                      '${log.weightKg!.toStringAsFixed(1)} kg',
                    '${log.energyKcal.toStringAsFixed(1)} kcal',
                    '${log.metsUsed.toStringAsFixed(1)} METs',
                  ];

                  final subtitleLines = <String>[
                    '${_formatDateTime(performedAt)}'
                        '${workoutName == null ? '' : ' • $workoutName'}',
                    summaryParts.join(' • '),
                    if (groupLabel != null) 'Targets: $groupLabel',
                  ];

                  return ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: Text(exerciseName),
                    subtitle: Text(subtitleLines.join('\n')),
                    isThreeLine: true,
                  );
                },
              ),
            ),
    );
  }
}
