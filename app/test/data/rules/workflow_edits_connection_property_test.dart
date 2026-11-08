import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import 'support/connection_proposals.dart';

Workflow? _randomNonEmptyWorkflow(Random random) {
  final Workflow workflow = randomBranchingWorkflow(random);
  if (workflow.agents.isEmpty) {
    return null;
  }
  return workflow;
}

Workflow? _randomConnectedWorkflow(Random random) {
  final Workflow workflow = randomBranchingWorkflow(random);
  if (workflow.connections.isEmpty) {
    return null;
  }
  return workflow;
}

Workflow _randomEdit(Random random, Workflow workflow) {
  final WorkflowAgent blank = buildBlankAgent(workflow);
  if (workflow.agents.isEmpty || random.nextBool()) {
    return addAgent(workflow, blank);
  }
  return removeAgent(workflow, pickOne(random, workflow.agents).id);
}

void main() {
  test('test_add_agent_property_appends_the_step_at_the_end', () {
    final Random random = seededRandom(91201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final WorkflowAgent blank = buildBlankAgent(workflow);

      final Workflow added = addAgent(workflow, blank);

      expect(added.agents, <WorkflowAgent>[...workflow.agents, blank]);
      expect(added.connections, workflow.connections);
      expect(added.name, workflow.name);
    }
  });

  test('test_add_agent_property_removing_it_restores_the_design', () {
    final Random random = seededRandom(91202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final WorkflowAgent blank = buildBlankPersonStep(workflow);

      final Workflow restored = removeAgent(
        addAgent(workflow, blank),
        blank.id,
      );

      expect(hasSameDesign(restored, workflow), isTrue);
    }
  });

  test('test_replace_agent_property_unknown_steps_are_refused', () {
    final Random random = seededRandom(91203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final WorkflowAgent stranger = buildBlankAgent(workflow);

      expect(() => replaceAgent(workflow, stranger), throwsStateError);
    }
  });

  test('test_replace_agent_property_a_step_replaced_by_itself_stays', () {
    final Random random = seededRandom(91204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow? workflow = _randomNonEmptyWorkflow(random);
      if (workflow == null) {
        continue;
      }
      final WorkflowAgent agent = pickOne(random, workflow.agents);

      final Workflow replaced = replaceAgent(workflow, agent);

      expect(hasSameDesign(replaced, workflow), isTrue);
    }
  });

  test('test_drop_loops_not_pointing_back_property_removing_a_loop_drops_'
      'only_it', () {
    final Random random = seededRandom(91205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final List<AgentConnection> loops = <AgentConnection>[
        for (final AgentConnection connection in workflow.connections)
          if (connection.isLoop) connection,
      ];
      if (loops.isEmpty) {
        continue;
      }
      final AgentConnection removed = pickOne(random, loops);

      final Workflow edited = removeConnection(workflow, removed);

      expect(edited.connections, <AgentConnection>[
        for (final AgentConnection connection in workflow.connections)
          if (connection != removed) connection,
      ]);
    }
  });

  test('test_drop_loops_not_pointing_back_property_keeps_loops_that_'
      'still_point_back', () {
    final Random random = seededRandom(91206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow? workflow = _randomConnectedWorkflow(random);
      if (workflow == null) {
        continue;
      }
      final AgentConnection removed = pickOne(random, workflow.connections);
      final Workflow withoutOnly = workflow.withGraph(
        agents: workflow.agents,
        connections: <AgentConnection>[
          for (final AgentConnection connection in workflow.connections)
            if (connection != removed) connection,
        ],
      );

      final Workflow edited = removeConnection(workflow, removed);

      final List<AgentConnection> expected = <AgentConnection>[
        for (final AgentConnection connection in withoutOnly.connections)
          if (!connection.isLoop || pointsBack(withoutOnly, connection))
            connection,
      ];
      expect(edited.connections, expected);
    }
  });

  test('test_drop_loops_not_pointing_back_property_forward_edges_stay', () {
    final Random random = seededRandom(91207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow? workflow = _randomNonEmptyWorkflow(random);
      if (workflow == null) {
        continue;
      }
      final WorkflowAgentId removedId = pickOne(random, workflow.agents).id;

      final Workflow edited = removeAgent(workflow, removedId);

      final List<AgentConnection> expectedForward = <AgentConnection>[
        for (final AgentConnection edge in listForwardConnections(workflow))
          if (edge.from != removedId && edge.to != removedId) edge,
      ];
      expect(listForwardConnections(edited), expectedForward);
    }
  });

  test('test_find_connection_property_returns_the_stored_connection', () {
    final Random random = seededRandom(91208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow? workflow = _randomConnectedWorkflow(random);
      if (workflow == null) {
        continue;
      }
      final AgentConnection stored = pickOne(random, workflow.connections);
      final AgentConnection probe = proposeConnection(
        stored.from,
        stored.to,
        roundLimit: random.nextBool() ? null : 7,
      );

      expect(findConnection(workflow, probe), same(stored));
    }
  });

  test('test_find_connection_property_unknown_pairs_are_refused', () {
    final Random random = seededRandom(91209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow? workflow = _randomNonEmptyWorkflow(random);
      if (workflow == null) {
        continue;
      }
      final AgentConnection probe = randomConnectionProposal(random, workflow);
      final bool isStored = workflow.connections.any(
        (AgentConnection connection) => connection.joinsSameSteps(probe),
      );

      final Matcher expected = isStored ? returnsNormally : throwsStateError;
      expect(() => findConnection(workflow, probe), expected);
    }
  });

  test('test_find_connection_property_finds_what_connect_agents_added', () {
    final Random random = seededRandom(91210);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow? workflow = _randomNonEmptyWorkflow(random);
      if (workflow == null) {
        continue;
      }
      final AgentConnection proposal = randomConnectionProposal(
        random,
        workflow,
      );
      if (isConnectionRefused(workflow, proposal)) {
        continue;
      }

      final Workflow connected = connectAgents(workflow, proposal);

      expect(findConnection(connected, proposal), proposal);
    }
  });

  test('test_replace_connection_property_unknown_pairs_are_refused', () {
    final Random random = seededRandom(91211);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final WorkflowAgent stranger = buildBlankAgent(workflow);
      final AgentConnection probe = proposeConnection(
        stranger.id,
        stranger.id,
        roundLimit: null,
      );

      expect(() => replaceConnection(workflow, probe), throwsStateError);
    }
  });

  test('test_replace_connection_property_same_connection_keeps_design', () {
    final Random random = seededRandom(91212);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow? workflow = _randomConnectedWorkflow(random);
      if (workflow == null) {
        continue;
      }
      final AgentConnection stored = pickOne(random, workflow.connections);

      final Workflow replaced = replaceConnection(workflow, stored);

      expect(hasSameDesign(replaced, workflow), isTrue);
    }
  });

  test('test_has_same_design_property_is_reflexive_and_symmetric', () {
    final Random random = seededRandom(91213);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final Workflow edited = random.nextBool()
          ? _randomEdit(random, workflow)
          : workflow;
      final Workflow elsewhere = Workflow(
        id: const WorkflowId('another-workflow'),
        name: workflow.name,
        availability: OnlyWorkspaces(const <WorkspaceId>[
          WorkspaceId('another-workspace'),
        ]),
        agents: workflow.agents,
        connections: workflow.connections,
        signature: null,
      );

      expect(hasSameDesign(workflow, workflow), isTrue);
      expect(hasSameDesign(workflow, elsewhere), isTrue);
      expect(hasSameDesign(workflow, edited), hasSameDesign(edited, workflow));
    }
  });
}
