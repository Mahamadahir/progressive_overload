import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:fitness_app/models/workout_plan.dart';
import 'package:fitness_app/services/workout_service.dart';
import 'session_page.dart';
import 'plan_charts_page.dart';

class PlanDetailPage extends StatefulWidget {
  final String planId;
  const PlanDetailPage({super.key, required this.planId});

  @override
  State<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends State<PlanDetailPage> {
  final service = WorkoutService();
  late WorkoutPlan plan;

  @override
  void initState() {
    super.initState();
    plan = Hive.box<WorkoutPlan>('plans').get(widget.planId)!;
  }

  Future<void> _openEditPlanSheet() async {
    final nameCtrl = TextEditingController(text: plan.name);
    final weightCtrl = TextEditingController(text: plan.currentWeightKg.toStringAsFixed(1));
    final minRepsCtrl = TextEditingController(text: plan.minReps.toString());
    final maxRepsCtrl = TextEditingController(text: plan.maxReps.toString());
    final incCtrl = TextEditingController(text: plan.incrementKg.toStringAsFixed(1));
    double metsLocal = plan.mets;

    final formKey = GlobalKey<FormState>();
    final metOptions = [2.5, 3.0, 5.0];
    final metLabels = {2.5: 'Light', 3.0: 'Moderate', 5.0: 'Vigorous'};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Form(
                key: formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const SizedBox(height: 8),
                    const Text('Edit Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Exercise name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: weightCtrl,
                      decoration: const InputDecoration(labelText: 'Current weight (kg)'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final d = double.tryParse(v ?? '');
                        if (d == null || d <= 0) return 'Enter a positive number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: minRepsCtrl,
                            decoration: const InputDecoration(labelText: 'Min reps'),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final x = int.tryParse(v ?? '');
                              if (x == null || x <= 0) return 'Enter a positive int';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: maxRepsCtrl,
                            decoration: const InputDecoration(labelText: 'Max reps'),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final x = int.tryParse(v ?? '');
                              if (x == null || x <= 0) return 'Enter a positive int';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: incCtrl,
                      decoration: const InputDecoration(labelText: 'Increment (kg)'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final d = double.tryParse(v ?? '');
                        if (d == null || d <= 0) return 'Enter a positive number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('Default intensity (METs)'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: metOptions.map((m) {
                        final selected = metsLocal == m;
                        return ChoiceChip(
                          label: Text('${metLabels[m]} (${m.toStringAsFixed(1)})'),
                          selected: selected,
                          onSelected: (_) => setSheetState(() => metsLocal = m),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        final newName = nameCtrl.text.trim();
                        final newWeight = double.parse(weightCtrl.text);
                        final newMin = int.parse(minRepsCtrl.text);
                        final newMax = int.parse(maxRepsCtrl.text);
                        final newInc = double.parse(incCtrl.text);

                        if (newMin > newMax) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Min reps cannot be greater than max reps')),
                          );
                          return;
                        }

                        // Apply updates
                        plan.name = newName;
                        plan.currentWeightKg = newWeight;
                        final prevMin = plan.minReps;
                        final prevMax = plan.maxReps;
                        plan.minReps = newMin;
                        plan.maxReps = newMax;
                        plan.incrementKg = newInc;
                        plan.mets = metsLocal;

                        // Keep expectedReps within [min..max]
                        if (plan.expectedReps < plan.minReps || plan.expectedReps > plan.maxReps) {
                          // If the bounds changed, clamp expected reps to the new range
                          plan.expectedReps = plan.expectedReps.clamp(plan.minReps, plan.maxReps);
                          // If previous range was invalid and we had no sensible value, default to min
                          if (plan.expectedReps < plan.minReps || plan.expectedReps > plan.maxReps) {
                            plan.expectedReps = plan.minReps;
                          }
                        }

                        await plan.save();
                        if (!mounted) return;
                        setState(() {
                          plan = Hive.box<WorkoutPlan>('plans').get(widget.planId)!;
                        });
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = service.getLogsForPlan(plan.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(plan.name),
        actions: [
          IconButton(
            tooltip: 'Edit plan',
            onPressed: _openEditPlanSheet,
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            tooltip: 'Delete plan',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete Plan?'),
                  content: const Text('This removes the plan (logs remain). Continue?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (ok == true) {
                await service.deletePlan(plan.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.delete),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => SessionPage(planId: plan.id)));
          if (!mounted) return;
          setState(() {
            plan = Hive.box<WorkoutPlan>('plans').get(widget.planId)!;
          });
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Log session'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Next up'),
              subtitle: Text(
                "${plan.currentWeightKg.toStringAsFixed(1)} kg × ${plan.expectedReps} reps"
                    "  •  ${plan.mets.toStringAsFixed(1)} METs",
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PlanChartsPage(planId: plan.id)),
                    );
                  },
                  icon: const Icon(Icons.show_chart),
                  label: const Text('Charts'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SessionPage(planId: plan.id)),
                    );
                    if (!mounted) return;
                    setState(() {
                      plan = Hive.box<WorkoutPlan>('plans').get(widget.planId)!;
                    });
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Log now'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Recent sessions', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (logs.isEmpty)
            const Text('No sessions yet.')
          else
            ...logs.take(10).map((l) => Card(
              child: ListTile(
                title: Text(
                    "${l.date.toLocal()} • ${l.expectedWeightKg.toStringAsFixed(1)}kg × ${l.expectedReps} (exp)"),
                subtitle: Text(
                    "Sets ${l.sets}, Reps ${l.achievedReps}, Target ${l.targetMet ? "met" : "missed"}, "
                        "Energy ${l.energyKcal.toStringAsFixed(0)} kcal, ${l.metsUsed.toStringAsFixed(1)} METs"),
              ),
            )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
