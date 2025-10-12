import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:fitness_app/database/app_database.dart';
import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/repositories/drift_repository.dart';
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
  List<MuscleGroup> _flatGroups = const <MuscleGroup>[];

  @override
  void initState() {
    super.initState();
    settings = Hive.box('settings');
    _load();
  }

  List<MuscleGroup> _flattenNodes(List<MuscleGroupNode> nodes) {
    final result = <MuscleGroup>[];
    void visit(List<MuscleGroupNode> items) {
      for (final node in items) {
        result.add(node.group);
        if (node.children.isNotEmpty) {
          visit(node.children);
        }
      }
    }

    visit(nodes);
    return result;
  }

  List<Widget> _buildGroupTiles(
    List<MuscleGroupNode> nodes, {
    int depth = 0,
  }) {
    final indent = depth * 12.0;
    final tiles = <Widget>[];
    for (final node in nodes) {
      tiles.add(
        Card(
          margin: EdgeInsets.only(left: indent, bottom: 6),
          child: ListTile(
            title: Text(node.group.name),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'add':
                    await _showGroupDialog(parentId: node.group.id);
                    break;
                  case 'edit':
                    await _showGroupDialog(group: node.group);
                    break;
                  case 'delete':
                    await _deleteGroup(node.group);
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'add', child: Text('Add child group')),
                PopupMenuItem(value: 'edit', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        ),
      );

      if (node.children.isNotEmpty) {
        tiles.addAll(_buildGroupTiles(node.children, depth: depth + 1));
      }
    }
    return tiles;
  }

  Future<void> _showGroupDialog({MuscleGroup? group, String? parentId}) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController(text: group?.name ?? '');
    String? selectedParentId = parentId ?? group?.parentId;
    final isEdit = group != null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Muscle Group' : 'Add Muscle Group'),
          content: StatefulBuilder(
            builder: (context, setState) {
              final parentOptions =
                  _flatGroups.where((g) => g.id != group?.id).toList()
                    ..sort((a, b) => a.name.compareTo(b.name));

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedParentId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Parent (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...parentOptions.map(
                        (g) => DropdownMenuItem<String?>(
                          value: g.id,
                          child: Text(g.name),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => selectedParentId = value),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Name is required.')),
                  );
                  return;
                }
                try {
                  final editingGroup = group;
                  if (editingGroup != null) {
                    await driftRepository.updateMuscleGroup(
                      id: editingGroup.id,
                      name: name,
                      parentId: selectedParentId,
                    );
                  } else {
                    await driftRepository.createMuscleGroup(
                      name,
                      parentId: selectedParentId,
                    );
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } on RepositoryException catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(e.message)));
                }
              },
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteGroup(MuscleGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete muscle group?'),
        content: Text('Delete "${group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await driftRepository.deleteMuscleGroup(group.id);
    } on RepositoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
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
    defaultMets = (settings.get('defaultMets', defaultValue: 3.0) as num)
        .toDouble();
    defaultMin = settings.get('defaultMinReps', defaultValue: 6);
    defaultMax = settings.get('defaultMaxReps', defaultValue: 12);
    defaultIncKg = (settings.get('defaultIncKg', defaultValue: 2.0) as num)
        .toDouble();

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Targets saved')));
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
          const Text(
            'Muscle Groups',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          StreamBuilder<List<MuscleGroupNode>>(
            stream: driftRepository.watchMuscleGroupsTree(),
            builder: (context, snapshot) {
              final nodes = snapshot.data ?? const [];
              _flatGroups = _flattenNodes(nodes);

              if (nodes.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text('No muscle groups yet.'),
                    TextButton.icon(
                      onPressed: () => _showGroupDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add muscle group'),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  const SizedBox(height: 8),
                  ..._buildGroupTiles(nodes),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _showGroupDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add top-level group'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // ===== Targets =====
          const Text(
            'Daily Net Loss',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
          const Text(
            'Daily Steps Goal',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
          const Text(
            'Reminders',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
                label: Text(
                  m == 2.5
                      ? 'Light (2.5)'
                      : m == 3.0
                      ? 'Moderate (3.0)'
                      : 'Vigorous (5.0)',
                ),
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

