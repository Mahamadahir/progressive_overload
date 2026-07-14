import 'package:fitness_app/services/health_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../helpers/test_harness.dart';

class FakeHealthService extends HealthService {
  FakeHealthService(this.fetched);

  final Map<String, double> fetched;
  int fetchCount = 0;

  @override
  Future<Map<String, double>> getCaloriesBurnedByDayFast(
    DateTime start,
    DateTime end,
  ) async {
    fetchCount++;
    return fetched;
  }
}

void main() {
  setUpAll(initialiseHive);

  setUp(() async {
    await openCoreHiveBoxes();
    mockHealthPluginChannels();
  });

  tearDown(() async {
    resetPluginChannels();
    await clearCoreHiveBoxes();
  });

  tearDownAll(closeHive);

  test('serves non-today calorie cache and always refetches today', () async {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayKey = _key(yesterday);
    final todayKey = _key(today);
    final cache = Hive.box('health_cache');
    await cache.put('kcal:$yesterdayKey', 123.0);
    await cache.put('kcal:$todayKey', 456.0);

    final service = FakeHealthService({todayKey: 789.0});
    final result = await HealthServiceCache(
      service,
    ).getCaloriesBurnedByDayCached(yesterday, today);

    expect(result[yesterdayKey], 123.0);
    expect(result[todayKey], 789.0);
    expect(service.fetchCount, 1);
    expect(cache.get('kcal:$todayKey'), 789.0);
  });

  test('calorie read errors are not converted to zero', () async {
    const healthChannel = MethodChannel('flutter_health');
    mockHealthPluginChannels();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(healthChannel, (call) async {
          if (call.method == 'hasPermissions') return true;
          if (call.method == 'getData') {
            throw PlatformException(code: 'read_failed');
          }
          return true;
        });

    await expectLater(
      HealthService().getCaloriesBurnedByDay(
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 1),
      ),
      throwsA(anything),
    );
  });
}

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
