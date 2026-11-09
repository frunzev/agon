import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'support/edge_distance_model.dart';
import 'support/random_canvas_points.dart';
import 'support/random_diagram_layouts.dart';

const double _hugeReach = 1e9;
const double _onPathTolerance = 1e-6;
const double _controlBoxTolerance = 1;
const int _largestRoundLimit = 1 << 31;

EdgeCurve _randomCurve(Random random) {
  return EdgeCurve(
    start: randomCanvasPoint(random, reach: _hugeReach),
    controlStart: randomCanvasPoint(random, reach: _hugeReach),
    controlEnd: randomCanvasPoint(random, reach: _hugeReach),
    end: randomCanvasPoint(random, reach: _hugeReach),
  );
}

Offset _splitDeCasteljau(List<Offset> points, double progress) {
  List<Offset> level = points;
  while (level.length > 1) {
    level = <Offset>[
      for (int i = 1; i < level.length; i += 1)
        Offset.lerp(level[i - 1], level[i], progress)!,
    ];
  }
  return level.single;
}

double _measureCurveMagnitude(EdgeCurve curve) {
  return curve.start.distance +
      curve.controlStart.distance +
      curve.controlEnd.distance +
      curve.end.distance;
}

AgentConnection _randomConnection(Random random) {
  return AgentConnection(
    from: WorkflowAgentId(randomText(random)),
    to: WorkflowAgentId(randomText(random)),
    condition: random.nextBool() ? null : randomHostileText(random),
    roundLimit: random.nextBool() ? null : random.nextInt(_largestRoundLimit),
  );
}

void main() {
  test('test_find_curve_point_property_matches_de_casteljau', () {
    final Random random = seededRandom(118401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeCurve curve = _randomCurve(random);
      final double progress = random.nextDouble();
      final Offset expected = _splitDeCasteljau(<Offset>[
        curve.start,
        curve.controlStart,
        curve.controlEnd,
        curve.end,
      ], progress);

      expectNearlySamePoint(
        findCurvePoint(curve, progress),
        expected,
        magnitude: _measureCurveMagnitude(curve),
      );
    }
  });

  test('test_find_curve_point_property_stays_inside_its_control_box', () {
    final Random random = seededRandom(118402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeCurve curve = _randomCurve(random);
      final Offset point = findCurvePoint(curve, random.nextDouble());
      final Rect controlBox = findRouteBounds(curve)
          .inflate(_controlBoxTolerance);

      expect(point.isFinite, isTrue);
      expect(controlBox.contains(point), isTrue, reason: '$point');
    }
  });

  test('test_find_curve_point_property_reversed_curve_mirrors_progress', () {
    final Random random = seededRandom(118403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeCurve curve = _randomCurve(random);
      final EdgeCurve reversed = EdgeCurve(
        start: curve.end,
        controlStart: curve.controlEnd,
        controlEnd: curve.controlStart,
        end: curve.start,
      );
      final double progress = random.nextDouble();

      expectNearlySamePoint(
        findCurvePoint(reversed, 1 - progress),
        findCurvePoint(curve, progress),
        magnitude: _measureCurveMagnitude(curve),
      );
    }
  });

  test('test_find_label_centre_property_curve_label_is_halfway', () {
    final Random random = seededRandom(118404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeCurve curve = randomDrawnCurve(random, reach: farCanvasReach);
      final Offset halfway = (curve.start + curve.end) / 2;

      expectNearlySamePoint(
        findLabelCentre(curve),
        halfway,
        magnitude: _measureCurveMagnitude(curve),
      );
    }
  });

  test('test_find_label_centre_property_loop_label_sits_on_its_path', () {
    final Random random = seededRandom(118405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);

      for (final DiagramEdge edge in describeSavedEdges(workflow)) {
        final EdgeRoute route = edge.route;
        if (route is! LoopRoute) {
          continue;
        }
        final Offset centre = findLabelCentre(route);
        final Rect source = findAgentRect(workflow, edge.connection.from);
        final Rect target = findAgentRect(workflow, edge.connection.to);

        expect(
          measureReferenceDistanceToPoints(route.corners, centre),
          lessThan(_onPathTolerance),
        );
        expect(centre.dx, greaterThan(max(source.right, target.right)));
      }
    }
  });

  test('test_find_label_centre_property_moves_with_the_whole_diagram', () {
    final Random random = seededRandom(118406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);
      final Offset shift = Offset(
        random.nextInt(farCanvasReach.toInt()).toDouble(),
        random.nextInt(farCanvasReach.toInt()).toDouble(),
      );
      final Workflow shifted = workflow.withGraph(
        agents: <WorkflowAgent>[
          for (final WorkflowAgent agent in workflow.agents)
            agent.copyWith(
              position: moveCanvasPosition(agent.position, shift),
            ),
        ],
        connections: workflow.connections,
      );
      final List<DiagramEdge> edges = describeSavedEdges(workflow);
      final List<DiagramEdge> shiftedEdges = describeSavedEdges(shifted);

      for (int index = 0; index < edges.length; index += 1) {
        final Offset centre = findLabelCentre(edges[index].route);
        expectNearlySamePoint(
          findLabelCentre(shiftedEdges[index].route),
          centre + shift,
          magnitude: centre.distance + shift.distance,
        );
      }
    }
  });

  test('test_diagram_edge_new_property_keeps_every_field', () {
    final Random random = seededRandom(118407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentConnection connection = _randomConnection(random);
      final EdgeCurve route = _randomCurve(random);
      final String? label = randomOptionalHostileText(random);
      final EdgeLine line = pickOne(random, EdgeLine.values);
      final EdgeLook look = pickOne(random, EdgeLook.values);

      final DiagramEdge edge = DiagramEdge(
        connection: connection,
        route: route,
        label: label,
        line: line,
        look: look,
      );

      expect(edge.connection, same(connection));
      expect(edge.route, same(route));
      expect(edge.label, label);
      expect(edge.line, line);
      expect(edge.look, look);
    }
  });

  test('test_diagram_edge_new_property_described_edges_keep_connection', () {
    final Random random = seededRandom(118408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);
      final List<DiagramEdge> edges = describeSavedEdges(workflow);

      expect(edges.length, workflow.connections.length);
      for (int index = 0; index < edges.length; index += 1) {
        expect(edges[index].connection, same(workflow.connections[index]));
        expect(edges[index].look, EdgeLook.normal);
      }
    }
  });

  test('test_diagram_edge_new_property_label_text_is_kept_byte_for_byte', () {
    final Random random = seededRandom(118409);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String label = randomHostileText(random);
      final DiagramEdge edge = DiagramEdge(
        connection: _randomConnection(random),
        route: _randomCurve(random),
        label: label,
        line: EdgeLine.solid,
        look: EdgeLook.selected,
      );

      expect(edge.label!.codeUnits, label.codeUnits);
    }
  });
}
