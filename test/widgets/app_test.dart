import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_app/app.dart';

void main() {
  final app = App();

  test('buildLightTheme configures the light theme', () {
    // TODO(Mrmah): Add assertions for buildLightTheme.
    app.buildLightTheme();
  });

  test('buildDarkTheme configures the dark theme', () {
    // TODO(Mrmah): Add assertions for buildDarkTheme.
    app.buildDarkTheme();
  });

  test('buildRoutes registers base routes', () {
    // TODO(Mrmah): Add assertions for buildRoutes.
    app.buildRoutes();
  });

  test('handleGeneratedRoute wires dynamic routes', () {
    // TODO(Mrmah): Add assertions for handleGeneratedRoute.
    app.handleGeneratedRoute(
      const RouteSettings(name: '/session', arguments: 'plan-id'),
    );
  });
}
