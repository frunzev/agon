import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/startup/forgotten_device_problem.dart';
import 'package:agent_orchestration/startup/hosting_problem.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/random_inputs.dart';

const int _missingKindOdds = 4;
const List<String> _nodeHostingProblems = <String>[
  'the app server cannot listen on port 8731: address in use',
  'the saved hosted server record is damaged',
  'the app server answered 401: the device is not paired',
  'this device has no account yet',
];

String _randomHostingText(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _nodeHostingProblems);
  }
  return randomHostileText(random);
}

node.HostingProblemKind? _randomOptionalKind(Random random) {
  if (random.nextInt(_missingKindOdds) == 0) {
    return null;
  }
  return pickOne(random, node.HostingProblemKind.values);
}

void main() {
  test('test_hosting_problem_constructor_property_keeps_the_node_text', () {
    final Random random = seededRandom(95201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String nodeText = _randomHostingText(random);
      final node.HostingProblemKind? kind = _randomOptionalKind(random);

      final HostingProblem problem = HostingProblem(nodeText, kind: kind);

      expect(problem.message, nodeText);
      expect(problem.kind, kind);
    }
  });

  test('test_hosting_problem_constructor_property_is_explained_in_its_'
      'own_words', () {
    final Random random = seededRandom(95202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String nodeText = _randomHostingText(random);

      final String? explanation = describeProblemForPeople(
        HostingProblem(nodeText, kind: _randomOptionalKind(random)),
      );

      final bool isBlank = nodeText.trim().isEmpty;
      expect(explanation, isBlank ? isNull : nodeText);
    }
  });

  test('test_hosting_problem_constructor_property_is_never_a_forgotten_'
      'device', () {
    final Random random = seededRandom(95203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final HostingProblem problem = HostingProblem(
        _randomHostingText(random),
        kind: _randomOptionalKind(random),
      );

      expect(isForgottenDeviceProblem(problem), isFalse);
    }
  });

  test('test_is_damaged_device_record_problem_property_only_the_record_'
      'damaged_kind_counts', () {
    final Random random = seededRandom(95204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.HostingProblemKind? kind = _randomOptionalKind(random);
      final HostingProblem problem = HostingProblem(
        _randomHostingText(random),
        kind: kind,
      );

      final bool isDamaged = isDamagedDeviceRecordProblem(problem);

      expect(isDamaged, kind == node.HostingProblemKind.recordDamaged);
    }
  });

  test('test_is_damaged_device_record_problem_property_the_text_never_'
      'decides', () {
    final Random random = seededRandom(95205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.HostingProblemKind? kind = _randomOptionalKind(random);
      final String firstText = _randomHostingText(random);
      final String otherText = _randomHostingText(random);

      final bool firstAnswer = isDamagedDeviceRecordProblem(
        HostingProblem(firstText, kind: kind),
      );
      final bool otherAnswer = isDamagedDeviceRecordProblem(
        HostingProblem(otherText, kind: kind),
      );

      expect(firstAnswer, otherAnswer, reason: '$firstText / $otherText');
    }
  });

  test('test_is_damaged_device_record_problem_property_other_problems_'
      'never_count', () {
    final Random random = seededRandom(95206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = _randomHostingText(random);
      final List<Object> otherProblems = <Object>[
        StateError(text),
        FormatException(text),
        text,
        node.HostingProblemKind.recordDamaged,
      ];

      for (final Object otherProblem in otherProblems) {
        expect(isDamagedDeviceRecordProblem(otherProblem), isFalse);
      }
    }
  });
}
