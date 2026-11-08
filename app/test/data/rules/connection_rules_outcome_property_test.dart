import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';

import '../../support/random_inputs.dart';
import '../../support/random_repository_addresses.dart';
import 'support/random_connection_chains.dart';

const String _modelAlphabet = 'ab9 -A_é\t ';
const String _outcomeAlphabet = 'abcdefghijklmnopqrstuvwxyz0123456789 -';
const List<String> _paddings = <String>[' ', '\t', ' ', '\n', '　'];
final RegExp _allowedOutcomeCharacters = RegExp(r'^[a-z0-9 \-]+$');

bool _isWellFormedByModel(String outcome) {
  final bool hasAllowedLength =
      outcome.isNotEmpty && outcome.length <= maximumOutcomeLength;
  final bool hasNoEdgeSpace =
      !outcome.startsWith(' ') && !outcome.endsWith(' ');
  final bool hasAllowedCharacters = _allowedOutcomeCharacters.hasMatch(
    outcome,
  );
  return hasAllowedLength && hasNoEdgeSpace && hasAllowedCharacters;
}

String _randomWellFormedOutcome(Random random) {
  final int length = 1 + random.nextInt(maximumOutcomeLength);
  final String letters = randomCharacters(random, _outcomeAlphabet, length);
  final String trimmed = letters.trim();
  return trimmed.isEmpty ? 'a' : trimmed;
}

List<String> _distinctOutcomes(Random random, int count) {
  final Set<String> outcomes = <String>{};
  while (outcomes.length < count) {
    outcomes.add(_randomWellFormedOutcome(random));
  }
  return outcomes.toList();
}

Workflow _fanOut(List<WorkflowAgent> agents, List<String> outcomes) {
  final List<AgentConnection> connections = <AgentConnection>[
    for (int index = 1; index < agents.length; index += 1)
      buildConnection(
        agents.first,
        agents[index],
        condition: outcomes[index - 1],
        roundLimit: null,
      ),
  ];
  return buildConnectionWorkflow(agents, connections);
}

void main() {
  test('test_is_well_formed_outcome_property_matches_the_model', () {
    final Random random = seededRandom(87501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int length = random.nextInt(maximumOutcomeLength + 6);
      final String outcome = randomCharacters(random, _modelAlphabet, length);

      final bool isWellFormed = isWellFormedOutcome(outcome);

      expect(isWellFormed, _isWellFormedByModel(outcome), reason: outcome);
    }
  });

  test('test_is_well_formed_outcome_property_refuses_any_padding', () {
    final Random random = seededRandom(87502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String outcome = _randomWellFormedOutcome(random);
      final String padding = pickOne(random, _paddings);
      final String padded = random.nextBool()
          ? '$padding$outcome'
          : '$outcome$padding';

      expect(isWellFormedOutcome(outcome), isTrue, reason: outcome);
      expect(isWellFormedOutcome(padded), isFalse, reason: padded);
    }
  });

  test('test_describe_outcome_problem_property_malformed_is_format', () {
    final Random random = seededRandom(87503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final List<String> outcomes = _distinctOutcomes(random, agents.length);
      final Workflow workflow = _fanOut(agents, outcomes);
      final String malformed =
          '${_randomWellFormedOutcome(random)}${pickOne(random, _paddings)}';

      final String? problem = describeOutcomeProblem(
        workflow: workflow,
        connection: pickOne(random, workflow.connections),
        outcome: malformed,
      );

      expect(problem, outcomeFormatProblem);
    }
  });

  test('test_describe_outcome_problem_property_accepts_a_fresh_outcome', () {
    final Random random = seededRandom(87504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final List<String> outcomes = _distinctOutcomes(random, agents.length);
      final Workflow workflow = _fanOut(agents, outcomes);

      final String? problem = describeOutcomeProblem(
        workflow: workflow,
        connection: pickOne(random, workflow.connections),
        outcome: outcomes.last,
      );

      expect(problem, isNull);
    }
  });

  test('test_is_outcome_taken_elsewhere_property_own_outcome_is_free', () {
    final Random random = seededRandom(87505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final List<String> outcomes = _distinctOutcomes(random, agents.length);
      final Workflow workflow = _fanOut(agents, outcomes);
      final AgentConnection connection = pickOne(random, workflow.connections);

      final String? problem = describeOutcomeProblem(
        workflow: workflow,
        connection: connection,
        outcome: connection.condition!,
      );

      expect(problem, isNull);
    }
  });

  test('test_is_outcome_taken_elsewhere_property_sibling_is_taken', () {
    final Random random = seededRandom(87506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final List<String> outcomes = _distinctOutcomes(random, agents.length);
      final Workflow workflow = _fanOut(agents, outcomes);
      final List<AgentConnection> shuffled = List<AgentConnection>.of(
        workflow.connections,
      );
      shuffled.shuffle(random);
      if (shuffled.length < 2) {
        continue;
      }

      final String? problem = describeOutcomeProblem(
        workflow: workflow,
        connection: shuffled.first,
        outcome: shuffled.last.condition!,
      );

      final String fromName = agents.first.name;
      final String taken = shuffled.last.condition!;
      expect(problem, 'Another connection from $fromName already uses $taken');
    }
  });

  test('test_is_outcome_taken_elsewhere_property_other_steps_never_count', () {
    final Random random = seededRandom(87507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final String outcome = _randomWellFormedOutcome(random);
      final List<AgentConnection> connections = <AgentConnection>[
        for (int index = 1; index < agents.length; index += 1)
          buildConnection(
            agents[index - 1],
            agents[index],
            condition: outcome,
            roundLimit: null,
          ),
      ];
      final Workflow workflow = buildConnectionWorkflow(agents, connections);

      final String? problem = describeOutcomeProblem(
        workflow: workflow,
        connection: pickOne(random, connections),
        outcome: outcome,
      );

      expect(problem, isNull);
    }
  });
}
