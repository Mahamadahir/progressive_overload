import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Optional: fixed ids you can reuse/cancel later
  static const int shortfallId = 2001;
  static const int instantId   = 1001;

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fallback if timezone lookup fails
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    // On Android 13+ you must ask the user to allow notifications
    await ensurePermissions();
  }

  /// Android 13+ (Tiramisu) runtime permission for notifications.
  static Future<void> ensurePermissions() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      // If you ever need exact alarms, you'd also request here:
      // await androidImpl.requestExactAlarmsPermission();
    }
  }

  /// Show a notification immediately.
  static Future<void> showNow({
    required String title,
    required String body,
    int id = instantId,
  }) async {
    // Make sure we have permission (no-op on older Android)
    await ensurePermissions();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'instant_channel',
        'Instant Notifications',
        channelDescription: 'Immediate alerts and reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(id, title, body, details);
  }

  /// Schedule a notification every day at the same local time.
  static Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    final todayAtTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    final first = todayAtTime.isAfter(now)
        ? todayAtTime
        : todayAtTime.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      first,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel',
          'Daily Reminders',
          channelDescription: 'Daily reminder notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);

  static Future<void> cancelAll() => _plugin.cancelAll();
}
