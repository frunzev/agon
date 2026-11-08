import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

Set<WorkflowAgentId> _listInputs(
  WorkflowAgent agent,
  List<AgentConnection> connections,
) {
  return <WorkflowAgentId>{
    for (final AgentConnection connection in connections)
      if (connection.to == agent.id) connection.from,
  };
}

bool _hasEveryInput(
  WorkflowAgent agent,
  Set<WorkflowAgentId> orderedIds,
  List<AgentConnection> connections,
) {
  return orderedIds.containsAll(_listInputs(agent, connections));
}

Set<WorkflowAgentId> _randomOrderedIds(Random random, Workflow workflow) {
  return <WorkflowAgentId>{
    for (final WorkflowAgent agent in workflow.agents)
      if (random.nextBool()) agent.id,
  };
}

List<WorkflowAgent> _randomRemaining(Random random, Workflow workflow) {
  final List<WorkflowAgent> remaining = <WorkflowAgent>[
    for (final WorkflowAgent agent in workflow.agents)
      if (random.nextInt(3) != 0) agent,
  ];
  remaining.shuffle(random);
  return remaining;
}

void main() {
  test('test_find_ready_index_property_finds_the_first_ready_agent', () {
    final Random random = seededRandom(52201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final List<WorkflowAgent> remaining = _randomRemaining(random, workflow);
      final Set<WorkflowAgentId> orderedIds = _randomOrderedIds(
        random,
        workflow,
      );
      final List<AgentConnection> connections = workflow.connections;

      final int? readyIndex = findReadyIndex(
        remaining,
        orderedIds,
        connections,
      );

      final int lastBlocked = readyIndex ?? remaining.length;
      for (int index = 0; index < lastBlocked; index += 1) {
        expect(
          _hasEveryInput(remaining[index], orderedIds, connections),
          isFalse,
        );
      }
      if (readyIndex != null) {
        expect(
          _hasEveryInput(remaining[readyIndex], orderedIds, connections),
          isTrue,
        );
      }
    }
  });

  test('test_find_ready_index_property_nothing_remaining_finds_nothing', () {
    final Random random = seededRandom(52202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);

      final int? readyIndex = findReadyIndex(
        const <WorkflowAgent>[],
        _randomOrderedIds(random, workflow),
        workflow.connections,
      );

      expect(readyIndex, isNull);
    }
  });

  test('test_find_ready_index_property_all_ordered_readies_the_first', () {
    final Random random = seededRandom(52203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final List<WorkflowAgent> remaining = _randomRemaining(random, workflow);
      final Set<WorkflowAgentId> everyId = <WorkflowAgentId>{
        for (final WorkflowAgent agent in workflow.agents) agent.id,
      };

      final int? readyIndex = findReadyIndex(
        remaining,
        everyId,
        workflow.connections,
      );

      expect(readyIndex, remaining.isEmpty ? isNull : 0);
    }
  });

  test('test_is_ready_property_an_agent_without_inputs_is_ready', () {
    final Random random = seededRandom(52204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final List<WorkflowAgent> sources = <WorkflowAgent>[
        for (final WorkflowAgent agent in workflow.agents)
          if (_listInputs(agent, workflow.connections).isEmpty) agent,
      ];
      if (sources.isEmpty) {
        continue;
      }

      final int? readyIndex = findReadyIndex(
        <WorkflowAgent>[pickOne(random, sources)],
        const <WorkflowAgentId>{},
        workflow.connections,
      );

      expect(readyIndex, 0);
    }
  });

  test('test_is_ready_property_ordered_inputs_make_an_agent_ready', () {
    final Random random = seededRandom(52205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent agent = pickOne(random, workflow.agents);
      final Set<WorkflowAgentId> orderedIds = <WorkflowAgentId>{
        ..._listInputs(agent, workflow.connections),
        ..._randomOrderedIds(random, workflow),
      };

      final int? readyIndex = findReadyIndex(
        <WorkflowAgent>[agent],
        orderedIds,
        workflow.connections,
      );

      expect(readyIndex, 0);
    }
  });

  test('test_is_ready_property_one_missing_input_blocks_an_agent', () {
    final Random random = seededRandom(52206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final List<WorkflowAgent> fedAgents = <WorkflowAgent>[
        for (final WorkflowAgent agent in workflow.agents)
          if (_listInputs(agent, workflow.connections).isNotEmpty) agent,
      ];
      if (fedAgents.isEmpty) {
        continue;
      }
      final WorkflowAgent agent = pickOne(random, fedAgents);
      final Set<WorkflowAgentId> inputs = _listInputs(
        agent,
        workflow.connections,
      );
      final WorkflowAgentId missing = pickOne(random, inputs.toList());
      final Set<WorkflowAgentId> orderedIds = <WorkflowAgentId>{
        ..._randomOrderedIds(random, workflow),
        ...inputs,
      };
      orderedIds.remove(missing);

      final int? readyIndex = findReadyIndex(
        <WorkflowAgent>[agent],
        orderedIds,
        workflow.connections,
      );

      expect(readyIndex, isNull);
    }
  });
}
