import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive/hive.dart';
import 'package:fitness_app/models/workout_plan.dart';
import 'package:fitness_app/services/workout_service.dart';

class PlanChartsPage extends StatefulWidget {
  final String planId;
  const PlanChartsPage({super.key, required this.planId});

  @override
  State<PlanChartsPage> createState() => _PlanChartsPageState();
}

class _PlanChartsPageState extends State<PlanChartsPage> {
  final service = WorkoutService();
  late WorkoutPlan plan;

  @override
  void initState() {
    super.initState();
    plan = Hive.box<WorkoutPlan>('plans').get(widget.planId)!;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final logs = service.getLogsForPlan(plan.id).reversed.toList(); // oldest -> newest
    final spotsWeight = <FlSpot>[];
    final spotsReps = <FlSpot>[];
    final spotsKcal = <FlSpot>[];

    for (var i = 0; i < logs.length; i++) {
      final l = logs[i];
      spotsWeight.add(FlSpot(i.toDouble(), l.expectedWeightKg));
      spotsReps.add(FlSpot(i.toDouble(), l.achievedReps.toDouble()));
      spotsKcal.add(FlSpot(i.toDouble(), l.energyKcal));
    }

    Widget buildChart(String title, List<FlSpot> spots) {
      if (spots.isEmpty) return const Text('No data yet.');
      return SizedBox(
        height: 260,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: scheme.outlineVariant.withValues(alpha: 0.3),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) => Text(
                              v.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          barWidth: 3,
                          color: scheme.primary,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: scheme.primary.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('${plan.name} • Charts')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          buildChart('Weight (kg) — Expected', spotsWeight),
          buildChart('Reps — Achieved', spotsReps),
          buildChart('Energy (kcal) — Estimated', spotsKcal),
          const SizedBox(height: 8),
          if (logs.isNotEmpty)
            Text('Sessions: ${logs.length}', textAlign: TextAlign.center),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
