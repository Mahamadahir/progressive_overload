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
          ? _EmptyHistory(days: _historySpan.inDays)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final scheme = Theme.of(context).colorScheme;
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
                    '${log.reps} reps',
                    if (log.weightKg != null)
                      '${log.weightKg!.toStringAsFixed(1)} kg',
                    '${log.energyKcal.toStringAsFixed(0)} kcal',
                  ];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            foregroundColor: scheme.onPrimaryContainer,
                            child: const Icon(Icons.fitness_center, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exerciseName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_formatDateTime(performedAt)}'
                                  '${workoutName == null ? '' : ' • $workoutName'}',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  summaryParts.join('  •  '),
                                  style: TextStyle(color: scheme.primary),
                                ),
                                if (groupLabel != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Targets: $groupLabel',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final int days;
  const _EmptyHistory({required this.days});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 56, color: scheme.primary),
          const SizedBox(height: 12),
          const Text('No workouts yet'),
          const SizedBox(height: 4),
          Text(
            'Nothing logged in the last $days days.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
