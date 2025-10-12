// lib/diagnostics/health_connect_diagnostics_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:health/health.dart';

import 'package:fitness_app/health_singleton.dart'; // uses: final Health health = Health();
import 'package:fitness_app/services/health_service.dart';

/// Top-level constants so helpers + UI can both reference them.
const List<HealthDataType> hcTypes = <HealthDataType>[
  HealthDataType.WORKOUT,
  HealthDataType.TOTAL_CALORIES_BURNED,
  HealthDataType.WEIGHT,
];

List<HealthDataAccess> get hcPermissions => <HealthDataAccess>[
  HealthDataAccess.READ_WRITE, // WORKOUT
  HealthDataAccess.READ_WRITE, // TOTAL_CALORIES_BURNED
  HealthDataAccess.READ, // WEIGHT
];

class HealthConnectDiagnosticsPage extends StatefulWidget {
  const HealthConnectDiagnosticsPage({super.key});

  @override
  State<HealthConnectDiagnosticsPage> createState() =>
      _HealthConnectDiagnosticsPageState();
}

class _HealthConnectDiagnosticsPageState
    extends State<HealthConnectDiagnosticsPage> {
  String status = 'Unknown';
  String? error;
  bool checking = false;
  bool installed = false;
  bool hasPerms = false;

  // Guard to prevent overlapping permission prompts
  bool _authBusy = false;

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() {
      checking = true;
      error = null;
      status = 'Checking...';
      installed = false;
      hasPerms = false;
    });

    try {
      if (!Platform.isAndroid) {
        setState(() {
          status = 'This page is for Android / Health Connect';
          checking = false;
        });
        return;
      }

      await health.configure();

      final sdkStatus = await health.getHealthConnectSdkStatus();
      final name = sdkStatus?.name.toUpperCase() ?? 'UNKNOWN';
      status = 'Health Connect Status: $name';

      installed = (sdkStatus == HealthConnectSdkStatus.sdkAvailable);

      final has = await health.hasPermissions(hcTypes, permissions: hcPermissions);
      hasPerms = has ?? false;
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> _installHealthConnect() async {
    try {
      await health.installHealthConnect();
    } catch (e) {
      setState(() => error = 'installHealthConnect error: $e');
    }
  }

  Future<void> _requestAuth() async {
    if (_authBusy) return;
    setState(() {
      _authBusy = true;
      error = null;
    });
    try {
      final authorized =
          await HealthConnectDiagnosticsHelper.requestPermissionsSerial();
      setState(() => hasPerms = authorized);
    } catch (e) {
      setState(() => error = 'requestAuthorization error: $e');
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _revoke() async {
    try {
      await health.revokePermissions();
      setState(() => hasPerms = false);
    } catch (e) {
      setState(() => error = 'revokePermissions error: $e');
    }
  }

  /// Debug helper: check each requested type individually
  Future<void> _debugCheckEachPermission() async {
    final buf = StringBuffer('Debug permission check:\n');
    for (int i = 0; i < hcTypes.length; i++) {
      final t = [hcTypes[i]];
      final p = [hcPermissions[i]];
      final ok = await health.hasPermissions(t, permissions: p) ?? false;
      buf.writeln(' - ${hcTypes[i].name} (${p.first.name}): ${ok ? "OK" : "NO"}');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(buf.toString())),
    );
  }

  Future<void> _readSmokeTest() async {
    try {
      await health.configure();
      const t = [HealthDataType.TOTAL_CALORIES_BURNED];
      const p = [HealthDataAccess.READ];

      await health.hasPermissions(t, permissions: p); // Warm the plugin cache
      final ok = await health.requestAuthorization(t, permissions: p);
      if (!ok) throw 'READ permission denied for TOTAL_CALORIES_BURNED';

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final pts = await health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: t,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Read OK: ${pts.length} point(s)')),
      );
    } catch (e) {
      setState(() => error = 'readSmokeTest error: $e');
    }
  }

  Future<void> _writeSmokeTest() async {
    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(minutes: 1));

      final ok = await HealthService.writeStrengthWorkout(
        start: start,
        end: end,
        energyKcal: 1.0,
        title: 'Diagnostics test',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Write OK' : 'Write failed')),
      );
    } catch (e) {
      setState(() => error = 'writeSmokeTest error: $e');
    }
  }

  Future<void> _openAppAccess() async {
    if (_authBusy) return;
    final s = await health.getHealthConnectSdkStatus();
    if (s == HealthConnectSdkStatus.sdkUnavailable ||
        s == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
      final market =
      Uri.parse('market://details?id=com.google.android.apps.healthdata');
      final web = Uri.parse(
          'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata');
      if (!await launchUrl(market, mode: LaunchMode.externalApplication)) {
        await launchUrl(web, mode: LaunchMode.externalApplication);
      }
    } else {
      await _requestAuth();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Connect Diagnostics')),
      body: checking
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(status, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _runChecks,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Re-check'),
                ),
                ElevatedButton.icon(
                  onPressed: installed ? null : _installHealthConnect,
                  icon: const Icon(Icons.download),
                  label: const Text('Install / Update Health Connect'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Permissions: ${hasPerms ? "GRANTED" : "NOT GRANTED"}${_authBusy ? " (requesting...)" : ""}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _authBusy ? null : _requestAuth,
                  child: const Text('Request permissions'),
                ),
                OutlinedButton(
                  onPressed: _authBusy ? null : _revoke,
                  child: const Text('Revoke permissions'),
                ),
                OutlinedButton(
                  onPressed: _authBusy ? null : _openAppAccess,
                  child: const Text('Open HC app access'),
                ),
                OutlinedButton(
                  onPressed: _debugCheckEachPermission,
                  child: const Text('Debug: check each permission'),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('Smoke tests'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _readSmokeTest,
                  child: const Text('Read test'),
                ),
                ElevatedButton(
                  onPressed: _writeSmokeTest,
                  child: const Text('Write test'),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text('Error: $error', style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Centralized helpers (call these from other screens like SessionPage)
/// ---------------------------------------------------------------------------
class HealthConnectDiagnosticsHelper {
  /// Passive check: returns true if all required permissions are already granted.
  /// Does NOT show any UI prompts.
  static Future<bool> checkPermissionsPassive() async {
    if (!Platform.isAndroid) return false;
    try {
      await health.configure();
      final has = await health.hasPermissions(hcTypes, permissions: hcPermissions);
      return has ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Active, serialized permission flow. Requests required OS/system permissions first,
  /// then calls Health Connect authorization. Returns true if authorized.
  static Future<bool> requestPermissionsSerial() async {
    try {
      await health.configure();

      // System permissions required for ActivityRecognition
      try {
        await Permission.activityRecognition.request();
      } catch (_) {
        // permission_handler issues shouldn't block us; we'll continue to health request
      }

      // Force re-check to ensure plugin isn't returning stale state; then request auth
      bool? hasAll = await health.hasPermissions(hcTypes, permissions: hcPermissions);

      // Some plugin states might be ambiguous for WRITE; force re-request
      hasAll = false;

      bool authorized = false;
      if (hasAll != true) {
        authorized = await health.requestAuthorization(hcTypes, permissions: hcPermissions);

        // attempt optional background/history authorizations where available
        try {
          await health.requestHealthDataHistoryAuthorization();
        } catch (_) {}
        try {
          await health.requestHealthDataInBackgroundAuthorization();
        } catch (_) {}
      } else {
        authorized = true;
      }

      return authorized;
    } catch (e) {
      // if something goes wrong, return false
      return false;
    }
  }
}








