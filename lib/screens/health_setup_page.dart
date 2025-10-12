import 'package:flutter/material.dart';
import 'package:health/health.dart';                // enums & types
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fitness_app/health_singleton.dart';               // shared health instance
import 'package:fitness_app/services/health_service.dart';        // centralized, serialized prompts
import 'health_connect_diagnostics_page.dart';

class HealthSetupPage extends StatefulWidget {
  const HealthSetupPage({super.key});

  @override
  State<HealthSetupPage> createState() => _HealthSetupPageState();
}

class _HealthSetupPageState extends State<HealthSetupPage> {
  bool _busy = false;
  String? _result;

  Future<void> _ensureHealthConnectAndAuthorize() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _result = null;
    });

    try {
      await health.configure();

      // 1) Ensure Health Connect present or updated
      final s = await health.getHealthConnectSdkStatus();
      if (s == HealthConnectSdkStatus.sdkUnavailable ||
          s == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        final market = Uri.parse('market://details?id=com.google.android.apps.healthdata');
        final web = Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata');
        if (!await launchUrl(market, mode: LaunchMode.externalApplication)) {
          await launchUrl(web, mode: LaunchMode.externalApplication);
        }
        setState(() => _result = 'Opened Play Store to install/update Health Connect.');
        return;
      }

      // 2) System permission (Android 10+)
      final activityPerm = await Permission.activityRecognition.request();
      if (!activityPerm.isGranted) {
        setState(() => _result = 'Activity recognition permission denied.');
        return;
      }

      // 3) Request all Health Connect permissions up-front (single prompt flow)
      final hcAuthorized =
          await HealthConnectDiagnosticsHelper.requestPermissionsSerial();
      if (!hcAuthorized) {
        setState(() =>
            _result = 'Health Connect permissions were denied or interrupted.');
        return;
      }

      // 4) Verify workout + total calories + weight scopes (no prompt if already granted)
      final okWorkout = await HealthService.ensureWorkoutWritePermissions();
      if (!okWorkout) {
        setState(() =>
            _result = 'Workout/Total calories permission verification failed.');
        return;
      }

      final okWeight = await HealthService.ensureAuthorized(
        types: const [HealthDataType.WEIGHT],
        permissions: const [HealthDataAccess.READ],
      );
      if (!okWeight) {
        setState(() => _result = 'Weight (read) permission denied.');
        return;
      }

      setState(() => _result = 'Health Connect setup complete ✅');
    } catch (e) {
      setState(() => _result = 'Setup error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Health Connect Setup")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _busy ? null : _ensureHealthConnectAndAuthorize,
              child: Text(_busy ? "Working…" : "Connect to Health Data"),
            ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_result!, textAlign: TextAlign.center),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/calories'),
              child: const Text("View Calorie Burn"),
            ),
          ],
        ),
      ),
    );
  }
}
