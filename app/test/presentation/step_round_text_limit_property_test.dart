import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/step_round_text.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/random_branching_workflows.dart';
import '../support/random_inputs.dart';
import '../support/random_step_rounds.dart';
import '../support/random_workflows.dart';

List<AgentConnection> _loopsRerunning(
  Workflow workflow,
  WorkflowAgentId agentId,
) {
  return <AgentConnection>[
    for (final AgentConnection connection in workflow.connections)
      if (connection.isLoop &&
          hasForwardPath(workflow, from: connection.to, to: agentId))
        connection,
  ];
}

int? _expectedRoundLimit(Workflow workflow, WorkflowAgentId agentId) {
  final List<AgentConnection> loops = _loopsRerunning(workflow, agentId);
  if (loops.length != 1) {
    return null;
  }
  return loops.single.roundLimit;
}

String? _randomLoopSource(Random random, Workflow workflow) {
  return pickOne<String?>(random, <String?>[
    null,
    randomHostileText(random),
    if (workflow.agents.isNotEmpty) pickOne(random, workflow.agents).name,
  ]);
}

AgentConnection _forwardConnection({
  required WorkflowAgentId from,
  required WorkflowAgentId to,
}) {
  return AgentConnection(
    from: from,
    to: to,
    condition: null,
    roundLimit: null,
  );
}

AgentConnection _oneRoundLoop({
  required WorkflowAgentId from,
  required WorkflowAgentId to,
  required String condition,
}) {
  return AgentConnection(
    from: from,
    to: to,
    condition: condition,
    roundLimit: 1,
  );
}

Workflow _nestedLoopWorkflow(Random random) {
  final List<WorkflowAgent> agents = <WorkflowAgent>[
    for (int index = 0; index < 3; index += 1) randomAgent(random, index),
  ];
  final WorkflowAgentId first = agents[0].id;
  final WorkflowAgentId second = agents[1].id;
  final WorkflowAgentId third = agents[2].id;

  return Workflow(
    id: const WorkflowId('nested-loops'),
    name: 'nested-loops',
    availability: const AllWorkspaces(),
    agents: agents,
    connections: <AgentConnection>[
      _forwardConnection(from: first, to: second),
      _forwardConnection(from: second, to: third),
      _oneRoundLoop(from: third, to: second, condition: 'fix'),
      _oneRoundLoop(from: third, to: first, condition: 'redo'),
    ],
    signature: null,
  );
}

void main() {
  test('test_find_step_round_limit_property_one_rerunning_loop_only', () {
    final Random random = seededRandom(94701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);

      for (final WorkflowAgent agent in workflow.agents) {
        final RunStep step = buildAgentRunStep(
          agent: agent,
          loopSource: _randomLoopSource(random, workflow),
          earlierRounds: randomEarlierRounds(random, 1 + random.nextInt(3)),
          result: null,
        );

        expect(
          findStepRoundLimit(step: step, workflow: workflow),
          _expectedRoundLimit(workflow, agent.id),
        );
      }
    }
  });

  test('test_find_step_round_limit_property_unknown_graph_has_no_limit', () {
    final Random random = seededRandom(94702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent agent = pickOne(random, workflow.agents);
      final RunStep step = buildAgentRunStep(
        agent: agent,
        loopSource: _randomLoopSource(random, workflow),
        earlierRounds: randomEarlierRounds(random, 1),
        result: null,
      );
      final RunStep stepWithoutAgent = RunStep(
        name: step.name,
        agentId: null,
        runner: null,
        status: step.status,
        startedAt: null,
        finishedAt: null,
        result: null,
        outcome: null,
        loopSource: step.loopSource,
        earlierRounds: step.earlierRounds,
      );

      expect(findStepRoundLimit(step: step, workflow: null), isNull);
      expect(
        findStepRoundLimit(step: stepWithoutAgent, workflow: workflow),
        isNull,
      );
    }
  });

  test('test_find_step_round_limit_property_limit_within_loop_bounds', () {
    final Random random = seededRandom(94703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);

      for (final WorkflowAgent agent in workflow.agents) {
        final int? limit = findStepRoundLimit(
          step: buildAgentRunStep(
            agent: agent,
            loopSource: null,
            earlierRounds: const <EarlierRound>[],
            result: null,
          ),
          workflow: workflow,
        );
        if (limit == null) {
          continue;
        }

        expect(limit, inInclusiveRange(1, mostRoundsInATest));
        expect(
          workflow.connections.any(
            (AgentConnection connection) => connection.roundLimit == limit,
          ),
          isTrue,
        );
      }
    }
  });

  test('test_describe_step_round_property_matches_round_and_limit_model', () {
    final Random random = seededRandom(94704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent agent = pickOne(random, workflow.agents);
      final int earlierCount = random.nextInt(5);
      final RunStep step = buildAgentRunStep(
        agent: agent,
        loopSource: _randomLoopSource(random, workflow),
        earlierRounds: randomEarlierRounds(random, earlierCount),
        result: null,
      );
      final int? limit = _expectedRoundLimit(workflow, agent.id);

      final String? text = describeStepRound(step: step, workflow: workflow);

      if (earlierCount == 0) {
        expect(text, isNull);
      } else if (limit == null) {
        expect(text, 'round ${earlierCount + 1}');
      } else {
        expect(text, 'round ${earlierCount + 1} of ${limit + 1}');
      }
    }
  });

  test(
    'test_describe_step_round_property_nested_loop_never_exceeds_total',
    () {
      final Random random = seededRandom(94705);
      final Workflow workflow = _nestedLoopWorkflow(random);
      final WorkflowAgent second = workflow.agents[1];
      final RunStep step = buildAgentRunStep(
        agent: second,
        loopSource: workflow.agents[2].name,
        earlierRounds: randomEarlierRounds(random, 3),
        result: null,
      );

      expect(describeStepRound(step: step, workflow: workflow), 'round 4');
      expect(findStepRoundLimit(step: step, workflow: workflow), isNull);
    },
  );

  test('test_describe_step_round_property_no_rounds_without_earlier_ones', () {
    final Random random = seededRandom(94706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final RunStep step = buildAgentRunStep(
        agent: pickOne(random, workflow.agents),
        loopSource: _randomLoopSource(random, workflow),
        earlierRounds: const <EarlierRound>[],
        result: random.nextBool() ? randomWordPhrase(random) : null,
      );

      expect(describeStepRound(step: step, workflow: workflow), isNull);
      expect(describeStepRound(step: step, workflow: null), isNull);
    }
  });
}
