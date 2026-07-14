import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/food_component.dart';

const aiDraftComponentIdPrefix = 'ai-draft:';

enum AiFoodLogMode { mealText, labelPhoto }

class AiFoodLogException implements Exception {
  final String message;

  const AiFoodLogException(this.message);

  @override
  String toString() => message;
}

class AiMealLineDraft {
  final String name;
  final double grams;
  final double kcalPer100g;
  final double confidence;

  const AiMealLineDraft({
    required this.name,
    required this.grams,
    required this.kcalPer100g,
    required this.confidence,
  });

  factory AiMealLineDraft.fromJson(Map<String, Object?> json) {
    final name = _readString(json, 'name');
    final grams = _readPositiveNumber(json, 'grams');
    final kcalPer100g = _readPositiveNumber(json, 'kcalPer100g');
    final confidence = _readConfidence(json, 'confidence');
    return AiMealLineDraft(
      name: name,
      grams: grams,
      kcalPer100g: kcalPer100g,
      confidence: confidence,
    );
  }
}

class AiMealDraft {
  final String mealName;
  final List<AiMealLineDraft> lines;
  final List<String> warnings;

  const AiMealDraft({
    required this.mealName,
    required this.lines,
    required this.warnings,
  });

  factory AiMealDraft.fromJson(Map<String, Object?> json) {
    if (json['kind'] != 'meal') {
      throw const AiFoodLogException('AI returned the wrong response type.');
    }
    final rawLines = json['lines'];
    if (rawLines is! List || rawLines.isEmpty) {
      throw const AiFoodLogException('AI did not return any meal rows.');
    }
    return AiMealDraft(
      mealName: _readString(json, 'mealName'),
      lines: rawLines
          .map(_asMap)
          .map(AiMealLineDraft.fromJson)
          .toList(growable: false),
      warnings: _readStringList(json, 'warnings'),
    );
  }
}

class AiComponentDraft {
  final String name;
  final double kcalPer100g;
  final double servingSizeGrams;
  final double kcalPerServing;
  final double confidence;
  final List<String> warnings;

  const AiComponentDraft({
    required this.name,
    required this.kcalPer100g,
    required this.servingSizeGrams,
    required this.kcalPerServing,
    required this.confidence,
    required this.warnings,
  });

  factory AiComponentDraft.fromJson(Map<String, Object?> json) {
    if (json['kind'] != 'component') {
      throw const AiFoodLogException('AI returned the wrong response type.');
    }
    return AiComponentDraft(
      name: _readString(json, 'name'),
      kcalPer100g: _readPositiveNumber(json, 'kcalPer100g'),
      servingSizeGrams: _readPositiveNumber(json, 'servingSizeGrams'),
      kcalPerServing: _readPositiveNumber(json, 'kcalPerServing'),
      confidence: _readConfidence(json, 'confidence'),
      warnings: _readStringList(json, 'warnings'),
    );
  }
}

class AiMappedMealLine {
  final FoodComponent component;
  final double grams;
  final double confidence;
  final bool isPendingComponent;

  const AiMappedMealLine({
    required this.component,
    required this.grams,
    required this.confidence,
    required this.isPendingComponent,
  });
}

class AiMappedMealDraft {
  final String mealName;
  final List<AiMappedMealLine> lines;
  final List<String> warnings;

  const AiMappedMealDraft({
    required this.mealName,
    required this.lines,
    required this.warnings,
  });
}

typedef ParseFoodLogInvoker =
    Future<Map<String, Object?>> Function(Map<String, Object?> request);

class AiFoodLogService {
  AiFoodLogService({ParseFoodLogInvoker? invoker}) : _invoker = invoker;

  final ParseFoodLogInvoker? _invoker;

  Future<AiMealDraft> parseMealText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const AiFoodLogException('Enter a meal description first.');
    }
    final response = await _callParseFoodLog({
      'mode': 'meal_text',
      'text': trimmed,
    });
    return AiMealDraft.fromJson(response);
  }

  Future<AiComponentDraft> parseLabelPhoto({
    required String base64,
    required String mimeType,
  }) async {
    if (base64.isEmpty) {
      throw const AiFoodLogException('Choose a nutrition-label photo first.');
    }
    if (mimeType != 'image/jpeg' && mimeType != 'image/png') {
      throw const AiFoodLogException('Choose a JPEG or PNG label photo.');
    }
    final response = await _callParseFoodLog({
      'mode': 'label_photo',
      'image': {'base64': base64, 'mimeType': mimeType},
    });
    return AiComponentDraft.fromJson(response);
  }

  AiMappedMealDraft mapMealDraft({
    required AiMealDraft draft,
    required List<FoodComponent> existingComponents,
  }) {
    final byName = {
      for (final component in existingComponents)
        component.name.trim().toLowerCase(): component,
    };
    final lines = <AiMappedMealLine>[];

    for (var index = 0; index < draft.lines.length; index += 1) {
      final line = draft.lines[index];
      final match = byName[line.name.trim().toLowerCase()];
      final component =
          match ??
          FoodComponent(
            id: '$aiDraftComponentIdPrefix${DateTime.now().microsecondsSinceEpoch}-$index',
            name: line.name,
            kcalPer100g: line.kcalPer100g,
          );
      lines.add(
        AiMappedMealLine(
          component: component,
          grams: line.grams,
          confidence: line.confidence,
          isPendingComponent: match == null,
        ),
      );
    }

    return AiMappedMealDraft(
      mealName: draft.mealName,
      lines: lines,
      warnings: draft.warnings,
    );
  }

  Future<Map<String, Object?>> _callParseFoodLog(
    Map<String, Object?> request,
  ) async {
    if (_invoker != null) {
      return _invoker(request);
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('parseFoodLog');
      final response = await callable.call<Map<Object?, Object?>>(request);
      return _normaliseMap(response.data);
    } on FirebaseFunctionsException catch (error) {
      throw AiFoodLogException(error.message ?? 'AI parsing failed.');
    } on TimeoutException {
      throw const AiFoodLogException('AI parsing timed out.');
    }
  }
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return _normaliseMap(value);
  throw const AiFoodLogException('AI returned malformed JSON.');
}

Map<String, Object?> _normaliseMap(Map<Object?, Object?> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}

String _readString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw AiFoodLogException('AI returned an invalid $key.');
}

double _readPositiveNumber(Map<String, Object?> json, String key) {
  final value = json[key];
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null || !number.isFinite || number <= 0) {
    throw AiFoodLogException('AI returned an invalid $key.');
  }
  return number;
}

double _readConfidence(Map<String, Object?> json, String key) {
  final value = json[key];
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null || !number.isFinite) {
    throw AiFoodLogException('AI returned an invalid $key.');
  }
  return number.clamp(0, 1).toDouble();
}

List<String> _readStringList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List) {
    throw AiFoodLogException('AI returned an invalid $key.');
  }
  return value
      .whereType<String>()
      .map((warning) => warning.trim())
      .where((warning) => warning.isNotEmpty)
      .toList(growable: false);
}
