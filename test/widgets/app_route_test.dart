import 'package:fitness_app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dynamic plan routes handle missing or wrong-typed arguments', () {
    const app = App();

    for (final name in ['/session', '/plan_detail', '/plan_charts']) {
      expect(
        () => app.handleGeneratedRoute(RouteSettings(name: name)),
        returnsNormally,
      );
      expect(
        () =>
            app.handleGeneratedRoute(RouteSettings(name: name, arguments: 42)),
        returnsNormally,
      );
      expect(
        app.handleGeneratedRoute(RouteSettings(name: name, arguments: 42)),
        isA<MaterialPageRoute<dynamic>>(),
      );
    }
  });
}
