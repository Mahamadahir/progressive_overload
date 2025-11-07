// lib/services/health_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:health/health.dart';
import '../health_singleton.dart'; // shared singleton
import 'package:hive/hive.dart';
import 'health_history_permission.dart';

class HealthService {
  /// Global mutex to serialize *all* permission prompts across the app.
  static Completer<void>? _authMutex;

  static Future<T> _inAuthCriticalSection<T>(
    Future<T> Function() action,
  ) async {
    // If a prompt is in progress, wait for it to finish.
    while (_authMutex != null) {
      try {
        await _authMutex!.future;
      } catch (_) {
        // ignore and continue
      }
    }
    // Create a new mutex for our critical section.
    final lock = Completer<void>();
    _authMutex = lock;
    try {
      return await action();
    } finally {
      // Release the mutex.
      if (!lock.isCompleted) lock.complete();
      _authMutex = null;
    }
  }

  /// Ask for permissions for the given types (defaults to READ).
  /// - Checks hasPermissions(...) first.
  /// - Serializes the actual prompt so only one sheet shows at a time.
  static Future<bool> ensureAuthorized({
    required List<HealthDataType> types,
    List<HealthDataAccess>? permissions,
  }) async {
    await health.configure();
    final perms =
        permissions ?? types.map((t) => HealthDataAccess.READ).toList();

    // Fast path: already granted
    final has = await health.hasPermissions(types, permissions: perms) ?? false;
    if (has) return true;

    // Slow path: serialize the prompt
    return _inAuthCriticalSection<bool>(() async {
      // Re-check inside the lock in case another call granted while we waited
      final stillHas =
          await health.hasPermissions(types, permissions: perms) ?? false;
      if (stillHas) return true;

      return await health.requestAuthorization(types, permissions: perms);
    });
  }

  /// Ask for required perms for a workout write (WORKOUT + TOTAL_CALORIES_BURNED).
  /// - Checks hasPermissions(...) first.
  /// - Serializes the prompt to avoid overlapping sheets.
  static Future<bool> ensureWorkoutWritePermissions() async {
    await health.configure();

    const types = <HealthDataType>[
      HealthDataType.WORKOUT,
      HealthDataType.TOTAL_CALORIES_BURNED,
    ];
    const perms = <HealthDataAccess>[
      HealthDataAccess.READ_WRITE,
      HealthDataAccess.READ_WRITE,
    ];

    // Fast path
    final has = await health.hasPermissions(types, permissions: perms) ?? false;
    if (has) return true;

    // Serialized prompt
    return _inAuthCriticalSection<bool>(() async {
      final stillHas =
          await health.hasPermissions(types, permissions: perms) ?? false;
      if (stillHas) return true;

      return await health.requestAuthorization(types, permissions: perms);
    });
  }

  /// Save a strength exercise record (writes workout + total kcal).
  static Future<bool> writeStrengthWorkout({
    required DateTime start,
    required DateTime end,
    required double energyKcal,
    required String title,
  }) async {
    final ok = await ensureWorkoutWritePermissions();
    if (!ok) return false;

    await health.configure();

    return health.writeWorkoutData(
      activityType: HealthWorkoutActivityType.STRENGTH_TRAINING,
      start: start,
      end: end,
      totalEnergyBurned: energyKcal.round(), // kcal (int)
      title: title,
    );
  }

  /// Calories burned per day in [start, end] using TOTAL_CALORIES_BURNED, keyed by YYYY-MM-DD (local).
  Future<Map<String, double>> getCaloriesBurnedByDay(
    DateTime start,
    DateTime end,
  ) async {
    await health.configure();

    const types = [HealthDataType.TOTAL_CALORIES_BURNED];
    const perms = [HealthDataAccess.READ];

    final granted = await ensureAuthorized(types: types, permissions: perms);
    if (!granted) {
      throw Exception('Health permission denied for TOTAL_CALORIES_BURNED');
    }

    final result = <String, double>{};

    for (int i = 0; i <= end.difference(start).inDays; i++) {
      final day = start.add(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      try {
        final data = await health.getHealthDataFromTypes(
          startTime: dayStart,
          endTime: dayEnd,
          types: types,
        );

        double total = 0.0;
        for (final dp in data) {
          final v = dp.value;
          if (v is NumericHealthValue) {
            total += v.numericValue.toDouble();
          }
        }

        result[_yyyyMmDd(dayStart)] = total;
        if (kDebugMode) {
          debugPrint(
            '[Calories/day] ${_yyyyMmDd(dayStart)} -> $total kcal (${data.length} pts)',
          );
        }
      } catch (e) {
        debugPrint('[Calories/day] ${_yyyyMmDd(dayStart)} error: $e');
        result[_yyyyMmDd(dayStart)] = 0.0;
      }
    }

    return result;
  }

  /// Batched: pull TOTAL_CALORIES_BURNED once and group by day.
  Future<Map<String, double>> getCaloriesBurnedByDayFast(
    DateTime start,
    DateTime end,
  ) async {
    await health.configure();
    const types = [HealthDataType.TOTAL_CALORIES_BURNED];
    final ok = await ensureAuthorized(types: types);
    if (!ok) {
      throw Exception('Health permission denied for TOTAL_CALORIES_BURNED');
    }

    // inclusive end-of-day
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59);

    // one call for the whole range
    final points = await health.getHealthDataFromTypes(
      startTime: startDay,
      endTime: endDay,
      types: types,
    );

    final out = <String, double>{};
    for (final dp in points) {
      final v = dp.value;
      if (v is! NumericHealthValue) continue;
      final key = _yyyyMmDd(dp.dateTo); // health already gives local DateTimes
      out.update(
        key,
        (x) => x + v.numericValue.toDouble(),
        ifAbsent: () => v.numericValue.toDouble(),
      );
    }

    // Optional sanity: clamp truly wild daily sums (provider bugs)
    out.updateAll((_, kcal) {
      if (!kcal.isFinite || kcal < 0) return 0.0;
      if (kcal > 30000) return kcal / 1000;
      return kcal;
    });

    return out;
  }

  /// Batched: pull STEPS once, de-duplicate, group by day.
  Future<Map<String, double>> getStepsByDayFast(
    DateTime start,
    DateTime end,
  ) async {
    await health.configure();
    const types = [HealthDataType.STEPS];
    final ok = await ensureAuthorized(types: types);
    if (!ok) throw Exception('Health permission denied for STEPS');

    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59);

    var points = await health.getHealthDataFromTypes(
      startTime: startDay,
      endTime: endDay,
      types: types,
    );

    try {
      // ignore: deprecated_member_use_from_same_package
      points = health.removeDuplicates(points);
    } catch (_) {}

    final out = <String, double>{};
    for (final dp in points) {
      final v = dp.value;
      if (v is! NumericHealthValue) continue;
      final key = _yyyyMmDd(dp.dateTo);
      out.update(
        key,
        (x) => x + v.numericValue.toDouble(),
        ifAbsent: () => v.numericValue.toDouble(),
      );
    }
    return out;
  }

  /// Weight per day (READ): last measurement of the day (kg).
  Future<Map<String, double>> getWeightByDay(
    DateTime start,
    DateTime end,
  ) async {
    await health.configure();
    const types = [HealthDataType.WEIGHT];
    final ok = await ensureAuthorized(types: types);
    if (!ok) throw Exception('Health permission denied for WEIGHT');

    final result = <String, double>{};

    // Pull once over the full range, then pick latest per-day.
    final all = await health.getHealthDataFromTypes(
      startTime: DateTime(start.year, start.month, start.day),
      endTime: DateTime(end.year, end.month, end.day, 23, 59, 59),
      types: types,
    );

    // Keep latest per day
    final latest = <String, ({DateTime t, double kg})>{};
    for (final dp in all) {
      final localTo = dp.dateTo;
      final key = _yyyyMmDd(DateTime(localTo.year, localTo.month, localTo.day));
      final v = dp.value;
      if (v is! NumericHealthValue) continue;
      final kg = v.numericValue.toDouble();

      final existing = latest[key];
      if (existing == null || localTo.isAfter(existing.t)) {
        latest[key] = (t: localTo, kg: kg);
      }
    }
    for (final e in latest.entries) {
      result[e.key] = e.value.kg;
    }
    return result;
  }

  /// Latest body weight (kg) in last 30 days.
  static Future<double?> getLatestWeight() async {
    await health.configure();

    const types = [HealthDataType.WEIGHT];

    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));

    final granted = await ensureAuthorized(types: types);
    if (!granted) return null;

    final data = await health.getHealthDataFromTypes(
      startTime: from,
      endTime: now,
      types: types,
    );

    if (data.isEmpty) return null;

    data.sort((a, b) => b.dateTo.compareTo(a.dateTo));

    final v = data.first.value;
    if (v is NumericHealthValue) return v.numericValue.toDouble(); // kg
    return null;
  }

  static String _yyyyMmDd(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
}

/// ===== Extension: Trends helpers (additions only) =====
extension HealthServiceTrends on HealthService {
  /// Weight (kg) per day (last value that day) in [start,end).
  Future<Map<String, double?>> getWeightByDay(
    DateTime start,
    DateTime end,
  ) async {
    await health.configure();

    const types = [HealthDataType.WEIGHT];
    final ok = await HealthService.ensureAuthorized(
      types: types,
      permissions: const [HealthDataAccess.READ],
    );
    if (!ok) {
      return {};
    }

    final map = <String, double?>{};
    for (int i = 0; i <= end.difference(start).inDays; i++) {
      final day = DateTime(
        start.year,
        start.month,
        start.day,
      ).add(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final data = await health.getHealthDataFromTypes(
        startTime: dayStart,
        endTime: dayEnd,
        types: types,
      );

      if (data.isEmpty) {
        map[HealthService._yyyyMmDd(dayStart)] = null;
        continue;
      }
      data.sort((a, b) => a.dateTo.compareTo(b.dateTo)); // last of day
      final v = data.last.value;
      map[HealthService._yyyyMmDd(dayStart)] = (v is NumericHealthValue)
          ? v.numericValue.toDouble()
          : null;
    }
    return map;
  }

  /// Workouts per day: count + total energy (kcal) for [start,end).
  Future<Map<String, ({int count, int kcal})>> getWorkoutAggByDay(
    DateTime start,
    DateTime end,
  ) async {
    await health.configure();

    const types = [HealthDataType.WORKOUT];
    final ok = await HealthService.ensureAuthorized(
      types: types,
      permissions: const [HealthDataAccess.READ],
    );
    if (!ok) {
      return {};
    }

    final map = <String, ({int count, int kcal})>{};
    for (int i = 0; i <= end.difference(start).inDays; i++) {
      final day = DateTime(
        start.year,
        start.month,
        start.day,
      ).add(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final data = await health.getHealthDataFromTypes(
        startTime: dayStart,
        endTime: dayEnd,
        types: types,
      );

      int count = 0;
      int kcal = 0;
      for (final dp in data) {
        final v = dp.value;
        if (v is WorkoutHealthValue) {
          count++;
          if (v.totalEnergyBurned != null) kcal += v.totalEnergyBurned!;
        }
      }
      map[HealthService._yyyyMmDd(dayStart)] = (count: count, kcal: kcal);
    }
    return map;
  }
}

/// ===== Cache-aware, day-granular fetchers (today always refetched) =====
extension HealthServiceCache on HealthService {
  static const _cacheBoxName = 'health_cache';
  Box get _cache => Hive.box(_cacheBoxName);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  bool _isToday(DateTime d) => _isSameDay(d, DateTime.now());

  Iterable<DateTime> _eachDay(DateTime start, DateTime end) sync* {
    var d = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(e)) {
      yield d;
      d = d.add(const Duration(days: 1));
    }
  }

  List<(DateTime, DateTime)> _coalesceDays(Iterable<DateTime> days) {
    final list = days.toList()..sort();
    final ranges = <(DateTime, DateTime)>[];
    if (list.isEmpty) return ranges;
    var runStart = list.first;
    var prev = list.first;
    for (var i = 1; i < list.length; i++) {
      final cur = list[i];
      if (cur.difference(prev).inDays == 1) {
        prev = cur;
        continue;
      }
      ranges.add((runStart, prev));
      runStart = cur;
      prev = cur;
    }
    ranges.add((runStart, prev));
    return ranges;
  }

  /// Burned kcal per day with caching (non-today days served from cache).
  Future<Map<String, double>> getCaloriesBurnedByDayCached(
    DateTime start,
    DateTime end,
  ) async {
    await health.configure();
    final out = <String, double>{};
    final missing = <DateTime>[];

    for (final day in _eachDay(start, end)) {
      final keyDay = HealthService._yyyyMmDd(day);
      final cacheKey = 'kcal:$keyDay';
      final cached = _cache.get(cacheKey);
      final isToday = _isToday(day);
      if (!isToday && cached is num) {
        out[keyDay] = cached.toDouble();
      } else {
        missing.add(day);
      }
    }

    for (final (rs, re) in _coalesceDays(missing)) {
      final fetched = await getCaloriesBurnedByDayFast(rs, re);
      fetched.forEach((k, v) {
        double cleaned;
        if (!v.isFinite || v < 0) {
          cleaned = 0.0;
        } else if (v > 30000) {
          cleaned = v / 1000;
        } else {
          cleaned = v;
        }
        _cache.put('kcal:$k', cleaned);
        out[k] = cleaned;
      });
      for (final d in _eachDay(rs, re)) {
        final k = HealthService._yyyyMmDd(d);
        out.putIfAbsent(k, () => 0.0);
        _cache.put('kcal:$k', out[k]);
      }
    }
    return out;
  }

  /// Steps per day with caching (non-today days served from cache).
  Future<Map<String, int>> getStepsByDayCached(
    DateTime start,
    DateTime end,
  ) async {
    await health.configure();
    final out = <String, int>{};
    final missing = <DateTime>[];

    for (final day in _eachDay(start, end)) {
      final keyDay = HealthService._yyyyMmDd(day);
      final cacheKey = 'steps:$keyDay';
      final cached = _cache.get(cacheKey);
      final isToday = _isToday(day);
      if (!isToday && cached is int) {
        out[keyDay] = cached;
      } else {
        missing.add(day);
      }
    }

    for (final (rs, re) in _coalesceDays(missing)) {
      final fetched = await getStepsByDayFast(rs, re); // Map<String,double>
      fetched.forEach((k, v) {
        final steps = (v.isFinite && v >= 0) ? v.round() : 0;
        _cache.put('steps:$k', steps);
        out[k] = steps;
      });
      for (final d in _eachDay(rs, re)) {
        final k = HealthService._yyyyMmDd(d);
        out.putIfAbsent(k, () => 0);
        _cache.put('steps:$k', out[k]);
      }
    }
    return out;
  }

  /// Weight per day with caching (stores NaN for “no data”). Today always refetched.
  Future<Map<String, double?>> getWeightByDayCached(
    DateTime start,
    DateTime end,
  ) async {
    await health.configure();
    final out = <String, double?>{};
    final missing = <DateTime>[];

    for (final day in _eachDay(start, end)) {
      final keyDay = HealthService._yyyyMmDd(day);
      final cacheKey = 'weight:$keyDay';
      final cached = _cache.get(cacheKey);
      final isToday = _isToday(day);
      if (!isToday && cached is num) {
        final v = cached.toDouble();
        out[keyDay] = v.isNaN ? null : v;
      } else {
        missing.add(day);
      }
    }

    for (final (rs, re) in _coalesceDays(missing)) {
      final fetched = await getWeightByDay(rs, re); // Map<String,double>
      for (final d in _eachDay(rs, re)) {
        final k = HealthService._yyyyMmDd(d);
        if (fetched.containsKey(k)) {
          final v = fetched[k]!;
          _cache.put('weight:$k', v);
          out[k] = v;
        } else {
          _cache.put('weight:$k', double.nan); // mark “no data”
          out[k] = null;
        }
      }
    }
    return out;
  }
}
