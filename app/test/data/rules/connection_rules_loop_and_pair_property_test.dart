import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import 'support/random_connection_chains.dart';

const String _goodOutcome = 'again';
const String _otherOutcome = 'retry';
const String _loopDirectionEnding = 'must go back to an earlier step';

void main() {
  test('test_describe_loop_direction_problem_property_forward_refused', () {
    final Random random = seededRandom(87610);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final OrderedAgentPair pair = pickOrderedPair(random, agents);

      final String? problem = describeChainWith(agents, <AgentConnection>[
        buildConnection(
          pair.earlier,
          pair.later,
          condition: _goodOutcome,
          roundLimit: randomGoodRoundLimit(random),
        ),
      ]);

      final String ends = describeConnectionEnds(pair.earlier, pair.later);
      expect(problem, 'The loop $ends $_loopDirectionEnding');
    }
  });

  test('test_describe_loop_direction_problem_property_unlinked_refused', () {
    final Random random = seededRandom(87611);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final OrderedAgentPair pair = pickOrderedPair(random, agents);
      final Workflow workflow = buildConnectionWorkflow(
        agents,
        <AgentConnection>[
          buildConnection(
            pair.later,
            pair.earlier,
            condition: _goodOutcome,
            roundLimit: randomGoodRoundLimit(random),
          ),
        ],
      );

      final String? problem = describeConnectionsProblem(workflow);

      final String ends = describeConnectionEnds(pair.later, pair.earlier);
      expect(problem, 'The loop $ends $_loopDirectionEnding');
    }
  });

  test('test_describe_loop_direction_problem_property_names_first_loop', () {
    final Random random = seededRandom(87612);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final OrderedAgentPair pair = pickOrderedPair(random, agents);
      final AgentConnection goodLoop = buildConnection(
        pair.later,
        pair.earlier,
        condition: _goodOutcome,
        roundLimit: randomGoodRoundLimit(random),
      );
      final AgentConnection forwardLoop = buildConnection(
        agents.first,
        agents.last,
        condition: 'skip ahead',
        roundLimit: randomGoodRoundLimit(random),
      );

      final String? problem = describeChainWith(agents, <AgentConnection>[
        goodLoop,
        forwardLoop,
      ]);

      final String ends = describeConnectionEnds(agents.first, agents.last);
      expect(problem, 'The loop $ends $_loopDirectionEnding');
    }
  });

  test(
    'test_describe_repeated_pair_problem_property_outcomes_still_repeat',
    () {
      final Random random = seededRandom(87613);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<WorkflowAgent> agents = randomChainAgents(random);
        final OrderedAgentPair pair = pickOrderedPair(random, agents);

        final Workflow workflow = buildConnectionWorkflow(
          agents,
          <AgentConnection>[
            buildConnection(
              pair.earlier,
              pair.later,
              condition: _goodOutcome,
              roundLimit: null,
            ),
            buildConnection(
              pair.earlier,
              pair.later,
              condition: _otherOutcome,
              roundLimit: null,
            ),
          ],
        );

        final String ends = describeConnectionEnds(pair.earlier, pair.later);
        expect(
          describeConnectionsProblem(workflow),
          'There are two connections $ends; keep one',
        );
      }
    },
  );

  test('test_describe_repeated_pair_problem_property_reverse_is_distinct', () {
    final Random random = seededRandom(87614);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomChainAgents(random);
      final int index = 1 + random.nextInt(agents.length - 1);

      final String? problem = describeChainWith(agents, <AgentConnection>[
        buildConnection(
          agents[index],
          agents[index - 1],
          condition: _goodOutcome,
          roundLimit: randomGoodRoundLimit(random),
        ),
      ]);

      expect(problem, isNull);
    }
  });

  test('test_describe_repeated_pair_problem_property_any_copy_repeats', () {
    final Random random = seededRandom(87615);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      if (workflow.connections.isEmpty) {
        continue;
      }
      final AgentConnection copied = pickOne(random, workflow.connections);
      final Workflow repeated = workflow.withGraph(
        agents: workflow.agents,
        connections: <AgentConnection>[...workflow.connections, copied],
      );

      final String from = workflow.findAgent(copied.from).name;
      final String to = workflow.findAgent(copied.to).name;
      expect(
        describeConnectionsProblem(repeated),
        'There are two connections from $from to $to; keep one',
      );
    }
  });
}
