import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import 'support/random_connection_scenes.dart';

const String _designSeparator = ' · ';
const String _designLimitPrefix = '≤ ';
const int _largestRoundLimit = 1 << 20;
const int _stepIdentifierCount = 9;

String? _randomValidOutcome(Random random) {
  final int length = 1 + random.nextInt(maximumOutcomeLength);
  return pickOne(random, <String?>[
    null,
    pickOne(random, sampleOutcomes),
    randomOutcomeOfLength(random, length),
  ]);
}

AgentConnection _randomLabelledConnection(Random random) {
  return AgentConnection(
    from: WorkflowAgentId('from-${random.nextInt(_stepIdentifierCount)}'),
    to: WorkflowAgentId('to-${random.nextInt(_stepIdentifierCount)}'),
    condition: _randomValidOutcome(random),
    roundLimit: random.nextBool() ? null : random.nextInt(_largestRoundLimit),
  );
}

({String? condition, int? roundLimit}) _readLabel(String label) {
  final int limitStart = label.lastIndexOf(_designLimitPrefix);
  if (limitStart == -1) {
    return (condition: label, roundLimit: null);
  }

  final int roundLimit = int.parse(
    label.substring(limitStart + _designLimitPrefix.length),
  );
  if (limitStart == 0) {
    return (condition: null, roundLimit: roundLimit);
  }
  final int separatorStart = limitStart - _designSeparator.length;
  expect(label.substring(separatorStart, limitStart), _designSeparator);
  return (
    condition: label.substring(0, separatorStart),
    roundLimit: roundLimit,
  );
}

void main() {
  test('test_describe_connection_label_property_none_without_any_rule', () {
    final Random random = seededRandom(118501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentConnection connection = _randomLabelledConnection(random);
      final bool hasRule =
          connection.condition != null || connection.roundLimit != null;

      final String? label = describeConnectionLabel(connection);

      expect(label != null, hasRule);
      if (label != null) {
        expect(label.contains('\n'), isFalse);
        expect(label.trim(), label);
      }
    }
  });

  test('test_describe_connection_label_property_reads_back_its_parts', () {
    final Random random = seededRandom(118502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentConnection connection = _randomLabelledConnection(random);
      final String? label = describeConnectionLabel(connection);
      if (label == null) {
        continue;
      }

      final ({String? condition, int? roundLimit}) parts = _readLabel(label);

      expect(parts.condition, connection.condition);
      expect(parts.roundLimit, connection.roundLimit);
    }
  });

  test('test_describe_connection_label_property_depends_only_on_rules', () {
    final Random random = seededRandom(118503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentConnection connection = _randomLabelledConnection(random);
      final AgentConnection elsewhere = AgentConnection(
        from: connection.to,
        to: WorkflowAgentId(randomText(random)),
        condition: connection.condition,
        roundLimit: connection.roundLimit,
      );

      expect(
        describeConnectionLabel(elsewhere),
        describeConnectionLabel(connection),
      );
    }
  });

  test('test_describe_connection_label_property_matches_design_wording', () {
    final Random random = seededRandom(118504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String outcome = pickOne(random, sampleOutcomes);
      final int rounds = 1 + random.nextInt(mostRoundsInATest);
      final AgentConnection loop = AgentConnection(
        from: const WorkflowAgentId('review'),
        to: const WorkflowAgentId('draft'),
        condition: outcome,
        roundLimit: rounds,
      );

      expect(describeConnectionLabel(loop), '$outcome · ≤ $rounds');
      expect(describeConnectionLabel(loop.withRoundLimit(null)), outcome);
      expect(describeConnectionLabel(loop.withCondition(null)), '≤ $rounds');
    }
  });
}
