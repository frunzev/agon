import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../support/random_inputs.dart';
import '../../support/recorded_canvas_calls.dart';
import 'support/random_diagram_layouts.dart';

const Size _anyCanvasSize = Size(800, 600);
const double _designDash = AppSpacing.space2;
const double _designGap = AppSpacing.space1;
const double _boundsTolerance = 0.05;

List<DiagramEdge> _randomDashedEdges(Random random) {
  final Workflow workflow = randomDiagramWorkflow(random);
  final List<WorkflowAgent> agents = workflow.agents;
  final AgentConnection? drawnLoop = agents.length < 2
      ? null
      : AgentConnection(
          from: agents.last.id,
          to: agents.first.id,
          condition: null,
          roundLimit: null,
        );
  final List<DiagramEdge> edges = describeDiagramEdges(
    agents: agents,
    connections: workflow.connections,
    selected: null,
    drawnLoop: drawnLoop,
  );
  return <DiagramEdge>[
    for (final DiagramEdge edge in edges)
      if (edge.line == EdgeLine.dashed) edge,
  ];
}

List<RecordedPath> _paintDashesOf(DiagramEdge edge) {
  final RecordingCanvas canvas = RecordingCanvas();
  final DiagramEdgesPainter painter = DiagramEdgesPainter(
    edges: <DiagramEdge>[edge],
    drawnEdge: null,
  );
  painter.paint(canvas, _anyCanvasSize);
  return <RecordedPath>[
    for (final RecordedPath path in canvas.paths)
      if (path.paint.style == PaintingStyle.stroke) path,
  ];
}

double _measurePathLength(EdgeRoute route) {
  double length = 0;
  for (final PathMetric metric in buildEdgePath(route).computeMetrics()) {
    length += metric.length;
  }
  return length;
}

void main() {
  test('test_paint_dashes_property_dash_count_follows_the_length', () {
    final Random random = seededRandom(118801);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final DiagramEdge edge in _randomDashedEdges(random)) {
        final double length = _measurePathLength(edge.route);
        final int expectedDashes = (length / (_designDash + _designGap))
            .ceil();

        expect(_paintDashesOf(edge).length, expectedDashes);
      }
    }
  });

  test('test_paint_dashes_property_every_dash_is_short', () {
    final Random random = seededRandom(118802);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final DiagramEdge edge in _randomDashedEdges(random)) {
        for (final RecordedPath dash in _paintDashesOf(edge)) {
          final double longestSide = max(
            dash.bounds.width,
            dash.bounds.height,
          );

          expect(longestSide, lessThan(_designDash + _designGap));
        }
      }
    }
  });

  test('test_paint_dashes_property_dashes_cover_the_path_ends', () {
    final Random random = seededRandom(118803);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final DiagramEdge edge in _randomDashedEdges(random)) {
        final EdgeRoute route = edge.route;
        if (route is! LoopRoute) {
          continue;
        }
        final List<RecordedPath> dashes = _paintDashesOf(edge);
        final Rect pathBounds = buildEdgePath(route)
            .getBounds()
            .inflate(_boundsTolerance);
        final Rect firstDash = dashes.first.bounds.inflate(_boundsTolerance);

        expect(firstDash.contains(route.corners.first), isTrue);
        for (final RecordedPath dash in dashes) {
          expect(pathBounds.expandToInclude(dash.bounds), pathBounds);
        }
      }
    }
  });
}
