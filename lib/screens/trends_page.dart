import 'package:flutter/material.dart';
import '../services/meal_service.dart';
import '../services/health_service.dart';
import 'trends_calendar_page.dart';

enum TrendGranularity { daily, weekly, monthly }
enum TrendMetric { netLoss, intake, burned, steps, weight }

class TrendsPage extends StatefulWidget {
  const TrendsPage({super.key});

  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> with TickerProviderStateMixin {
  final _meal = MealService();
  final _health = HealthService();

  late final TabController _tab = TabController(length: 3, vsync: this);
  TrendMetric _metric = TrendMetric.netLoss;

  bool _loading = true;
  String? _error;

  // Raw daily maps keyed by yyyy-mm-dd
  Map<String, double> _intake = {};
  Map<String, double> _burned = {};
  Map<String, double> _steps = {};
  Map<String, double> _weight = {};

  // Config
  static const _dailyDays = 14; // last 14 days
  static const _weeklyWeeks = 12; // last 12 weeks
  static const _monthlyMonths = 12; // last 12 months

  @override
  void initState() {
    super.initState();
    _loadDailyRange();
    _tab.addListener(() {
      if (!_tab.indexIsChanging) return;
      if (_tab.index == 0) _loadDailyRange();
      if (_tab.index == 1) _loadWeeklyRange();
      if (_tab.index == 2) _loadMonthlyRange();
    });
  }

  Future<void> _loadDailyRange() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: _dailyDays - 1));
      final end = DateTime(now.year, now.month, now.day);

      // data (fetch in parallel)
      final intake = _meal.intakeByDay(start, end);

      final results = await Future.wait([
        _health.getCaloriesBurnedByDayFast(start, end),
        _health.getStepsByDayFast(start, end),
        _health.getWeightByDay(start, end), // already batched
      ]);

      final burned = results[0];
      final steps = results[1];
      final weight = results[2];

      if (!mounted) return;
      setState(() {
        _intake = intake;
        _burned = burned;
        _steps = steps;
        _weight = weight;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadWeeklyRange() async {
    // We leverage the same daily fetch but over a wider period,
    // then aggregate to ISO weeks (Mon-Sun).
    await _loadGenericAggregated(daysBack: _weeklyWeeks * 7);
  }

  Future<void> _loadMonthlyRange() async {
    // Same approach, aggregate to calendar months.
    await _loadGenericAggregated(daysBack: _monthlyMonths * 31);
  }

  Future<void> _loadGenericAggregated({required int daysBack}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: daysBack - 1));
      final end = DateTime(now.year, now.month, now.day);

      // Pull daily (batched & in parallel)
      final intakeDaily = _meal.intakeByDay(start, end);
      final results = await Future.wait([
        _health.getCaloriesBurnedByDayFast(start, end),
        _health.getStepsByDayFast(start, end),
        _health.getWeightByDay(start, end),
      ]);

      final burnedDaily = results[0];
      final stepsDaily = results[1];
      final weightDaily = results[2];

      if (!mounted) return;
      setState(() {
        _intake = intakeDaily;
        _burned = burnedDaily;
        _steps = stepsDaily;
        _weight = weightDaily;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---- helpers to build axes ----
  static String _yyyyMmDd(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  List<_BarPoint> _buildDailySeries() {
    final now = DateTime.now();
    final points = <_BarPoint>[];
    for (int i = _dailyDays - 1; i >= 0; i--) {
      final day =
      DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final key = _yyyyMmDd(day);
      final intake = _intake[key]; // may be null (meaning "Unavailable")
      final burned = _burned[key] ?? 0;

      double? value;
      switch (_metric) {
        case TrendMetric.netLoss:
          value = (intake == null) ? null : (burned - intake);
          break;
        case TrendMetric.intake:
          value = intake ?? 0;
          break;
        case TrendMetric.burned:
          value = burned;
          break;
        case TrendMetric.steps:
          value = _steps[key] ?? 0;
          break;
        case TrendMetric.weight:
          value = _weight[key]; // weight might be missing some days
          break;
      }

      points.add(_BarPoint(
        label: "${day.day}/${day.month}",
        value: value,
        unavailable: (_metric == TrendMetric.netLoss && intake == null),
      ));
    }
    return points;
  }

  /// Aggregate maps by week (Mon-Sun).
  List<_BarPoint> _buildWeeklySeries() {
    // Build a map weekKey -> sums/averages
    final weeks = <String, _WeekAgg>{};

    void addDay(String keyDay) {
      // dayKey -> Date
      final parts = keyDay.split('-');
      if (parts.length != 3) return;
      final d = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      // ISO-ish: week starts Monday
      final monday = d.subtract(Duration(days: (d.weekday + 6) % 7));
      final weekKey =
          "${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}";

      final w = weeks.putIfAbsent(weekKey, () => _WeekAgg());
      w.intake += (_intake[keyDay] ?? 0);
      w.burned += (_burned[keyDay] ?? 0);
      w.steps += (_steps[keyDay] ?? 0);
      if (_weight.containsKey(keyDay)) {
        w.weightSum += _weight[keyDay]!;
        w.weightCount++;
      }
      w.days.add(keyDay);
    }

    // Use the union of keys we have in burned and intake and steps and weight
    final keys = <String>{}
      ..addAll(_burned.keys)
      ..addAll(_intake.keys)
      ..addAll(_steps.keys)
      ..addAll(_weight.keys);
    for (final k in keys) {
      addDay(k);
    }

    // Order weeks (oldest → newest) and build points
    final orderedKeys = weeks.keys.toList()
      ..sort((a, b) {
        final da = DateTime.parse('${a}T00:00:00');
        final db = DateTime.parse('${b}T00:00:00');
        return da.compareTo(db);
      });

    // Keep last _weeklyWeeks
    if (orderedKeys.length > _weeklyWeeks) {
      orderedKeys.removeRange(0, orderedKeys.length - _weeklyWeeks);
    }

    final points = <_BarPoint>[];
    for (final wk in orderedKeys) {
      final a = weeks[wk]!;
      double? value;
      switch (_metric) {
        case TrendMetric.netLoss:
          value = a.burned - a.intake;
          break;
        case TrendMetric.intake:
          value = a.intake;
          break;
        case TrendMetric.burned:
          value = a.burned;
          break;
        case TrendMetric.steps:
          value = a.steps;
          break;
        case TrendMetric.weight:
          value = (a.weightCount > 0) ? (a.weightSum / a.weightCount) : null;
          break;
      }
      final d = wk.split('-');
      final label =
          "Wk ${DateTime(int.parse(d[0]), int.parse(d[1]), int.parse(d[2])).day}/${d[1]}";
      points.add(_BarPoint(label: label, value: value, unavailable: false));
    }
    return points;
  }

  /// Aggregate maps by month (calendar).
  List<_BarPoint> _buildMonthlySeries() {
    // Map monthKey -> agg
    final months = <String, _WeekAgg>{};

    void addDay(String keyDay) {
      final parts = keyDay.split('-');
      if (parts.length != 3) return;
      final mKey = "${parts[0]}-${parts[1]}"; // yyyy-mm
      final w = months.putIfAbsent(mKey, () => _WeekAgg());
      w.intake += (_intake[keyDay] ?? 0);
      w.burned += (_burned[keyDay] ?? 0);
      w.steps += (_steps[keyDay] ?? 0);
      if (_weight.containsKey(keyDay)) {
        w.weightSum += _weight[keyDay]!;
        w.weightCount++;
      }
      w.days.add(keyDay);
    }

    final keys = <String>{}
      ..addAll(_burned.keys)
      ..addAll(_intake.keys)
      ..addAll(_steps.keys)
      ..addAll(_weight.keys);
    for (final k in keys) {
      addDay(k);
    }

    final ordered = months.keys.toList()..sort(); // yyyy-mm sorts by time
    // keep last N
    if (ordered.length > _monthlyMonths) {
      ordered.removeRange(0, ordered.length - _monthlyMonths);
    }

    final points = <_BarPoint>[];
    for (final mk in ordered) {
      final a = months[mk]!;
      double? value;
      switch (_metric) {
        case TrendMetric.netLoss:
          value = a.burned - a.intake;
          break;
        case TrendMetric.intake:
          value = a.intake;
          break;
        case TrendMetric.burned:
          value = a.burned;
          break;
        case TrendMetric.steps:
          value = a.steps;
          break;
        case TrendMetric.weight:
          value = (a.weightCount > 0) ? (a.weightSum / a.weightCount) : null;
          break;
      }
      final parts = mk.split('-');
      final label = "${parts[1]}/${parts[0].substring(2)}";
      points.add(_BarPoint(label: label, value: value, unavailable: false));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final metricName = switch (_metric) {
      TrendMetric.netLoss => 'Net kcal loss',
      TrendMetric.intake => 'Kcal input',
      TrendMetric.burned => 'Kcal output',
      TrendMetric.steps => 'Steps',
      TrendMetric.weight => 'Weight (kg)',
    };

    final series = switch (_tab.index) {
      0 => _buildDailySeries(),
      1 => _buildWeeklySeries(),
      _ => _buildMonthlySeries(),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trends'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Calendar',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrendsCalendarPage()),
            ),
            icon: const Icon(Icons.calendar_month),
          ),
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                if (_tab.index == 0) _loadDailyRange();
                if (_tab.index == 1) _loadWeeklyRange();
                if (_tab.index == 2) _loadMonthlyRange();
              }),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Metric switcher
            SegmentedButton<TrendMetric>(
              segments: const [
                ButtonSegment(
                    value: TrendMetric.netLoss,
                    label: Text('Net loss')),
                ButtonSegment(
                    value: TrendMetric.intake,
                    label: Text('Input')),
                ButtonSegment(
                    value: TrendMetric.burned,
                    label: Text('Output')),
                ButtonSegment(
                    value: TrendMetric.steps, label: Text('Steps')),
                ButtonSegment(
                    value: TrendMetric.weight,
                    label: Text('Weight')),
              ],
              selected: {_metric},
              onSelectionChanged: (s) =>
                  setState(() => _metric = s.first),
            ),
            const SizedBox(height: 12.0),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(metricName,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8.0),
            Expanded(
              child: _BarChart(
                points: series,
                emphasizePositiveGreen:
                _metric == TrendMetric.netLoss,
                showUnavailableBadges:
                _tab.index == 0 && _metric == TrendMetric.netLoss,
              ),
            ),
            if (_tab.index == 0 &&
                _metric == TrendMetric.netLoss)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('“Unavailable” days: no intake logged',
                    style: TextStyle(color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekAgg {
  double intake = 0.0;
  double burned = 0.0;
  double steps = 0.0;
  double weightSum = 0.0;
  int weightCount = 0;
  final Set<String> days = {};
}

class _BarPoint {
  final String label;
  final double? value; // null => unavailable
  final bool unavailable;
  _BarPoint({required this.label, required this.value, this.unavailable = false});
}

/// Lightweight, dependency-free bar chart with null-aware bars.
class _BarChart extends StatelessWidget {
  final List<_BarPoint> points;
  final bool emphasizePositiveGreen;
  final bool showUnavailableBadges;

  const _BarChart({
    required this.points,
    this.emphasizePositiveGreen = false,
    this.showUnavailableBadges = false,
  });

  @override
  Widget build(BuildContext context) {
    final values = points.map((e) => e.value).whereType<double>().toList();
    final double maxV =
    values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    return LayoutBuilder(
      builder: (context, c) {
        // ensure double types everywhere
        final double computed = c.maxWidth / (points.length * 1.6);
        final double barWidth = computed < 10.0 ? 10.0 : computed;

        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points.map((p) {
                  final double? v = p.value;

                  final double height = (v == null)
                      ? 0.0
                      : (maxV == 0.0
                      ? 0.0
                      : (v / maxV) * (c.maxHeight - 40.0)); // labels space

                  Color barColor = Theme.of(context).colorScheme.primary;
                  if (emphasizePositiveGreen && v != null) {
                    barColor = v >= 0 ? Colors.green : Colors.red;
                  }

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (showUnavailableBadges && p.unavailable)
                          const Text('—', style: TextStyle(color: Colors.grey)),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: height,
                          width: barWidth,
                          decoration: BoxDecoration(
                            color: v == null
                                ? Colors.black12
                                : barColor.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          p.label,
                          style: const TextStyle(fontSize: 12.0),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
