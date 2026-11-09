import 'dart:math';
import 'dart:ui';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../../support/random_branching_workflows.dart';
import '../../../support/random_inputs.dart';
import 'random_canvas_points.dart';
import 'random_connection_scenes.dart';

const double layoutColumnPitch = 208;
const double layoutRowPitch = 152;
const double farCanvasReach = 1e5;
const double _overlapReach = 40;
const double _spreadReach = 4000;
const double _halfColumn = 0.5;
const int _extraColumnSlots = 3;
const int _placementCount = 5;
const String _longOutcomePrefix = 'o';

Workflow randomValidWorkflow(Random random) {
  Workflow workflow = randomBranchingWorkflow(random);
  while (describeConnectionsProblem(workflow) != null) {
    workflow = randomBranchingWorkflow(random);
  }
  return workflow;
}

String _randomLongOutcome(Random random, int index) {
  final String prefix = '$_longOutcomePrefix$index-';
  final int letterCount = random.nextInt(maximumOutcomeLength - prefix.length);
  return '$prefix${randomOutcomeOfLength(random, letterCount)}';
}

Workflow _lengthenSomeOutcomes(Random random, Workflow workflow) {
  final List<AgentConnection> connections = <AgentConnection>[];
  for (int index = 0; index < workflow.connections.length; index += 1) {
    final AgentConnection connection = workflow.connections[index];
    final bool keepsOutcome =
        connection.condition == null || random.nextBool();
    connections.add(
      keepsOutcome
          ? connection
          : connection.withCondition(_randomLongOutcome(random, index)),
    );
  }
  return workflow.withGraph(agents: workflow.agents, connections: connections);
}

Map<WorkflowAgentId, int> _assignRows(Workflow workflow) {
  final Map<WorkflowAgentId, int> rows = <WorkflowAgentId, int>{
    for (final WorkflowAgent agent in workflow.agents) agent.id: 0,
  };

  for (int pass = 0; pass < workflow.agents.length; pass += 1) {
    for (final AgentConnection connection in workflow.connections) {
      if (connection.isLoop) {
        continue;
      }
      final int rowBelowSource = rows[connection.from]! + 1;
      if (rowBelowSource > rows[connection.to]!) {
        rows[connection.to] = rowBelowSource;
      }
    }
  }
  return rows;
}

List<double> _randomRowColumns(Random random, int agentCount) {
  final double rowShift = random.nextBool() ? 0 : _halfColumn;
  final List<double> columns = <double>[
    for (int slot = 0; slot < agentCount + _extraColumnSlots; slot += 1)
      slot + rowShift,
  ];
  columns.shuffle(random);
  return columns;
}

Workflow _moveAgents(Workflow workflow, List<CanvasPosition> positions) {
  final List<WorkflowAgent> moved = <WorkflowAgent>[];
  for (int index = 0; index < workflow.agents.length; index += 1) {
    moved.add(workflow.agents[index].copyWith(position: positions[index]));
  }
  return workflow.withGraph(agents: moved, connections: workflow.connections);
}

Workflow layOutInForkLanes(Random random, Workflow workflow) {
  final Map<WorkflowAgentId, int> rows = _assignRows(workflow);
  final Map<int, List<double>> freeColumnsByRow = <int, List<double>>{};
  final List<CanvasPosition> positions = <CanvasPosition>[];

  for (final WorkflowAgent agent in workflow.agents) {
    final int row = rows[agent.id]!;
    final List<double> freeColumns = freeColumnsByRow.putIfAbsent(
      row,
      () => _randomRowColumns(random, workflow.agents.length),
    );
    positions.add(
      CanvasPosition(
        horizontal: freeColumns.removeLast() * layoutColumnPitch,
        vertical: row * layoutRowPitch,
      ),
    );
  }
  return _moveAgents(workflow, positions);
}

Workflow _scatterAgents(
  Random random,
  Workflow workflow, {
  required double reach,
}) {
  return _moveAgents(workflow, <CanvasPosition>[
    for (int index = 0; index < workflow.agents.length; index += 1)
      randomPlacedPosition(random, reach: reach),
  ]);
}

Workflow _shiftAgents(Workflow workflow, Offset shift) {
  return _moveAgents(workflow, <CanvasPosition>[
    for (final WorkflowAgent agent in workflow.agents)
      moveCanvasPosition(agent.position, shift),
  ]);
}

Workflow placeRandomly(Random random, Workflow workflow) {
  final Workflow laidOut = layOutInForkLanes(random, workflow);
  final Offset farShift = Offset(
    random.nextDouble() * farCanvasReach,
    random.nextDouble() * farCanvasReach,
  );

  switch (random.nextInt(_placementCount)) {
    case 0:
      return laidOut;
    case 1:
      return workflow;
    case 2:
      return _scatterAgents(random, workflow, reach: _overlapReach);
    case 3:
      return _scatterAgents(random, workflow, reach: _spreadReach);
    default:
      return _shiftAgents(laidOut, farShift);
  }
}

Workflow randomDiagramWorkflow(Random random) {
  final Workflow valid = randomValidWorkflow(random);
  return placeRandomly(random, _lengthenSomeOutcomes(random, valid));
}

Workflow randomLaidOutWorkflow(Random random) {
  final Workflow valid = randomValidWorkflow(random);
  return layOutInForkLanes(random, _lengthenSomeOutcomes(random, valid));
}

List<DiagramEdge> describeSavedEdges(Workflow workflow) {
  return describeDiagramEdges(
    agents: workflow.agents,
    connections: workflow.connections,
    selected: null,
    drawnLoop: null,
  );
}

Rect findAgentRect(Workflow workflow, WorkflowAgentId agentId) {
  return findNodeRect(workflow.findAgent(agentId).position);
}

EdgeCurve randomDrawnCurve(Random random, {required double reach}) {
  final Offset port = randomCanvasPoint(random, reach: reach);
  final Offset pointer = randomCanvasPoint(random, reach: reach);
  final Offset levelPointer = Offset(pointer.dx, port.dy);
  final Offset drawnEnd = pickOne(random, <Offset>[
    pointer,
    levelPointer,
    port,
  ]);
  return connectPoints(start: port, end: drawnEnd);
}
