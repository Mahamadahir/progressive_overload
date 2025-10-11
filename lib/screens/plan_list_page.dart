import 'package:flutter/material.dart';
import 'package:fitness_app/services/workout_service.dart';
import 'create_plan_page.dart';
import 'session_page.dart';
import 'plan_detail_page.dart';
import 'edit_plan_page.dart'; // <-- NEW

class PlanListPage extends StatefulWidget {
  const PlanListPage({super.key});

  @override
  State<PlanListPage> createState() => _PlanListPageState();
}

class _PlanListPageState extends State<PlanListPage> {
  final service = WorkoutService();

  @override
  Widget build(BuildContext context) {
    final plans = service.getPlans();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Plans'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePlanPage()));
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
      body: plans.isEmpty
          ? const Center(child: Text('No plans yet. Tap + to create one.'))
          : ListView.builder(
        itemCount: plans.length,
        itemBuilder: (_, i) {
          final p = plans[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: ListTile(
              title: Text(p.name),
              subtitle: Text(
                "Next: ${p.currentWeightKg.toStringAsFixed(1)} kg × ${p.expectedReps} reps  •  "
                    "Intensity: ${p.mets.toStringAsFixed(1)} METs",
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EditPlanPage(planId: p.id)),
                        );
                        setState(() {});
                      } else if (value == 'delete') {
                        await service.deletePlan(p.id);
                        setState(() {});
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    icon: const Icon(Icons.more_vert),
                  ),
                  IconButton(
                    tooltip: 'Log session',
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SessionPage(planId: p.id)),
                      );
                      setState(() {});
                    },
                  ),
                ],
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PlanDetailPage(planId: p.id)),
                );
                setState(() {});
              },
            ),
          );
        },
      ),
    );
  }
}
