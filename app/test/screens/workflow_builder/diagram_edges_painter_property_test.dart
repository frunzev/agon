import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../support/random_inputs.dart';
import '../../support/recorded_canvas_calls.dart';
import 'support/random_diagram_layouts.dart';

const Size _anyCanvasSize = Size(800, 600);
const double _boundsTolerance = 0.05;
const double _drawnReach = 2000;

final class _PaintedScene {
  const _PaintedScene({required this.edges, required this.drawnEdge});

  final List<DiagramEdge> edges;
  final EdgeCurve? drawnEdge;
}

_PaintedScene _randomScene(Random random) {
  final Workflow workflow = randomDiagramWorkflow(random);
  final AgentConnection? selected = workflow.connections.isEmpty
      ? null
      : pickOne(random, workflow.connections);
  final List<DiagramEdge> edges = describeDiagramEdges(
    agents: workflow.agents,
    connections: workflow.connections,
    selected: random.nextBool() ? selected : null,
    drawnLoop: null,
  );
  final EdgeCurve? drawnEdge = random.nextBool()
      ? null
      : randomDrawnCurve(random, reach: _drawnReach);
  return _PaintedScene(edges: edges, drawnEdge: drawnEdge);
}

RecordingCanvas _paint(List<DiagramEdge> edges, EdgeCurve? drawnEdge) {
  final RecordingCanvas canvas = RecordingCanvas();
  final DiagramEdgesPainter painter = DiagramEdgesPainter(
    edges: edges,
    drawnEdge: drawnEdge,
  );
  painter.paint(canvas, _anyCanvasSize);
  return canvas;
}

List<RecordedPath> _listFills(RecordingCanvas canvas) {
  return <RecordedPath>[
    for (final RecordedPath path in canvas.paths)
      if (path.paint.style == PaintingStyle.fill) path,
  ];
}

Rect _findArrowedRouteBounds(EdgeRoute route) {
  final Rect lineBounds = buildEdgePath(route).getBounds();
  final Rect arrowBounds = buildArrowhead(route).getBounds();
  return lineBounds.expandToInclude(arrowBounds).inflate(_boundsTolerance);
}

void main() {
  test('test_diagram_edges_painter_paint_property_one_arrow_per_edge', () {
    final Random random = seededRandom(118701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _PaintedScene scene = _randomScene(random);
      final int drawnCount = scene.drawnEdge == null ? 0 : 1;

      final RecordingCanvas canvas = _paint(scene.edges, scene.drawnEdge);

      expect(_listFills(canvas).length, scene.edges.length + drawnCount);
      expect(canvas.circles, isEmpty);
      for (final RecordedPath path in canvas.paths) {
        expect(path.bounds.isFinite, isTrue);
      }
    }
  });

  test('test_diagram_edges_painter_paint_property_selected_use_action', () {
    final Random random = seededRandom(118702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _PaintedScene scene = _randomScene(random);

      for (final DiagramEdge edge in scene.edges) {
        final Color expected = edge.look == EdgeLook.selected
            ? AppColors.action
            : AppColors.lineStrong;
        for (final RecordedPath path in _paint(<DiagramEdge>[
          edge,
        ], null).paths) {
          expect(path.paint.color.toARGB32(), expected.toARGB32());
        }
      }
      final EdgeCurve? drawnEdge = scene.drawnEdge;
      if (drawnEdge != null) {
        final RecordingCanvas drawn = _paint(const <DiagramEdge>[], drawnEdge);
        for (final RecordedPath path in drawn.paths) {
          expect(path.paint.color.toARGB32(), AppColors.action.toARGB32());
        }
      }
    }
  });

  test('test_diagram_edges_painter_paint_property_marks_stay_on_route', () {
    final Random random = seededRandom(118703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _PaintedScene scene = _randomScene(random);

      for (final DiagramEdge edge in scene.edges) {
        final Rect allowed = _findArrowedRouteBounds(edge.route);
        for (final RecordedPath path in _paint(<DiagramEdge>[
          edge,
        ], null).paths) {
          expect(allowed.expandToInclude(path.bounds), allowed);
        }
      }
    }
  });

  test('test_diagram_edges_painter_new_property_keeps_what_it_paints', () {
    final Random random = seededRandom(118704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _PaintedScene scene = _randomScene(random);

      final DiagramEdgesPainter painter = DiagramEdgesPainter(
        edges: scene.edges,
        drawnEdge: scene.drawnEdge,
      );

      expect(painter.edges, same(scene.edges));
      expect(painter.drawnEdge, same(scene.drawnEdge));
    }
  });

  test('test_diagram_edges_painter_new_property_nothing_paints_nothing', () {
    final RecordingCanvas canvas = _paint(const <DiagramEdge>[], null);

    expect(canvas.paths, isEmpty);
    expect(canvas.circles, isEmpty);
  });

  test('test_diagram_edges_painter_new_property_lone_drawn_edge_paints', () {
    final Random random = seededRandom(118705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeCurve drawnEdge = randomDrawnCurve(random, reach: _drawnReach);

      final RecordingCanvas canvas = _paint(const <DiagramEdge>[], drawnEdge);

      expect(canvas.paths.length, 2);
      expect(canvas.paths.first.paint.style, PaintingStyle.stroke);
      expect(canvas.paths.last.paint.style, PaintingStyle.fill);
    }
  });

  test('test_diagram_edges_painter_should_repaint_property_same_is_calm', () {
    final Random random = seededRandom(118706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _PaintedScene scene = _randomScene(random);
      final DiagramEdgesPainter painter = DiagramEdgesPainter(
        edges: scene.edges,
        drawnEdge: scene.drawnEdge,
      );
      final DiagramEdgesPainter twin = DiagramEdgesPainter(
        edges: scene.edges,
        drawnEdge: scene.drawnEdge,
      );

      expect(painter.shouldRepaint(painter), isFalse);
      expect(painter.shouldRepaint(twin), isFalse);
    }
  });

  test('test_diagram_edges_painter_should_repaint_property_new_edges', () {
    final Random random = seededRandom(118707);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _PaintedScene scene = _randomScene(random);
      final DiagramEdgesPainter painter = DiagramEdgesPainter(
        edges: scene.edges,
        drawnEdge: scene.drawnEdge,
      );
      final DiagramEdgesPainter rebuilt = DiagramEdgesPainter(
        edges: List<DiagramEdge>.of(scene.edges),
        drawnEdge: scene.drawnEdge,
      );

      expect(rebuilt.shouldRepaint(painter), isTrue);
      expect(painter.shouldRepaint(rebuilt), isTrue);
    }
  });

  test('test_diagram_edges_painter_should_repaint_property_new_drawing', () {
    final Random random = seededRandom(118708);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _PaintedScene scene = _randomScene(random);
      final DiagramEdgesPainter painter = DiagramEdgesPainter(
        edges: scene.edges,
        drawnEdge: scene.drawnEdge,
      );
      final DiagramEdgesPainter moved = DiagramEdgesPainter(
        edges: scene.edges,
        drawnEdge: randomDrawnCurve(random, reach: _drawnReach),
      );

      expect(moved.shouldRepaint(painter), isTrue);
      expect(painter.shouldRepaint(moved), isTrue);
    }
  });

  test('test_paint_edge_property_lines_stroke_at_the_selected_width', () {
    final Random random = seededRandom(118709);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _PaintedScene scene = _randomScene(random);
      final RecordingCanvas canvas = _paint(scene.edges, scene.drawnEdge);

      for (final RecordedPath path in canvas.paths) {
        if (path.paint.style == PaintingStyle.stroke) {
          expect(path.paint.strokeWidth, AppBorders.selected);
        }
      }
    }
  });

  test('test_paint_edge_property_solid_edges_draw_one_whole_line', () {
    final Random random = seededRandom(118710);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final DiagramEdge edge in _randomScene(random).edges) {
        if (edge.line != EdgeLine.solid) {
          continue;
        }
        final List<RecordedPath> paths = _paint(<DiagramEdge>[
          edge,
        ], null).paths;
        final Rect line = buildEdgePath(edge.route).getBounds();

        expect(paths.length, 2);
        expect(paths.first.bounds, line);
      }
    }
  });

  test('test_paint_edge_property_arrowhead_covers_the_route_end', () {
    final Random random = seededRandom(118711);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final DiagramEdge edge in _randomScene(random).edges) {
        final RecordedPath arrowhead = _listFills(
          _paint(<DiagramEdge>[edge], null),
        ).single;
        final EdgeRoute route = edge.route;
        final Offset end = switch (route) {
          EdgeCurve() => route.end,
          LoopRoute() => route.corners.last,
        };

        expect(
          arrowhead.bounds.inflate(_boundsTolerance).contains(end),
          isTrue,
        );
      }
    }
  });
}
