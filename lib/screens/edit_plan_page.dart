import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../models/workout_plan.dart';

class EditPlanPage extends StatefulWidget {
  final String planId;
  const EditPlanPage({super.key, required this.planId});

  @override
  State<EditPlanPage> createState() => _EditPlanPageState();
}

class _EditPlanPageState extends State<EditPlanPage> {
  late WorkoutPlan plan;
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _minRepsCtrl = TextEditingController();
  final _maxRepsCtrl = TextEditingController();
  final _incCtrl = TextEditingController();
  double _mets = 3.0;

  @override
  void initState() {
    super.initState();
    plan = Hive.box<WorkoutPlan>('plans').get(widget.planId)!;
    _nameCtrl.text = plan.name;
    _weightCtrl.text = plan.currentWeightKg.toStringAsFixed(1);
    _minRepsCtrl.text = plan.minReps.toString();
    _maxRepsCtrl.text = plan.maxReps.toString();
    _incCtrl.text = plan.incrementKg.toStringAsFixed(1);
    _mets = plan.mets;
  }

  @override
  Widget build(BuildContext context) {
    final metOptions = [2.5, 3.0, 5.0];
    final metLabels = {2.5: 'Light', 3.0: 'Moderate', 5.0: 'Vigorous'};

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Plan')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Exercise name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _weightCtrl,
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
                      controller: _minRepsCtrl,
                      decoration: const InputDecoration(labelText: 'Min reps'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final x = int.tryParse(v ?? '');
                        if (x == null || x <= 0) return 'Enter positive int';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxRepsCtrl,
                      decoration: const InputDecoration(labelText: 'Max reps'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final x = int.tryParse(v ?? '');
                        if (x == null || x <= 0) return 'Enter positive int';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _incCtrl,
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
                  final selected = _mets == m;
                  return ChoiceChip(
                    label: Text('${metLabels[m]} (${m.toStringAsFixed(1)})'),
                    selected: selected,
                    onSelected: (_) => setState(() => _mets = m),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;

                  final newName = _nameCtrl.text.trim();
                  final newWeight = double.parse(_weightCtrl.text);
                  final newMin = int.parse(_minRepsCtrl.text);
                  final newMax = int.parse(_maxRepsCtrl.text);
                  final newInc = double.parse(_incCtrl.text);

                  if (newMin > newMax) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Min reps cannot be greater than max reps')),
                    );
                    return;
                  }

                  plan
                    ..name = newName
                    ..currentWeightKg = newWeight
                    ..minReps = newMin
                    ..maxReps = newMax
                    ..incrementKg = newInc
                    ..mets = _mets;

                  // Clamp expected reps into range
                  plan.expectedReps =
                      plan.expectedReps.clamp(plan.minReps, plan.maxReps);

                  await plan.save();
                  if (!mounted) return;
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
