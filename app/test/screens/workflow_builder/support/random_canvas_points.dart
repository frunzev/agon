import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../../support/random_inputs.dart';

const double ordinaryCanvasReach = 2000;
const double hugeCanvasReach = 1e9;
const double _absoluteTolerance = 1e-6;
const double _relativeTolerance = 1e-12;
const double _middleShare = 0.5;
const double _scaleSpan = CanvasZoom.largestScale - CanvasZoom.smallestScale;

double randomSignedCoordinate(Random random, {required double reach}) {
  return (random.nextDouble() - _middleShare) * 2 * reach;
}

Offset randomCanvasPoint(Random random, {required double reach}) {
  return Offset(
    randomSignedCoordinate(random, reach: reach),
    randomSignedCoordinate(random, reach: reach),
  );
}

CanvasPosition randomPlacedPosition(Random random, {required double reach}) {
  return CanvasPosition(
    horizontal: random.nextDouble() * reach,
    vertical: random.nextDouble() * reach,
  );
}

double randomAllowedScale(Random random) {
  return CanvasZoom.smallestScale + random.nextDouble() * _scaleSpan;
}

CanvasView randomCanvasView(Random random, {required double reach}) {
  return CanvasView(
    scale: randomAllowedScale(random),
    offset: randomCanvasPoint(random, reach: reach),
  );
}

void expectNearlySamePoint(
  Offset actual,
  Offset expected, {
  required double magnitude,
}) {
  final double tolerance = _absoluteTolerance + _relativeTolerance * magnitude;
  expect(actual.dx, closeTo(expected.dx, tolerance));
  expect(actual.dy, closeTo(expected.dy, tolerance));
}

double measureViewMagnitude(CanvasView view, Offset point) {
  final double offsetSize = view.offset.dx.abs() + view.offset.dy.abs();
  final double pointSize = point.dx.abs() + point.dy.abs();
  return (offsetSize + pointSize) / view.scale;
}

WorkflowAgentId randomHitAgentId(Random random) {
  return WorkflowAgentId(randomText(random));
}
