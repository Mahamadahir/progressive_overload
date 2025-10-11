import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:fitness_app/services/workout_service.dart';

class CreatePlanPage extends StatefulWidget {
  const CreatePlanPage({super.key});

  @override
  State<CreatePlanPage> createState() => _CreatePlanPageState();
}

class _CreatePlanPageState extends State<CreatePlanPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _startWeight = TextEditingController();
  final service = WorkoutService();

  late final Box _settings;
  late int _defaultMinReps;
  late int _defaultMaxReps;
  late double _defaultIncrementKg;
  late double _defaultMets;

  @override
  void initState() {
    super.initState();
    _settings = Hive.box('settings');
    _loadDefaults();
  }

  void _loadDefaults() {
    _defaultMinReps =
        _settings.get('defaultMinReps', defaultValue: 6) as int;
    _defaultMaxReps =
        _settings.get('defaultMaxReps', defaultValue: 12) as int;
    _defaultIncrementKg =
        (_settings.get('defaultIncKg', defaultValue: 2.0) as num).toDouble();
    _defaultMets =
        (_settings.get('defaultMets', defaultValue: 3.0) as num).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Plan')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Exercise name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _startWeight,
                decoration: const InputDecoration(labelText: 'Starting weight (kg)'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  await service.createPlan(
                    name: _name.text.trim(),
                    startWeightKg: double.parse(_startWeight.text),
                    minReps: _defaultMinReps,
                    maxReps: _defaultMaxReps,
                    incrementKg: _defaultIncrementKg,
<<<<<<< HEAD
                    defaultMets: _defaultMets,
=======
                    mets: _defaultMets,
>>>>>>> origin/main
                  );
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
