import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import 'support/connection_proposals.dart';

const String _loopForwardProblem = 'A loop must go back to an earlier step';
const String _backwardWithoutRoundsProblem =
    'Going back to an earlier step needs a round limit';

void main() {
  test('test_describe_direction_problem_property_a_plain_back_edge_needs_'
      'rounds', () {
    final Random random = seededRandom(52308);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      for (final AgentConnection edge in listForwardConnections(workflow)) {
        final AgentConnection backEdge = proposeConnection(
          edge.to,
          edge.from,
          roundLimit: null,
        );
        if (findConnectionProblem(workflow, backEdge) != null) {
          continue;
        }

        expect(
          () => connectAgents(workflow, backEdge),
          throwsConnectionRefusal(_backwardWithoutRoundsProblem),
        );
      }
    }
  });

  test('test_describe_direction_problem_property_a_forward_loop_is_'
      'refused', () {
    final Random random = seededRandom(52309);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      for (final AgentConnection edge in listForwardConnections(workflow)) {
        final AgentConnection forwardLoop = proposeConnection(
          edge.from,
          edge.to,
          roundLimit: 2,
        );
        final Workflow withoutEdge = workflow.withGraph(
          agents: workflow.agents,
          connections: <AgentConnection>[
            for (final AgentConnection other in workflow.connections)
              if (!other.joinsSameSteps(edge)) other,
          ],
        );
        final bool isRefusedEarlier =
            findConnectionProblem(withoutEdge, forwardLoop) != null;
        if (isRefusedEarlier || pointsBack(withoutEdge, forwardLoop)) {
          continue;
        }

        expect(
          () => connectAgents(withoutEdge, forwardLoop),
          throwsConnectionRefusal(_loopForwardProblem),
        );
      }
    }
  });

  test('test_describe_direction_problem_property_back_loops_are_taken', () {
    final Random random = seededRandom(52310);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      for (final AgentConnection edge in listForwardConnections(workflow)) {
        final AgentConnection backLoop = proposeConnection(
          edge.to,
          edge.from,
          roundLimit: 1 + random.nextInt(10),
        );
        if (findConnectionProblem(workflow, backLoop) != null) {
          continue;
        }

        expect(() => connectAgents(workflow, backLoop), returnsNormally);
      }
    }
  });
}
