import 'package:flutter/material.dart';
import 'package:health/health.dart';        // enums & types
import 'package:fitness_app/health_singleton.dart';       // shared instance
import 'package:fitness_app/services/health_service.dart';

class WorkoutSessionPage extends StatefulWidget {
  const WorkoutSessionPage({super.key});

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  final _formKey = GlobalKey<FormState>();
  final _exerciseController = TextEditingController();
  final _weightController = TextEditingController();
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();

  bool _saving = false;
  String? _result;

  @override
  void dispose() {
    _exerciseController.dispose();
    _weightController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  Future<void> _saveWorkout() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _saving = true; _result = null; });

    final name = _exerciseController.text.trim();
    final weightInput = double.tryParse(_weightController.text) ?? 0;
    final sets = int.tryParse(_setsController.text) ?? 0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    final durationSec = sets * reps * 5;

    try {
      // 0) Ensure write scopes for workout + total calories (centralized & serialized)
      final okWrite = await HealthService.ensureWorkoutWritePermissions();
      if (!okWrite) throw Exception("Health permissions not granted (workout/total calories)");

      // 1) Get latest bodyweight (READ Weight handled inside)
      final latestWeight = await HealthService.getLatestWeight();
      if (latestWeight == null) throw Exception("No weight data found");

      // 2) Calculate MET-based energy expenditure
      const MET = 3.0;
      final durationHrs = durationSec / 3600.0;
      final energyKcalDouble = durationHrs * latestWeight * MET;

      // 3) Save workout session
      final now = DateTime.now();
      final start = now.subtract(Duration(seconds: durationSec));

      final success = await health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.STRENGTH_TRAINING,
        start: start,
        end: now,
        totalEnergyBurned: energyKcalDouble.round(),
        title: "Workout: $name",
      );

      if (!success) throw Exception("Failed to save workout to Health");

      setState(() {
        _result =
        "Workout logged successfully!\n"
            "Exercise: $name\n"
            "Weight: ${weightInput.toStringAsFixed(1)} kg\n"
            "Sets×Reps: $sets×$reps\n"
            "Estimated energy: ${energyKcalDouble.toStringAsFixed(1)} kcal";
        _saving = false;
      });
    } catch (e) {
      setState(() { _result = "Error: $e"; _saving = false; });
    }
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? "Required" : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Log Workout")),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _exerciseController,
                decoration: const InputDecoration(labelText: "Exercise Name"),
                validator: _req,
              ),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(labelText: "Weight (kg)"),
                keyboardType: TextInputType.number,
                validator: _req,
              ),
              TextFormField(
                controller: _setsController,
                decoration: const InputDecoration(labelText: "Sets"),
                keyboardType: TextInputType.number,
                validator: _req,
              ),
              TextFormField(
                controller: _repsController,
                decoration: const InputDecoration(labelText: "Reps per Set"),
                keyboardType: TextInputType.number,
                validator: _req,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveWorkout,
                child: const Text("Save Workout to Health"),
              ),
              if (_result != null) ...[
                const SizedBox(height: 20),
                Text(_result!, style: const TextStyle(fontSize: 16)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
