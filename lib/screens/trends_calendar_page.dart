// lib/screens/trends_calendar_page.dart
import 'package:fitness_app/health_singleton.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:hive/hive.dart';

import '../services/meal_service.dart';
import '../services/health_service.dart';
import '../services/health_history_permission.dart';
import '../models/meal_log.dart';

class TrendsCalendarPage extends StatefulWidget {
  const TrendsCalendarPage({super.key});

  @override
  State<TrendsCalendarPage> createState() => _TrendsCalendarPageState();
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Stat(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(value),
        ],
      ),
    );
  }
}

class _TrendsCalendarPageState extends State<TrendsCalendarPage> {
  final _meal = MealService();
  final _health = HealthService();

  late final Box _settings;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  String? _error;

  /// yyyy-mm-dd -> summary
  Map<String, _DaySummary> _days = {};

  double get _targetKcal =>
      ((_settings.get('target_net_loss_kcal') as num?)?.toDouble()) ?? 0.0;
  int get _stepsGoal => (_settings.get('steps_goal') as int?) ?? 0;

  @override
  void initState() {
    super.initState();
    _settings = Hive.box('settings');
    _loadMonth();
  }

  DateTime _monthStart(DateTime m) => DateTime(m.year, m.month, 1);
  DateTime _monthEndExclusive(DateTime m) =>
      DateTime(m.year, m.month + 1, 1); // exclusive

  Future<void> _loadMonth() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final start = _monthStart(_month);
    final end = _monthEndExclusive(_month);

    try {
      await HealthHistoryPermission.ensureHistoryPermission();

      final granted = await health.hasPermissions(
        [HealthDataType.DISTANCE_DELTA],
        permissions: [HealthDataAccess.READ],
      );

      // Batch all data for the month
      final intake = _meal.intakeByDay(start, end);
      final meals = _meal.mealsByDay(start, end);

      // Cached Health fetchers (today always re-fetched)
      final burned = await _health.getCaloriesBurnedByDayCached(
        start,
        end,
      ); // Map<String,double>
      final steps = await _health.getStepsByDayCached(
        start,
        end,
      ); // Map<String,int>
      final weight = await _health.getWeightByDayCached(
        start,
        end,
      ); // Map<String,double?>

      // Workouts aggregation (no cached variant)
      final wAgg = await HealthServiceTrends(
        _health,
      ).getWorkoutAggByDay(start, end); // Map<String, ({int count, int kcal})>

      // Build per-day summaries
      final days = <String, _DaySummary>{};
      DateTime cursor = start;
      while (cursor.isBefore(end)) {
        final key = _key(cursor);
        final inKcal = intake[key] ?? 0.0;
        final outKcal = burned[key] ?? 0.0;
        final netLoss = outKcal - inKcal;

        days[key] = _DaySummary(
          date: cursor,
          kcalIn: inKcal,
          kcalOut: outKcal,
          netKcal: netLoss,
          meals: meals[key] ?? const [],
          steps: steps[key],
          weightKg: weight[key],
          workoutsCount: wAgg[key]?.count ?? 0,
          workoutsKcal: wAgg[key]?.kcal ?? 0,
        );
        cursor = cursor.add(const Duration(days: 1));
      }

      if (!mounted) return;
      setState(() {
        _days = days;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _clearHealthCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear cached health data?'),
        content: const Text(
          'This removes locally cached calories, steps, and weight. '
          'Fresh data will be fetched from Health Connect next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await Hive.box('health_cache').clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Health cache cleared')));
      await _loadMonth();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not clear cache: $error')));
    }
  }

  /// --- NEW: Day reload helper (fresh pull for a single day) ---
  Future<_DaySummary> _fetchDaySummary(DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final key = _key(dayStart);

    // Meals / intake (Hive)
    final intake = _meal.intakeByDay(dayStart, dayEnd)[key] ?? 0.0;
    final meals = _meal.mealsByDay(dayStart, dayEnd)[key] ?? const <MealLog>[];

    // Health Connect (fast paths)
    final burnedMap = await _health.getCaloriesBurnedByDayFast(
      dayStart,
      dayEnd,
    );
    final burned = burnedMap[key] ?? 0.0;

    final stepsFast = await _health.getStepsByDayFast(
      dayStart,
      dayEnd,
    ); // Map<String,double>
    final steps = stepsFast[key]?.round();

    final weightMap = await HealthServiceTrends(
      _health,
    ).getWeightByDay(dayStart, dayEnd); // Map<String,double?>
    final weight = weightMap[key];

    final wAgg = await HealthServiceTrends(_health).getWorkoutAggByDay(
      dayStart,
      dayEnd,
    ); // Map<String,({int count,int kcal})>
    final workouts = wAgg[key];

    return _DaySummary(
      date: dayStart,
      kcalIn: intake,
      kcalOut: burned,
      netKcal: burned - intake,
      meals: meals,
      steps: steps,
      weightKg: weight,
      workoutsCount: workouts?.count ?? 0,
      workoutsKcal: workouts?.kcal ?? 0,
    );
  }

  String _key(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  void _prevMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1);
    });
    _loadMonth();
  }

  void _nextMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month + 1);
    });
    _loadMonth();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final first = _monthStart(_month);
    final firstWeekday = first.weekday % 7; // make Sunday=0
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final totalCells = ((firstWeekday + daysInMonth + 6) ~/ 7) * 7;

    final viewingCurrentMonth =
        (_month.year == today.year && _month.month == today.month);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${_month.year}-${_month.month.toString().padLeft(2, '0')}",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Previous month',
          icon: const Icon(Icons.chevron_left),
          onPressed: _loading ? null : _prevMonth,
        ),
        actions: [
          IconButton(
            tooltip: 'Today',
            onPressed: _loading
                ? null
                : () {
                    setState(() {
                      _month = DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                      );
                    });
                    _loadMonth();
                  },
            icon: const Icon(Icons.today),
          ),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right),
            // disable going to future months beyond current
            onPressed: (_loading || viewingCurrentMonth) ? null : _nextMonth,
          ),
          IconButton(
            tooltip: 'Reload month',
            onPressed: _loading ? null : _loadMonth,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Clear cached health data',
            onPressed: _loading ? null : _clearHealthCache,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : Column(
              children: [
                // Weekday headers
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: const [
                      _Wd('Sun'),
                      _Wd('Mon'),
                      _Wd('Tue'),
                      _Wd('Wed'),
                      _Wd('Thu'),
                      _Wd('Fri'),
                      _Wd('Sat'),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: totalCells,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                    itemBuilder: (_, i) {
                      final dayNum = i - firstWeekday + 1;
                      if (dayNum < 1 || dayNum > daysInMonth) {
                        return const _DayCell.empty();
                      }
                      final date = DateTime(_month.year, _month.month, dayNum);
                      final key = _key(date);
                      final d = _days[key];

                      // status: green if net target met, red if missed (when a target is set)
                      final target = _targetKcal;
                      Color? bg;
                      if (target > 0 && d != null) {
                        bg = (d.netKcal >= target)
                            ? Colors.green.shade100
                            : Colors.red.shade100;
                      }

                      // steps badge if goal met
                      final stepsGoal = _stepsGoal;
                      final stepsOk =
                          stepsGoal > 0 && (d?.steps ?? 0) >= stepsGoal;

                      // disable days strictly after today
                      final isFutureDay = date.isAfter(todayDate);
                      final enabled = !isFutureDay;

                      return _DayCell(
                        date: date,
                        background: enabled
                            ? bg
                            : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.25),
                        stepsOk: stepsOk,
                        enabled: enabled,
                        onTap: enabled
                            ? () => _openDetails(d ?? _DaySummary(date: date))
                            : null,
                        summary: d,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _openDetails(_DaySummary d) {
    // local, mutable copy for the sheet
    _DaySummary sheetSummary = d;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StatefulBuilder(
            builder: (context, setStateSheet) {
              final meals = sheetSummary.meals;
              return ListView(
                controller: controller,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        "${sheetSummary.date.year}-${sheetSummary.date.month.toString().padLeft(2, '0')}-${sheetSummary.date.day.toString().padLeft(2, '0')}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Reload this day',
                        icon: const Icon(Icons.refresh),
                        onPressed: () async {
                          final fresh = await _fetchDaySummary(
                            sheetSummary.date,
                          );
                          if (!mounted) return;
                          // Update calendar backing map
                          setState(() {
                            _days[_key(sheetSummary.date)] = fresh;
                          });
                          // Update the open sheet
                          setStateSheet(() {
                            sheetSummary = fresh;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    runSpacing: 8,
                    spacing: 8,
                    children: [
                      _Stat(
                        'Kcal in',
                        sheetSummary.kcalIn.toStringAsFixed(0),
                        Icons.restaurant,
                      ),
                      _Stat(
                        'Kcal out',
                        sheetSummary.kcalOut.toStringAsFixed(0),
                        Icons.local_fire_department,
                      ),
                      _Stat(
                        'Net',
                        sheetSummary.netKcal.toStringAsFixed(0),
                        Icons.balance,
                      ),
                      _Stat(
                        'Steps',
                        (sheetSummary.steps ?? 0).toString(),
                        Icons.directions_walk,
                      ),
                      _Stat(
                        'Weight',
                        sheetSummary.weightKg == null
                            ? '—'
                            : "${sheetSummary.weightKg!.toStringAsFixed(1)} kg",
                        Icons.monitor_weight,
                      ),
                      _Stat(
                        'Workouts',
                        sheetSummary.workoutsCount.toString(),
                        Icons.fitness_center,
                      ),
                      if (sheetSummary.workoutsKcal > 0)
                        _Stat(
                          'Workout kcal',
                          sheetSummary.workoutsKcal.toString(),
                          Icons.local_fire_department,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Meals',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (meals.isEmpty)
                    const Text('No meals logged.')
                  else
                    ...meals.map(
                      (m) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.restaurant_menu),
                        title: Text(m.name),
                        subtitle: Text(
                          '${m.massGrams.toStringAsFixed(0)} g • ${m.kcal.toStringAsFixed(0)} kcal',
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Wd extends StatelessWidget {
  final String t;
  const _Wd(this.t);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Center(
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );
}

class _DayCell extends StatelessWidget {
  final DateTime? date;
  final Color? background;
  final bool stepsOk;
  final VoidCallback? onTap;
  final _DaySummary? summary;
  final bool enabled;

  const _DayCell({
    this.date,
    this.background,
    this.stepsOk = false,
    this.onTap,
    this.summary,
    this.enabled = true,
  });

  const _DayCell.empty()
    : date = null,
      background = null,
      stepsOk = false,
      onTap = null,
      summary = null,
      enabled = false;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    final text = Text(
      '${date!.day}',
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: enabled ? null : Colors.grey,
      ),
    );

    return Material(
      color:
          background ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              Align(alignment: Alignment.topLeft, child: text),
              if (summary != null)
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    // tiny preview: net kcal
                    summary!.netKcal.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 11,
                      color: enabled
                          ? Colors.black.withValues(alpha: 0.7)
                          : Colors.grey.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (stepsOk && enabled)
                const Align(
                  alignment: Alignment.topRight,
                  child: Icon(Icons.directions_walk, size: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySummary {
  final DateTime date;
  final double kcalIn;
  final double kcalOut;
  final double netKcal; // out - in
  final List<MealLog> meals;
  final int? steps;
  final double? weightKg;
  final int workoutsCount;
  final int workoutsKcal;

  _DaySummary({
    required this.date,
    this.kcalIn = 0,
    this.kcalOut = 0,
    this.netKcal = 0,
    this.meals = const [],
    this.steps,
    this.weightKg,
    this.workoutsCount = 0,
    this.workoutsKcal = 0,
  });
}
