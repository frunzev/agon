import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/default_protected_patterns.dart';
import 'package:agent_orchestration/data/rules/protected_patterns.dart';

import '../../support/random_inputs.dart';
import 'support/schedule_scope_run_tables.dart';

void main() {
  test('test_default_protected_patterns_property_match_the_shared_rust_'
      'list', () {
    final List<String> shared = readSharedDefaultProtectedPatterns();

    expect(defaultProtectedPatterns, orderedEquals(shared));
  });

  test('test_default_protected_patterns_property_pass_the_pattern_'
      'rules', () {
    final String? problem = describeProtectedFilesProblem(
      defaultProtectedPatterns,
    );

    expect(problem, isNull);
  });

  test('test_default_protected_patterns_property_no_two_protect_the_same_'
      'files', () {
    final Random random = seededRandom(89301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String first = pickOne(random, defaultProtectedPatterns);
      final String second = pickOne(random, defaultProtectedPatterns);

      final String? problem = describeProtectedFilesProblem(<String>[
        first,
        second,
      ]);

      expect(problem == null, first != second, reason: '$first $second');
    }
  });
}
