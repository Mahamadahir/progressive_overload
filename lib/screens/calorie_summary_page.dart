import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../services/meal_service.dart';
import '../services/health_service.dart';
import '../services/notification_service.dart'; // ← uses your existing service

class CalorieSummaryPage extends StatefulWidget {
  const CalorieSummaryPage({super.key});

  @override
  State<CalorieSummaryPage> createState() => _CalorieSummaryPageState();
}

class _CalorieSummaryPageState extends State<CalorieSummaryPage>
    with SingleTickerProviderStateMixin {
  final _mealService = MealService();
  final _healthService = HealthService();

  bool _loading = true;
  String? _error;
  double _intake = 0;
  double _burned = 0;
  double _weeklyIntake = 0;
  double _weeklyBurned = 0;

  // Target + settings
  final _targetCtrl = TextEditingController(text: '500');
  late final Box _settings;

  // tiny celebration effect
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);
  late final Animation<double> _scale = Tween(
    begin: 0.98,
    end: 1.02,
  ).animate(_pulse);

  static const _kTargetKey = 'target_net_loss_kcal';
  static const _kLastNotifyKey = 'notified_shortfall_yyyymmdd';

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    // settings box should already be open in bootstrap()
    _settings = Hive.box('settings');
    final savedTarget = (_settings.get(_kTargetKey) as num?)?.toDouble();
    if (savedTarget != null) {
      _targetCtrl.text = savedTarget.toStringAsFixed(0);
    }
    // reactively persist on edit
    _targetCtrl.addListener(() {
      final v = double.tryParse(_targetCtrl.text.trim());
      if (v != null && v >= 0) {
        _settings.put(_kTargetKey, v);
      }
      setState(() {}); // re-render progress card as user types
    });

    await _refresh();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = today.subtract(const Duration(days: 6));

      final intake = _mealService.todayIntakeKcal(now: now);
      final weeklyIntakeMap = _mealService.intakeByDay(start, today);
      final burnedMap = await _healthService.getCaloriesBurnedByDay(
        start,
        today,
      );

      double weeklyIntake = 0;
      double weeklyBurned = 0;
      for (int i = 0; i < 7; i++) {
        final day = start.add(Duration(days: i));
        final key = _formatDayKey(day);
        weeklyIntake += weeklyIntakeMap[key] ?? 0;
        weeklyBurned += burnedMap[key] ?? 0;
      }

      final todayKey = _formatDayKey(today);
      final todayBurned = burnedMap[todayKey] ?? 0;

      if (!mounted) return;
      setState(() {
        _intake = intake;
        _burned = todayBurned;
        _weeklyIntake = weeklyIntake;
        _weeklyBurned = weeklyBurned;
      });
      _maybeNotifyShortfall();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDayKey(DateTime day) {
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  void _maybeNotifyShortfall() {
    final netLoss = _burned - _intake;
    final target = double.tryParse(_targetCtrl.text.trim()) ?? 0;
    if (target <= 0) return;

    if (netLoss >= target) return; // goal met — no nag

    // Notify once per day
    final now = DateTime.now();
    final yyyymmdd =
        "${now.year.toString().padLeft(4, '0')}"
        "${now.month.toString().padLeft(2, '0')}"
        "${now.day.toString().padLeft(2, '0')}";
    final last = _settings.get(_kLastNotifyKey) as String?;
    if (last == yyyymmdd) return;

    final remaining = (target - netLoss).clamp(0, double.infinity);
    try {
      // Adjust to your NotificationService API if different:
      // e.g. NotificationService.showNow(title: ..., body: ...)
      NotificationService.showNow(
        title: 'Not there yet',
        body:
            'You are ${remaining.toStringAsFixed(0)} kcal short of today\'s goal. Time to move!',
      );
    } catch (_) {
      // If your service uses a different name, try one of these and remove the others:
      // NotificationService.show('Not there yet', 'You are ${remaining.toStringAsFixed(0)} kcal short…');
      // NotificationService.notify('Not there yet', 'You are …');
    }
    _settings.put(_kLastNotifyKey, yyyymmdd);
  }

  @override
  Widget build(BuildContext context) {
    final netLoss = _burned - _intake; // 🔁 burned − intake
    final target = double.tryParse(_targetCtrl.text.trim()) ?? 0;
    final remaining = (target - netLoss).clamp(0, double.infinity);
    final goalMet = target > 0 && netLoss >= target;

    final progress = target > 0
        ? (netLoss / target).clamp(0, 1).toDouble()
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calorie Summary'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _StatCard(
                    title: 'Intake (kcal)',
                    value: _intake.toStringAsFixed(0),
                  ),
                  const SizedBox(height: 12),
                  _StatCard(
                    title: 'Burned (kcal)',
                    value: _burned.toStringAsFixed(0),
                  ),
                  const SizedBox(height: 12),

                  // ▶ Net loss card (burned - intake) with goal UI
                  ScaleTransition(
                    scale: goalMet ? _scale : const AlwaysStoppedAnimation(1.0),
                    child: Card(
                      color: goalMet
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Net loss (kcal)',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const Spacer(),
                                Text(
                                  netLoss.toStringAsFixed(0),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _targetCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Target net loss (kcal)',
                                prefixIcon: Icon(Icons.flag),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 10,
                                backgroundColor: Colors.black12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (goalMet)
                              Text(
                                '🎉 Congratulations! You met today\'s goal.',
                                style: TextStyle(
                                  color: Colors.green.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else if (target > 0)
                              Text(
                                'You need ${remaining.toStringAsFixed(0)} more kcal to reach today\'s goal.',
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  _WeeklySummaryCard(
                    intake: _weeklyIntake,
                    burned: _weeklyBurned,
                  ),

                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Today\'s meal logs',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        itemCount: _mealService.todayLogs().length,
                        itemBuilder: (_, i) {
                          final log = _mealService.todayLogs()[i];
                          return ListTile(
                            leading: const Icon(Icons.restaurant),
                            title: Text(log.name),
                            subtitle: Text(
                              '${log.massGrams.toStringAsFixed(0)} g • ${log.kcal.toStringAsFixed(0)} kcal',
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  final double intake;
  final double burned;
  static const int _days = 7;
  const _WeeklySummaryCard({required this.intake, required this.burned});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = burned - intake;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly summary (last $_days days)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(label: 'Intake', value: intake),
                ),
                Expanded(
                  child: _SummaryValue(label: 'Burned', value: burned),
                ),
                Expanded(
                  child: _SummaryValue(label: 'Net', value: net),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    label: 'Avg intake',
                    value: intake / _days,
                    secondary: true,
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    label: 'Avg burned',
                    value: burned / _days,
                    secondary: true,
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    label: 'Avg net',
                    value: net / _days,
                    secondary: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final double value;
  final bool secondary;
  const _SummaryValue({
    required this.label,
    required this.value,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = secondary
        ? theme.textTheme.titleMedium?.copyWith(fontSize: 18)
        : theme.textTheme.titleLarge;
    final labelStyle = secondary
        ? theme.textTheme.bodySmall
        : theme.textTheme.labelLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 4),
        Text(value.toStringAsFixed(0), style: valueStyle),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
