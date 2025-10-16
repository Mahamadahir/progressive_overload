import 'dart:io';

import 'package:flutter/services.dart';

class HealthHistoryPermission {
  static const _channel = MethodChannel('fitness_app/health_connect');

  static Future<bool> ensureHistoryPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      final granted = await _channel.invokeMethod<bool>(
        'ensureHistoryPermission',
      );
      return granted ?? false;
    } on PlatformException {
      return false;
    }
  }
}
