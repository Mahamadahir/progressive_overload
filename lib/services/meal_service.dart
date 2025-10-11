import 'dart:math';
import 'package:hive/hive.dart';
import '../models/food_component.dart';
import '../models/meal_template.dart';
import '../models/meal_log.dart';
import '../models/meal_component_line.dart';

String _dayKey(DateTime d) =>
    "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

class MealService {
  static const _templatesBoxName = 'meal_templates';
  static const _logsBoxName = 'meal_logs';
  static const _componentsBoxName = 'food_components';

  // simple id generator (avoid extra deps)
  static final _rand = Random();
  static String _id() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = _rand.nextInt(1 << 32).toRadixString(36);
    return '${ts}_$r';
  }

  Box<MealTemplate> get _templates => Hive.box<MealTemplate>(_templatesBoxName);
  Box<MealLog> get _logs => Hive.box<MealLog>(_logsBoxName);
  Box<FoodComponent> get _components => Hive.box<FoodComponent>(_componentsBoxName);

  // ---------- Components ----------
  List<FoodComponent> getAllComponents() {
    final list = _components.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<FoodComponent> searchComponents(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return getAllComponents();
    return _components.values
        .where((c) => c.name.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<FoodComponent> createOrUpdateComponent({
    String? id,
    required String name,
    required double kcalPer100g,
  }) async {
    final cid = id ?? _id();
    final c = FoodComponent(id: cid, name: name.trim(), kcalPer100g: kcalPer100g);
    await _components.put(cid, c);
    return c;
  }

  Future<void> deleteComponent(String id) async {
    await _components.delete(id);
  }

  FoodComponent? getComponent(String id) => _components.get(id);

  // ---------- Templates ----------
  List<MealTemplate> getAllTemplates() {
    final list = _templates.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<MealTemplate> searchTemplates(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return getAllTemplates();
    return _templates.values
        .where((t) =>
    t.name.toLowerCase().contains(q) ||
        t.components.any((s) => s.toLowerCase().contains(q)))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Most recently used templates (by logs), unique.
  List<MealTemplate> recentTemplates({int limit = 8}) {
    final usedIds = <String>{};
    final result = <MealTemplate>[];
    final logs = _logs.values.toList()..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    for (final l in logs) {
      if (l.templateId != null && usedIds.add(l.templateId!)) {
        final t = _templates.get(l.templateId!);
        if (t != null) {
          result.add(t);
          if (result.length >= limit) break;
        }
      }
    }
    if (result.length < limit) {
      final more = getAllTemplates()
          .where((t) => !usedIds.contains(t.id))
          .take(limit - result.length);
      result.addAll(more);
    }
    return result;
  }

  /// Create/update a template from structured lines. Also back-fill legacy fields.
  Future<MealTemplate> createOrUpdateTemplateFromLines({
    String? id,
    required String name,
    required List<MealComponentLine> lines,
  }) async {
    // compute totals
    double totalMass = 0, totalKcal = 0;
    final tags = <String>{};
    for (final line in lines) {
      final c = getComponent(line.componentId);
      if (c == null) continue;
      totalMass += line.grams;
      totalKcal += (c.kcalPer100g * line.grams / 100.0);
      tags.add(c.name);
    }

    final tid = id ?? _id();
    final t = MealTemplate(
      id: tid,
      name: name.trim(),
      baseMassGrams: totalMass,
      baseKcal: totalKcal,
      components: tags.toList()..sort(),
      lines: lines,
    );
    await _templates.put(tid, t);
    return t;
  }

  Future<MealTemplate> updateTemplate(MealTemplate updated) async {
    await _templates.put(updated.id, updated);
    return updated;
  }

  Future<void> deleteTemplate(String id) async {
    await _templates.delete(id);
  }

  // ---------- Logging ----------
  static double _kcalFor(FoodComponent c, double grams) =>
      c.kcalPer100g * grams / 100.0;

  /// Log a meal from structured lines (and snapshot them).
  Future<MealLog> logMealFromLines({
    String? templateId,
    required String name,
    required List<MealComponentLine> lines,
    DateTime? when,
  }) async {
    final snapshots = <MealComponentSnapshot>[];
    double totalMass = 0, totalKcal = 0;

    for (final line in lines) {
      final c = getComponent(line.componentId);
      if (c == null) continue;
      final kcal = _kcalFor(c, line.grams);
      totalMass += line.grams;
      totalKcal += kcal;
      snapshots.add(MealComponentSnapshot(
        name: c.name,
        kcalPer100g: c.kcalPer100g,
        grams: line.grams,
        kcal: kcal,
      ));
    }

    final id = _id();
    final log = MealLog(
      id: id,
      loggedAt: (when ?? DateTime.now().toUtc()),
      templateId: templateId,
      name: name.trim(),
      components: snapshots.map((s) => s.name).toList(), // legacy tag list
      massGrams: totalMass, // legacy
      kcal: totalKcal,
      snapshot: snapshots,
      totalMassGrams: totalMass,
    );
    await _logs.put(id, log);
    return log;
  }

  double todayIntakeKcal({DateTime? now}) {
    final t = (now ?? DateTime.now());
    final start = DateTime(t.year, t.month, t.day).toUtc();
    final end = start.add(const Duration(days: 1));
    return _logs.values
        .where((e) => e.loggedAt.isAfter(start) && e.loggedAt.isBefore(end))
        .fold(0.0, (sum, e) => sum + e.kcal);
  }

  List<MealLog> todayLogs({DateTime? now}) {
    final t = (now ?? DateTime.now());
    final start = DateTime(t.year, t.month, t.day).toUtc();
    final end = start.add(const Duration(days: 1));
    final list = _logs.values
        .where((e) => e.loggedAt.isAfter(start) && e.loggedAt.isBefore(end))
        .toList();
    list.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return list;
  }

  /// Intake (kcal) per day in the inclusive range [start, end], keyed by YYYY-MM-DD (local).
  /// Only returns days that have at least one meal log (so you can detect "Unavailable").
  Map<String, double> intakeByDay(DateTime start, DateTime end) {
    final map = <String, double>{};
    final startUtc = DateTime(start.year, start.month, start.day).toUtc();
    final endExclusiveUtc =
        DateTime(end.year, end.month, end.day).add(const Duration(days: 1)).toUtc();

    for (final log in _logs.values) {
      final stamp = log.loggedAt;
      if (stamp.isBefore(startUtc) || !stamp.isBefore(endExclusiveUtc)) {
        continue;
      }
      final local = stamp.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final key = _dayKey(day);
      map.update(key, (v) => v + log.kcal, ifAbsent: () => log.kcal);
    }
    return map;
  }

  // Edit/delete logs
  Future<MealLog?> updateLogFromNewLines(String id, List<MealComponentLine> lines) async {
    final box = _logs;
    final log = box.get(id);
    if (log == null) return null;

    final snapshots = <MealComponentSnapshot>[];
    double totalMass = 0, totalKcal = 0;

    for (final line in lines) {
      final c = getComponent(line.componentId);
      if (c == null) continue;
      final kcal = _kcalFor(c, line.grams);
      totalMass += line.grams;
      totalKcal += kcal;
      snapshots.add(MealComponentSnapshot(
        name: c.name,
        kcalPer100g: c.kcalPer100g,
        grams: line.grams,
        kcal: kcal,
      ));
    }

    log
      ..snapshot = snapshots
      ..components = snapshots.map((s) => s.name).toList()
      ..totalMassGrams = totalMass
      ..massGrams = totalMass
      ..kcal = totalKcal;
    await box.put(id, log);
    return log;
  }

  Future<void> deleteLog(String id) async => _logs.delete(id);

  // Seed defaults once (components)
  Future<void> seedDefaultsIfEmpty() async {
    if (_components.isNotEmpty) return;
    final defs = <FoodComponent>[
      FoodComponent(id: _id(), name: 'Chicken breast', kcalPer100g: 165),
      FoodComponent(id: _id(), name: 'Cooked white rice', kcalPer100g: 130),
      FoodComponent(id: _id(), name: 'Olive oil', kcalPer100g: 884),
      FoodComponent(id: _id(), name: 'Broccoli', kcalPer100g: 35),
      FoodComponent(id: _id(), name: 'Banana', kcalPer100g: 89),
      FoodComponent(id: _id(), name: 'Oats (dry)', kcalPer100g: 389),
      FoodComponent(id: _id(), name: 'Whole milk', kcalPer100g: 61),
      FoodComponent(id: _id(), name: 'Whey protein', kcalPer100g: 400),
      FoodComponent(id: _id(), name: 'Greek yogurt (plain)', kcalPer100g: 59),
    ];
    for (final c in defs) {
      await _components.put(c.id, c);
    }
  }
}

// --- Extension: fast/month-batched helpers for trends ---
extension MealServiceTrends on MealService {
  /// All logs in the inclusive range [start, end] (UTC in storage; grouped by local day for UI).
  List<MealLog> logsInRange(DateTime start, DateTime end) {
    final startUtc = DateTime(start.year, start.month, start.day).toUtc();
    final endExclusiveUtc =
        DateTime(end.year, end.month, end.day).add(const Duration(days: 1)).toUtc();

    final list = Hive.box<MealLog>('meal_logs')
        .values
        .where((log) =>
            !log.loggedAt.isBefore(startUtc) && log.loggedAt.isBefore(endExclusiveUtc))
        .toList();
    list.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return list;
  }

  /// Meals (logs) by local day key.
  Map<String, List<MealLog>> mealsByDay(DateTime start, DateTime end) {
    final map = <String, List<MealLog>>{};
    for (final l in logsInRange(start, end)) {
      final local = l.loggedAt.toLocal();
      final key = _dayKey(DateTime(local.year, local.month, local.day));
      (map[key] ??= <MealLog>[]).add(l);
    }
    // newest first in each bucket
    for (final key in map.keys) {
      map[key]!.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    }
    return map;
  }
}
