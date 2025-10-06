// lib/screens/session_page.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:health/health.dart';
import '../../models/workout_plan.dart';
import '../../services/workout_service.dart';
import '../../services/health_service.dart';
import '../../health_singleton.dart'; // still used by other services
import 'health_connect_diagnostics_page.dart'; // centralized permission helpers

class SessionPage extends StatefulWidget {
  final String planId;
  const SessionPage({super.key, required this.planId});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  final service = WorkoutService();
  late WorkoutPlan plan;

  final _setsCtrl = TextEditingController(text: '3');
  final _achievedRepsCtrl = TextEditingController();
  bool _targetMet = false;
  bool _saving = false;
  String? _result;

  // permission banner / checks
  bool _checkingPerms = true;
  bool _authorized = true;
  bool _authBusy = false; // local UX lock (global guard may be in HealthService)

  // per-session MET override
  double? _overrideMets;
  final List<double?> _metOptions = [null, 2.5, 3.0, 5.0];
  final Map<double, String> _labels = {
    2.5: 'Light',
    3.0: 'Moderate',
    5.0: 'Vigorous',
  };

  // What this screen really needs (kept for readability / documentation)
  static const _typesWorkoutWrite = <HealthDataType>[
    HealthDataType.WORKOUT,
    HealthDataType.TOTAL_CALORIES_BURNED,
  ];
  static const _permsWorkoutWrite = <HealthDataAccess>[
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
  ];
  static const _typesActiveRead = <HealthDataType>[
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];
  static const _permsActiveRead = <HealthDataAccess>[
    HealthDataAccess.READ,
  ];
  static const _typesWeightRead = <HealthDataType>[
    HealthDataType.WEIGHT,
  ];
  static const _permsWeightRead = <HealthDataAccess>[
    HealthDataAccess.READ,
  ];

  @override
  void initState() {
    super.initState();
    plan = Hive.box<WorkoutPlan>('plans').get(widget.planId)!;
    _checkPermissions(); // passive check (no prompts)
  }

  /// Passive check: Delegated to HealthConnectDiagnostics helper (no UI prompts).
  Future<void> _checkPermissions() async {
    setState(() {
      _checkingPerms = true;
      _authorized = false;
    });

    try {
      final ok = await HealthConnectDiagnosticsHelper.checkPermissionsPassive();
      setState(() {
        _authorized = ok;
      });
    } catch (_) {
      setState(() => _authorized = false);
    } finally {
      setState(() => _checkingPerms = false);
    }
  }

  /// Active fix: Request permissions via centralized diagnostics helper to avoid races.
  Future<void> _fixPermissions() async {
    if (_authBusy) return;
    setState(() => _authBusy = true);
    try {
      final ok = await HealthConnectDiagnosticsHelper.requestPermissionsSerial();
      setState(() => _authorized = ok);
    } finally {
      setState(() => _authBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expectedWeight = plan.currentWeightKg;
    final expectedReps = plan.expectedReps;

    return Scaffold(
      appBar: AppBar(title: Text(plan.name)),
      body: _saving || _checkingPerms
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (!_authorized)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Health Connect permissions needed',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text('Tap Fix to request or re-enable permissions.'),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _authBusy
                                  ? null
                                  : () async {
                                await _fixPermissions();
                                await _checkPermissions(); // re-evaluate silently
                              },
                              child: _authBusy ? const Text('Requesting…') : const Text('Fix'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const Text('Expected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Weight: ${expectedWeight.toStringAsFixed(1)} kg"),
            Text("Reps (per set): $expectedReps"),
            Text("Plan Intensity: ${plan.mets.toStringAsFixed(1)} METs"),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            const Text('Achieved', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _setsCtrl,
              decoration: const InputDecoration(labelText: 'Sets'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _achievedRepsCtrl,
              decoration: const InputDecoration(labelText: 'Reps per set (achieved)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Did you meet your target?'),
              value: _targetMet,
              onChanged: (v) => setState(() => _targetMet = v),
            ),
            const SizedBox(height: 16),

            const Text('Intensity override (optional)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _metOptions.map((m) {
                final selected = _overrideMets == m;
                final label = m == null
                    ? 'Use plan default (${plan.mets.toStringAsFixed(1)} METs)'
                    : '${_labels[m]!} (${m.toStringAsFixed(1)})';
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => _overrideMets = m),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: !_authorized
                  ? null
                  : () async {
                final sets = int.tryParse(_setsCtrl.text) ?? 0;
                final reps = int.tryParse(_achievedRepsCtrl.text) ?? 0;
                if (sets <= 0 || reps <= 0) {
                  setState(() => _result = 'Enter valid sets/reps.');
                  return;
                }
                setState(() {
                  _saving = true;
                  _result = null;
                });
                try {
                  final log = await service.logSession(
                    plan: plan,
                    sets: sets,
                    achievedReps: reps,
                    targetMet: _targetMet,
                    overrideMets: _overrideMets,
                  );
                  setState(() {
                    _result =
                    "Saved!\nEnergy: ${log.energyKcal.toStringAsFixed(1)} kcal\nNext: ${plan.currentWeightKg.toStringAsFixed(1)} kg × ${plan.expectedReps} reps";
                  });
                } catch (e) {
                  setState(() => _result = 'Error: $e');
                } finally {
                  setState(() => _saving = false);
                }
              },
              child: const Text('Save session (writes to Health Connect)'),
            ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              Text(_result!, style: const TextStyle(fontSize: 16)),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                final logs = service.getLogsForPlan(plan.id);
                await showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Recent Sessions'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: logs.length,
                        itemBuilder: (_, i) {
                          final l = logs[i];
                          return ListTile(
                            title: Text(
                                "${l.date.toLocal()} | ${l.expectedWeightKg.toStringAsFixed(1)}kg x ${l.expectedReps} (exp)"),
                            subtitle: Text(
                                "Sets ${l.sets}, Reps ${l.achievedReps}, TargetMet ${l.targetMet ? "Yes" : "No"}, "
                                    "${l.energyKcal.toStringAsFixed(0)} kcal, ${l.metsUsed.toStringAsFixed(1)} METs"),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              child: const Text('View local session logs'),
            ),
          ],
        ),
      ),
    );
  }
}
