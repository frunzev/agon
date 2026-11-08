import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import 'support/connection_proposals.dart';

const int _largestProposalCount = 12;

bool _hasAcyclicForwardGraph(Workflow workflow) {
  for (final AgentConnection connection in listForwardConnections(workflow)) {
    if (reachesForward(workflow, from: connection.to, to: connection.from)) {
      return false;
    }
  }
  return true;
}

Workflow? _randomNonEmptyWorkflow(Random random) {
  final Workflow workflow = randomBranchingWorkflow(random);
  if (workflow.agents.isEmpty) {
    return null;
  }
  return workflow;
}

void main() {
  test('test_reaches_forward_property_every_step_reaches_itself', () {
    final Random random = seededRandom(52301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final WorkflowAgentId stranger = WorkflowAgentId('stranger-$i');

      for (final WorkflowAgent agent in workflow.agents) {
        expect(reachesForward(workflow, from: agent.id, to: agent.id), isTrue);
      }
      expect(reachesForward(workflow, from: stranger, to: stranger), isTrue);
    }
  });

  test('test_reaches_forward_property_loops_never_count', () {
    final Random random = seededRandom(52302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow? workflow = _randomNonEmptyWorkflow(random);
      if (workflow == null) {
        continue;
      }
      final Workflow forwardOnly = workflow.withGraph(
        agents: workflow.agents,
        connections: listForwardConnections(workflow),
      );
      final WorkflowAgentId from = pickOne(random, workflow.agents).id;
      final WorkflowAgentId to = pickOne(random, workflow.agents).id;

      expect(
        reachesForward(workflow, from: from, to: to),
        reachesForward(forwardOnly, from: from, to: to),
      );
    }
  });

  test('test_reaches_forward_property_is_transitive', () {
    final Random random = seededRandom(52303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow? workflow = _randomNonEmptyWorkflow(random);
      if (workflow == null) {
        continue;
      }
      final WorkflowAgentId first = pickOne(random, workflow.agents).id;
      final WorkflowAgentId middle = pickOne(random, workflow.agents).id;
      final WorkflowAgentId last = pickOne(random, workflow.agents).id;
      final bool isChained =
          reachesForward(workflow, from: first, to: middle) &&
          reachesForward(workflow, from: middle, to: last);

      if (isChained) {
        expect(reachesForward(workflow, from: first, to: last), isTrue);
      }
    }
  });

  test('test_points_back_property_reversed_forward_edges_point_back', () {
    final Random random = seededRandom(52304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);

      for (final AgentConnection edge in listForwardConnections(workflow)) {
        final AgentConnection reversed = proposeConnection(
          edge.to,
          edge.from,
          roundLimit: random.nextBool() ? null : 3,
        );

        expect(pointsBack(workflow, reversed), isTrue);
        expect(pointsBack(workflow, edge), isFalse);
      }
    }
  });

  test('test_points_back_property_ignores_condition_and_rounds', () {
    final Random random = seededRandom(52305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow? workflow = _randomNonEmptyWorkflow(random);
      if (workflow == null) {
        continue;
      }
      final AgentConnection proposal = randomConnectionProposal(
        random,
        workflow,
      );
      final AgentConnection plain = proposeConnection(
        proposal.from,
        proposal.to,
        roundLimit: null,
      );

      expect(pointsBack(workflow, proposal), pointsBack(workflow, plain));
    }
  });

  test('test_find_connection_problem_property_reversed_pair_is_new', () {
    final Random random = seededRandom(52306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);

      for (final AgentConnection stored in workflow.connections) {
        final AgentConnection reversed = proposeConnection(
          stored.to,
          stored.from,
          roundLimit: null,
        );
        final bool isReverseStored = workflow.connections.any(
          (AgentConnection other) => other.joinsSameSteps(reversed),
        );

        final ConnectionProblem? problem = findConnectionProblem(
          workflow,
          reversed,
        );

        expect(
          problem,
          isReverseStored ? ConnectionProblem.alreadyConnected : null,
        );
      }
    }
  });

  test(
    'test_find_connection_problem_property_ignores_condition_and_rounds',
    () {
      final Random random = seededRandom(52307);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Workflow? workflow = _randomNonEmptyWorkflow(random);
        if (workflow == null) {
          continue;
        }
        final AgentConnection proposal = randomConnectionProposal(
          random,
          workflow,
        );
        final AgentConnection plain = proposeConnection(
          proposal.from,
          proposal.to,
          roundLimit: null,
        );

        expect(
          findConnectionProblem(workflow, proposal),
          findConnectionProblem(workflow, plain),
        );
      }
    },
  );

  test('test_connect_agents_property_appends_exactly_the_connection', () {
    final Random random = seededRandom(52311);

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

      expect(connected.agents, workflow.agents);
      expect(connected.connections, <AgentConnection>[
        ...workflow.connections,
        proposal,
      ]);
      expect(connected.name, workflow.name);
    }
  });

  test('test_connect_agents_property_random_edits_keep_the_graph_sound', () {
    final Random random = seededRandom(52312);

    for (int i = 0; i < propertyIterations; i += 1) {
      Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final int proposalCount = random.nextInt(_largestProposalCount);

      for (int step = 0; step < proposalCount; step += 1) {
        final AgentConnection proposal = randomConnectionProposal(
          random,
          workflow,
        );
        if (!isConnectionRefused(workflow, proposal)) {
          workflow = connectAgents(workflow, proposal);
        }

        expect(_hasAcyclicForwardGraph(workflow), isTrue);
        for (final AgentConnection connection in workflow.connections) {
          if (connection.isLoop) {
            expect(pointsBack(workflow, connection), isTrue);
          }
        }
      }
    }
  });
}
