import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/random_canvas_points.dart';

const Size _screenSize = Size(widestWidth, widestWidth);
const double _smallestViewportSide = 240;
const double _largestViewportSide = 1200;
const int _largestMoveCount = 8;
const double _largestPan = 3000;
const double _tolerance = 1e-6;
const double _pointMagnitude = _largestPan * _largestMoveCount * 8;

final class _ShownCanvas {
  const _ShownCanvas({
    required this.view,
    required this.viewport,
    required this.diagramBounds,
    required this.positions,
  });

  final ValueNotifier<CanvasView> view;
  final Size viewport;
  final Rect diagramBounds;
  final List<CanvasPosition> positions;

  Offset get middle => viewport.center(Offset.zero);
}

Future<_ShownCanvas> _pumpRandomCanvas(
  WidgetTester tester,
  Random random,
) async {
  final Workflow workflow = randomBranchingWorkflow(random);
  final List<CanvasPosition> positions = <CanvasPosition>[
    for (final WorkflowAgent agent in workflow.agents) agent.position,
  ];
  final Rect diagramBounds = findDiagramBounds(
    positions: positions,
    edges: describeDiagramEdges(
      agents: workflow.agents,
      connections: workflow.connections,
      selected: null,
      drawnLoop: null,
    ),
  );
  final Size viewport = Size(
    randomWidth(
      random,
      least: _smallestViewportSide,
      most: _largestViewportSide,
    ),
    randomWidth(
      random,
      least: _smallestViewportSide,
      most: _largestViewportSide,
    ),
  );
  final ValueNotifier<CanvasView> view = ValueNotifier<CanvasView>(
    startingCanvasView,
  );
  addTearDown(view.dispose);

  useViewSize(tester, _screenSize);
  await tester.pumpWidget(
    wrapInApp(
      Center(
        child: SizedBox.fromSize(
          size: viewport,
          child: ZoomableCanvas(
            view: view,
            diagramBounds: diagramBounds,
            child: SizedBox.fromSize(size: measureCanvas(diagramBounds)),
          ),
        ),
      ),
      platform: desktopPlatform,
    ),
  );
  return _ShownCanvas(
    view: view,
    viewport: viewport,
    diagramBounds: diagramBounds,
    positions: positions,
  );
}

Future<void> _tapLabel(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

Future<void> _zoomOrPanRandomly(
  WidgetTester tester,
  Random random,
  _ShownCanvas canvas,
) async {
  final int moveCount = random.nextInt(_largestMoveCount);
  for (int move = 0; move < moveCount; move += 1) {
    final int choice = random.nextInt(3);
    if (choice == 0) {
      await _tapLabel(tester, zoomInLabel);
    } else if (choice == 1) {
      await _tapLabel(tester, zoomOutLabel);
    } else {
      canvas.view.value = panCanvasView(
        view: canvas.view.value,
        delta: randomCanvasPoint(random, reach: _largestPan),
      );
      await tester.pump();
    }
  }
}

void _expectSameView(CanvasView actual, CanvasView expected) {
  expect(actual.scale, closeTo(expected.scale, _tolerance));
  expectNearlySamePoint(
    actual.offset,
    expected.offset,
    magnitude: _pointMagnitude,
  );
}

void main() {
  testWidgets(
    'test_canvas_zoom_buttons_build_property_zoom_keeps_the_middle',
    (WidgetTester tester) async {
      final Random random = seededRandom(117801);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _ShownCanvas canvas = await _pumpRandomCanvas(tester, random);
        final int tapCount = 1 + random.nextInt(_largestMoveCount);

        for (int tap = 0; tap < tapCount; tap += 1) {
          final bool zoomsIn = random.nextBool();
          final CanvasView before = canvas.view.value;
          final Offset canvasMiddle = before.findCanvasPoint(canvas.middle);
          final double step = zoomsIn
              ? CanvasZoom.buttonStep
              : -CanvasZoom.buttonStep;

          await _tapLabel(tester, zoomsIn ? zoomInLabel : zoomOutLabel);

          final CanvasView after = canvas.view.value;
          final double expectedScale = clampDouble(
            before.scale + step,
            CanvasZoom.smallestScale,
            CanvasZoom.largestScale,
          );
          expect(after.scale, closeTo(expectedScale, _tolerance));
          expectNearlySamePoint(
            after.findViewportPoint(canvasMiddle),
            canvas.middle,
            magnitude: _pointMagnitude,
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('test_canvas_zoom_buttons_build_property_fit_brings_all_back', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(117802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ShownCanvas canvas = await _pumpRandomCanvas(tester, random);
      await _zoomOrPanRandomly(tester, random, canvas);

      await _tapLabel(tester, fitLabel);

      final CanvasView fitted = canvas.view.value;
      _expectSameView(
        fitted,
        fitCanvasView(
          diagramBounds: canvas.diagramBounds,
          viewport: canvas.viewport,
        ),
      );
      final Rect withMargin = canvas.diagramBounds.inflate(
        CanvasZoom.fitMargin,
      );
      final bool isRoomy =
          canvas.viewport.width / withMargin.width >=
              CanvasZoom.smallestScale &&
          canvas.viewport.height / withMargin.height >=
              CanvasZoom.smallestScale;
      if (!isRoomy) {
        continue;
      }
      final Rect visible = (Offset.zero & canvas.viewport).inflate(_tolerance);
      for (final CanvasPosition position in canvas.positions) {
        final Rect node = findNodeRect(position);
        expect(
          visible.contains(fitted.findViewportPoint(node.topLeft)),
          isTrue,
        );
        expect(
          visible.contains(fitted.findViewportPoint(node.bottomRight)),
          isTrue,
        );
      }
    }
  });

  testWidgets('test_canvas_zoom_buttons_build_property_in_then_out_restores', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(117803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ShownCanvas canvas = await _pumpRandomCanvas(tester, random);
      await _tapLabel(tester, fitLabel);
      final CanvasView fitted = canvas.view.value;

      await _tapLabel(tester, zoomInLabel);
      await _tapLabel(tester, zoomOutLabel);

      _expectSameView(canvas.view.value, fitted);
    }
  });
}
