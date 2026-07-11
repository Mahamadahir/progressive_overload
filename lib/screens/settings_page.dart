import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../services/notification_service.dart';
import '../theme_controller.dart';
import 'targets_page.dart';
import 'health_connect_diagnostics_page.dart';
import 'health_setup_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Box settings;

  bool weighInEnabled = false;
  TimeOfDay weighInTime = const TimeOfDay(hour: 7, minute: 0);
  bool workoutEnabled = false;
  TimeOfDay workoutTime = const TimeOfDay(hour: 18, minute: 0);

  @override
  void initState() {
    super.initState();
    settings = Hive.box('settings');
    weighInEnabled = settings.get('weighInEnabled', defaultValue: false);
    weighInTime = TimeOfDay(
      hour: settings.get('weighInHour', defaultValue: 7),
      minute: settings.get('weighInMinute', defaultValue: 0),
    );
    workoutEnabled = settings.get('workoutEnabled', defaultValue: false);
    workoutTime = TimeOfDay(
      hour: settings.get('workoutHour', defaultValue: 18),
      minute: settings.get('workoutMinute', defaultValue: 0),
    );
  }

  Future<void> _persistReminders() async {
    await settings.put('weighInEnabled', weighInEnabled);
    await settings.put('weighInHour', weighInTime.hour);
    await settings.put('weighInMinute', weighInTime.minute);
    await settings.put('workoutEnabled', workoutEnabled);
    await settings.put('workoutHour', workoutTime.hour);
    await settings.put('workoutMinute', workoutTime.minute);

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
  }

  Future<void> _pickTime(bool isWeighIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isWeighIn ? weighInTime : workoutTime,
    );
    if (picked == null) return;
    setState(() {
      if (isWeighIn) {
        weighInTime = picked;
      } else {
        workoutTime = picked;
      }
    });
    await _persistReminders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SectionHeader('Appearance'),
          Card(
            child: AnimatedBuilder(
              animation: themeController,
              builder: (context, _) {
                final isDark = themeController.isDarkModeEnabled;
                return SwitchListTile(
                  title: const Text('Dark mode'),
                  secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                  value: isDark,
                  onChanged: themeController.setDarkMode,
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          _SectionHeader('Notifications'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Morning weigh-in'),
                  subtitle: Text('Time: ${weighInTime.format(context)}'),
                  value: weighInEnabled,
                  secondary: IconButton(
                    icon: const Icon(Icons.access_time),
                    onPressed: () => _pickTime(true),
                  ),
                  onChanged: (v) async {
                    setState(() => weighInEnabled = v);
                    await _persistReminders();
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Workout reminder'),
                  subtitle: Text('Time: ${workoutTime.format(context)}'),
                  value: workoutEnabled,
                  secondary: IconButton(
                    icon: const Icon(Icons.access_time),
                    onPressed: () => _pickTime(false),
                  ),
                  onChanged: (v) async {
                    setState(() => workoutEnabled = v);
                    await _persistReminders();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _SectionHeader('Training'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Training targets'),
              subtitle: const Text('Goals, progression defaults, muscle groups'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TargetsPage()),
              ),
            ),
          ),
          const SizedBox(height: 20),

          _SectionHeader('Health Connect'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.health_and_safety_outlined),
                  title: const Text('Setup'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HealthSetupPage()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.build_outlined),
                  title: const Text('Diagnostics'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HealthConnectDiagnosticsPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
