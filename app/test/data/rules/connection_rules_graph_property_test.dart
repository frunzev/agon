import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import 'support/random_connection_chains.dart';

const String _goodOutcome = 'again';
const List<String> _badOutcomes = <String>['Again', ' again', 'a_b', ''];
const String _circleWord = 'circle';

void main() {
  test('test_describe_ends_property_names_a_bad_round_limit_loop', () {
    final Random random = seededRandom(87601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final OrderedAgentPair pair = pickOrderedPair(random, agents);
      final int roundLimit = randomBadRoundLimit(random);

      final String? problem = describeChainWith(agents, <AgentConnection>[
        buildConnection(
          pair.later,
          pair.earlier,
          condition: _goodOutcome,
          roundLimit: roundLimit,
        ),
      ]);

      final String ends = describeConnectionEnds(pair.later, pair.earlier);
      expect(problem, contains(ends));
      expect(problem, endsWith('not $roundLimit'));
    }
  });

  test('test_describe_ends_property_names_a_bad_outcome', () {
    final Random random = seededRandom(87602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final OrderedAgentPair pair = pickOrderedPair(random, agents);
      final String badOutcome = pickOne(random, _badOutcomes);

      final String? problem = describeChainWith(agents, <AgentConnection>[
        buildConnection(
          pair.later,
          pair.earlier,
          condition: badOutcome,
          roundLimit: randomGoodRoundLimit(random),
        ),
      ]);

      final String ends = describeConnectionEnds(pair.later, pair.earlier);
      expect(problem, startsWith('Fix the outcome "$badOutcome" $ends'));
    }
  });

  test('test_describe_ends_property_names_a_repeated_pair', () {
    final Random random = seededRandom(87603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final int index = 1 + random.nextInt(agents.length - 1);
      final WorkflowAgent from = agents[index - 1];
      final WorkflowAgent to = agents[index];

      final String? problem = describeChainWith(agents, <AgentConnection>[
        buildConnection(from, to, condition: _goodOutcome, roundLimit: null),
      ]);

      final String ends = describeConnectionEnds(from, to);
      expect(problem, 'There are two connections $ends; keep one');
    }
  });

  test('test_describe_round_limit_problem_property_accepts_the_range', () {
    final Random random = seededRandom(87604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final OrderedAgentPair pair = pickOrderedPair(random, agents);

      final String? problem = describeChainWith(agents, <AgentConnection>[
        buildConnection(
          pair.later,
          pair.earlier,
          condition: _goodOutcome,
          roundLimit: randomGoodRoundLimit(random),
        ),
      ]);

      expect(problem, isNull);
    }
  });

  test('test_describe_round_limit_problem_property_loop_needs_outcome', () {
    final Random random = seededRandom(87605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final OrderedAgentPair pair = pickOrderedPair(random, agents);

      final String? problem = describeChainWith(agents, <AgentConnection>[
        buildConnection(
          pair.later,
          pair.earlier,
          condition: null,
          roundLimit: randomGoodRoundLimit(random),
        ),
      ]);

      final String ends = describeConnectionEnds(pair.later, pair.earlier);
      expect(problem, 'Give the loop $ends an outcome');
    }
  });

  test('test_describe_round_limit_problem_property_range_comes_first', () {
    final Random random = seededRandom(87606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final OrderedAgentPair pair = pickOrderedPair(random, agents);
      final int roundLimit = randomBadRoundLimit(random);

      final String? problem = describeChainWith(agents, <AgentConnection>[
        buildConnection(
          pair.later,
          pair.earlier,
          condition: null,
          roundLimit: roundLimit,
        ),
      ]);

      final String ends = describeConnectionEnds(pair.later, pair.earlier);
      expect(
        problem,
        'The loop $ends can go back $fewestLoopRounds to $mostLoopRounds '
        'rounds, not $roundLimit',
      );
    }
  });

  test('test_has_forward_cycle_property_acyclic_graphs_pass', () {
    final Random random = seededRandom(87607);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);

      expect(describeConnectionsProblem(workflow), isNull);
    }
  });

  test('test_has_forward_cycle_property_a_plain_back_edge_is_a_circle', () {
    final Random random = seededRandom(87608);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final OrderedAgentPair pair = pickOrderedPair(random, agents);

      final String? problem = describeChainWith(agents, <AgentConnection>[
        buildConnection(
          pair.later,
          pair.earlier,
          condition: null,
          roundLimit: null,
        ),
      ]);

      expect(problem, contains(_circleWord));
    }
  });

  test('test_has_forward_cycle_property_a_self_edge_is_a_circle', () {
    final Random random = seededRandom(87609);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final WorkflowAgent agent = pickOne(random, agents);

      final String? problem = describeChainWith(agents, <AgentConnection>[
        buildConnection(agent, agent, condition: null, roundLimit: null),
      ]);

      expect(problem, contains(_circleWord));
    }
  });
}
