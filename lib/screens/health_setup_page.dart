import 'package:flutter/material.dart';
import 'package:health/health.dart';                // enums & types
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../health_singleton.dart';               // shared health instance
import '../../services/health_service.dart';        // centralized, serialized prompts

class HealthSetupPage extends StatefulWidget {
  const HealthSetupPage({super.key});

  @override
  _HealthSetupPageState createState() => _HealthSetupPageState();
}

class _HealthSetupPageState extends State<HealthSetupPage> {
  bool _busy = false;
  String? _result;

  Future<void> _ensureHealthConnectAndAuthorize() async {
    if (_busy) return;
    setState(() { _busy = true; _result = null; });

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

      // 3) App scopes via centralized, serialized service
      //    a) Write workout + total calories
      final okWorkout = await HealthService.ensureWorkoutWritePermissions();
      if (!okWorkout) { setState(() => _result = 'Workout/Total calories permission denied.'); return; }

      //    b) Read active energy
      final okActive = await HealthService.ensureAuthorized(
        types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
        permissions: const [HealthDataAccess.READ],
      );
      if (!okActive) { setState(() => _result = 'Active energy (read) permission denied.'); return; }

      //    c) Read weight (flip to READ_WRITE only if you truly write weight)
      final okWeight = await HealthService.ensureAuthorized(
        types: const [HealthDataType.WEIGHT],
        permissions: const [HealthDataAccess.READ],
      );
      if (!okWeight) { setState(() => _result = 'Weight (read) permission denied.'); return; }

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
