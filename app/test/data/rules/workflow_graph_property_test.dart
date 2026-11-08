import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import 'support/workflow_run_planning.dart';

const List<String> _hostileNames = <String>[
  'z',
  'Z',
  'plan',
  'Ａ',
  '',
  '\u{1f600}',
  '\u{10000}',
  'é',
  'é',
  '',
];
const List<double> _crowdedCoordinates = <double>[-1, -0.0, 0, 2];

int _compareByCodePoints(String first, String second) {
  final List<int> firstRunes = first.runes.toList();
  final List<int> secondRunes = second.runes.toList();
  for (int i = 0; i < firstRunes.length && i < secondRunes.length; i += 1) {
    if (firstRunes[i] != secondRunes[i]) {
      return firstRunes[i].compareTo(secondRunes[i]);
    }
  }
  return firstRunes.length.compareTo(secondRunes.length);
}

Workflow _randomUnconnectedCrowd(Random random) {
  final Workflow base = randomAcyclicWorkflow(random);
  final List<WorkflowAgent> agents = <WorkflowAgent>[
    for (final WorkflowAgent agent in base.agents)
      agent.copyWith(
        name: pickOne(random, _hostileNames),
        position: CanvasPosition(
          horizontal: pickOne(random, _crowdedCoordinates),
          vertical: pickOne(random, _crowdedCoordinates),
        ),
      ),
  ];
  return base.withGraph(
    agents: agents,
    connections: const <AgentConnection>[],
  );
}

bool _isCanvasOrdered(WorkflowAgent earlier, WorkflowAgent later) {
  final int verticalOrder = earlier.position.vertical.compareTo(
    later.position.vertical,
  );
  if (verticalOrder != 0) {
    return verticalOrder < 0;
  }
  final int horizontalOrder = earlier.position.horizontal.compareTo(
    later.position.horizontal,
  );
  if (horizontalOrder != 0) {
    return horizontalOrder < 0;
  }
  final int nameOrder = _compareByCodePoints(earlier.name, later.name);
  if (nameOrder != 0) {
    return nameOrder < 0;
  }
  return earlier.id.value.compareTo(later.id.value) < 0;
}

void main() {
  test('test_list_forward_connections_property_keeps_only_forward_ones', () {
    final Random random = seededRandom(52101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);

      final List<AgentConnection> forward = listForwardConnections(workflow);

      final List<AgentConnection> expected = <AgentConnection>[
        for (final AgentConnection connection in workflow.connections)
          if (connection.roundLimit == null) connection,
      ];
      expect(forward, expected);
    }
  });

  test('test_list_forward_connections_property_is_idempotent', () {
    final Random random = seededRandom(52102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final List<AgentConnection> forward = listForwardConnections(workflow);
      final Workflow forwardOnly = workflow.withGraph(
        agents: workflow.agents,
        connections: forward,
      );

      expect(listForwardConnections(forwardOnly), forward);
    }
  });

  test('test_list_forward_connections_property_loops_never_count', () {
    final Random random = seededRandom(52103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final List<AgentConnection> loops = <AgentConnection>[
        for (final AgentConnection connection in workflow.connections)
          if (connection.isLoop) connection,
      ];

      final List<AgentConnection> forward = listForwardConnections(workflow);

      expect(forward.length + loops.length, workflow.connections.length);
      expect(forward.any((AgentConnection edge) => edge.isLoop), isFalse);
    }
  });

  test(
    'test_compare_canvas_order_property_neighbours_are_in_canvas_order',
    () {
      final Random random = seededRandom(52104);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Workflow workflow = _randomUnconnectedCrowd(random);

        final List<WorkflowAgent> ordered = orderAgents(workflow);

        for (int index = 1; index < ordered.length; index += 1) {
          expect(
            _isCanvasOrdered(ordered[index - 1], ordered[index]),
            isTrue,
            reason: '${ordered[index - 1].name} before ${ordered[index].name}',
          );
        }
      }
    },
  );

  test('test_compare_canvas_order_property_names_follow_code_points', () {
    final Random random = seededRandom(52105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow crowd = _randomUnconnectedCrowd(random);
      final List<WorkflowAgent> onOneSpot = <WorkflowAgent>[
        for (int index = 0; index < crowd.agents.length; index += 1)
          crowd.agents[index].copyWith(
            name: '${pickOne(random, _hostileNames)}$index',
            position: const CanvasPosition(horizontal: 5, vertical: 5),
          ),
      ];
      final Workflow workflow = crowd.withGraph(
        agents: onOneSpot,
        connections: const <AgentConnection>[],
      );

      final List<String> names = <String>[
        for (final WorkflowAgent agent in orderAgents(workflow)) agent.name,
      ];

      final List<String> expected = List<String>.of(names);
      expected.sort(_compareByCodePoints);
      expect(names, expected);
    }
  });

  test('test_compare_canvas_order_property_ignores_the_storage_order', () {
    final Random random = seededRandom(52106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomUnconnectedCrowd(random);
      final Workflow reordered = shuffleStorageOrder(random, workflow);

      expect(orderAgents(reordered), orderAgents(workflow));
    }
  });

  test('test_connection_problem_property_messages_are_sentences', () {
    for (final ConnectionProblem problem in ConnectionProblem.values) {
      final String message = problem.message;

      expect(message.trim(), message, reason: problem.name);
      expect(message, isNotEmpty, reason: problem.name);
      expect(message[0], message[0].toUpperCase(), reason: problem.name);
    }
  });

  test('test_connection_problem_property_every_problem_is_reachable', () {
    final Random random = seededRandom(52107);
    final Set<ConnectionProblem> reached = <ConnectionProblem>{};

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final bool proposesStoredPair =
          workflow.connections.isNotEmpty && random.nextBool();
      final AgentConnection connection = proposesStoredPair
          ? pickOne(random, workflow.connections)
          : AgentConnection(
              from: pickOne(random, workflow.agents).id,
              to: pickOne(random, workflow.agents).id,
              condition: null,
              roundLimit: null,
            );

      final ConnectionProblem? problem = findConnectionProblem(
        workflow,
        connection,
      );

      if (problem != null) {
        reached.add(problem);
      }
    }

    expect(reached, ConnectionProblem.values.toSet());
  });
}
