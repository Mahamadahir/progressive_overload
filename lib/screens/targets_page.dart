import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/notification_service.dart';

class TargetsPage extends StatefulWidget {
  const TargetsPage({super.key});

  @override
  State<TargetsPage> createState() => _TargetsPageState();
}

class _TargetsPageState extends State<TargetsPage> {
  late Box settings;

  // Targets
  double targetNetLossKcal = 500;
  int stepsGoal = 8000; // NEW: steps goal

  // Reminders
  bool weighInEnabled = false;
  TimeOfDay weighInTime = const TimeOfDay(hour: 7, minute: 0);

  bool workoutEnabled = false;
  TimeOfDay workoutTime = const TimeOfDay(hour: 18, minute: 0);

  // Defaults
  double defaultMets = 3.0;
  int defaultMin = 6;
  int defaultMax = 12;
  double defaultIncKg = 2.0;

  @override
  void initState() {
    super.initState();
    settings = Hive.box('settings');
    _load();
  }

  void _load() {
    // Targets
    targetNetLossKcal =
        (settings.get('target_net_loss_kcal', defaultValue: 500) as num)
            .toDouble();
    stepsGoal = settings.get('steps_goal', defaultValue: 8000) as int; // NEW

    // Reminders
    weighInEnabled = settings.get('weighInEnabled', defaultValue: false);
    final wtH = settings.get('weighInHour', defaultValue: 7);
    final wtM = settings.get('weighInMinute', defaultValue: 0);
    weighInTime = TimeOfDay(hour: wtH, minute: wtM);

    workoutEnabled = settings.get('workoutEnabled', defaultValue: false);
    final woH = settings.get('workoutHour', defaultValue: 18);
    final woM = settings.get('workoutMinute', defaultValue: 0);
    workoutTime = TimeOfDay(hour: woH, minute: woM);

    // Defaults
    defaultMets = (settings.get('defaultMets', defaultValue: 3.0) as num).toDouble();
    defaultMin = settings.get('defaultMinReps', defaultValue: 6);
    defaultMax = settings.get('defaultMaxReps', defaultValue: 12);
    defaultIncKg = (settings.get('defaultIncKg', defaultValue: 2.0) as num).toDouble();

    setState(() {});
  }

  Future<void> _pickTime(bool isWeighIn) async {
    final current = isWeighIn ? weighInTime : workoutTime;
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    setState(() {
      if (isWeighIn) {
        weighInTime = picked;
      } else {
        workoutTime = picked;
      }
    });
  }

  Future<void> _save() async {
    // Targets
    await settings.put('target_net_loss_kcal', targetNetLossKcal);
    await settings.put('steps_goal', stepsGoal); // NEW

    // Reminders
    await settings.put('weighInEnabled', weighInEnabled);
    await settings.put('weighInHour', weighInTime.hour);
    await settings.put('weighInMinute', weighInTime.minute);

    await settings.put('workoutEnabled', workoutEnabled);
    await settings.put('workoutHour', workoutTime.hour);
    await settings.put('workoutMinute', workoutTime.minute);

    // Defaults
    await settings.put('defaultMets', defaultMets);
    await settings.put('defaultMinReps', defaultMin);
    await settings.put('defaultMaxReps', defaultMax);
    await settings.put('defaultIncKg', defaultIncKg);

    // Notifications
    if (weighInEnabled) {
      await NotificationService.scheduleDaily(
        id: 1001,
        title: 'Morning weigh-in',
        body: 'Log your weight (pre-food, post-toilet).',
        time: weighInTime,
      );
    } else {
      await NotificationService.cancel(1001);
    }
    if (workoutEnabled) {
      await NotificationService.scheduleDaily(
        id: 1002,
        title: 'Workout reminder',
        body: 'Time to train. Check your next target.',
        time: workoutTime,
      );
    } else {
      await NotificationService.cancel(1002);
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Targets saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepsQuick = [5000, 8000, 10000, 12000];

    return Scaffold(
      appBar: AppBar(title: const Text('Targets')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== Targets =====
          const Text('Daily Net Loss', style: TextStyle(fontWeight: FontWeight.bold)),
          TextFormField(
            initialValue: targetNetLossKcal.toStringAsFixed(0),
            decoration: const InputDecoration(
              labelText: 'Target net loss (kcal / day)',
              prefixIcon: Icon(Icons.flag),
              helperText: 'Used in Summary as Burned − Intake each day.',
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null && parsed >= 0) {
                setState(() => targetNetLossKcal = parsed);
              }
            },
          ),
          const SizedBox(height: 16),

          // ===== Steps Goal (NEW) =====
          const Text('Daily Steps Goal', style: TextStyle(fontWeight: FontWeight.bold)),
          TextFormField(
            initialValue: stepsGoal.toString(),
            decoration: const InputDecoration(
              labelText: 'Steps per day',
              prefixIcon: Icon(Icons.directions_walk),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final parsed = int.tryParse(v.trim());
              if (parsed != null && parsed >= 0) {
                setState(() => stepsGoal = parsed);
              }
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: stepsQuick.map((n) {
              return ChoiceChip(
                label: Text('${n ~/ 1000}k'),
                selected: stepsGoal == n,
                onSelected: (_) => setState(() => stepsGoal = n),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // ===== Reminders =====
          const Text('Reminders', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text('Morning weigh-in'),
            value: weighInEnabled,
            onChanged: (v) => setState(() => weighInEnabled = v),
            subtitle: Text('Time: ${weighInTime.format(context)}'),
            secondary: IconButton(
              icon: const Icon(Icons.access_time),
              onPressed: () => _pickTime(true),
            ),
          ),
          SwitchListTile(
            title: const Text('Workout reminder'),
            value: workoutEnabled,
            onChanged: (v) => setState(() => workoutEnabled = v),
            subtitle: Text('Time: ${workoutTime.format(context)}'),
            secondary: IconButton(
              icon: const Icon(Icons.access_time),
              onPressed: () => _pickTime(false),
            ),
          ),
          const SizedBox(height: 16),

          // ===== Defaults =====
          const Text('Defaults', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: defaultMin.toString(),
                  decoration: const InputDecoration(labelText: 'Min reps'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => defaultMin = int.tryParse(v) ?? defaultMin,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: defaultMax.toString(),
                  decoration: const InputDecoration(labelText: 'Max reps'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => defaultMax = int.tryParse(v) ?? defaultMax,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: defaultIncKg.toStringAsFixed(1),
            decoration: const InputDecoration(labelText: 'Increment (kg)'),
            keyboardType: TextInputType.number,
            onChanged: (v) => defaultIncKg = double.tryParse(v) ?? defaultIncKg,
          ),
          const SizedBox(height: 8),
          const Text('Default METs'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [2.5, 3.0, 5.0].map((m) {
              final selected = defaultMets == m;
              return ChoiceChip(
                label: Text(m == 2.5 ? 'Light (2.5)' : m == 3.0 ? 'Moderate (3.0)' : 'Vigorous (5.0)'),
                selected: selected,
                onSelected: (_) => setState(() => defaultMets = m),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
