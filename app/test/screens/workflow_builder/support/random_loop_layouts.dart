import 'dart:math';
import 'dart:ui';

import 'package:agent_orchestration/screens/workflow_builder.dart';

const double _columnPitch = 208;
const double loopRowPitch = 152;
const double fullLoopStub = 16;
const double loopLabelClearance = 16;
const double loopRowEscape = 24;
const double _closestNudge = 0.5;
const double _farthestNudge = 17;
const double _largestLabelWidth = 200;
const double _largestLabelHeight = 28;
const double loopTolerance = 1e-9;
const int _laneRowCount = 4;

typedef LoopLayout = ({
  Rect source,
  Rect target,
  List<Rect> nodes,
  Size labelSize,
});

Rect buildStepBox(double left, double top) {
  return Rect.fromLTWH(
    left,
    top,
    CanvasMetrics.nodeWidth,
    CanvasMetrics.nodeHeight,
  );
}

Size randomLoopLabelSize(Random random) {
  return Size(
    random.nextDouble() * _largestLabelWidth,
    random.nextDouble() * _largestLabelHeight,
  );
}

LoopLayout randomCloseStepLayout(Random random) {
  final double sourceLeft = random.nextDouble() * 400;
  final double sourceTop = random.nextDouble() * 400;
  final Rect source = buildStepBox(sourceLeft, sourceTop);
  final double nudge =
      _closestNudge + random.nextDouble() * (_farthestNudge - _closestNudge);
  final double rowShift = (random.nextDouble() - 0.5) * 60;
  final Rect close = buildStepBox(source.right + nudge, sourceTop + rowShift);
  final Rect upper = buildStepBox(
    sourceLeft,
    sourceTop - loopRowPitch * (1 + random.nextInt(3)),
  );
  final Rect other = random.nextBool() ? close : upper;
  final bool startsAtSource = random.nextBool();
  final List<Rect> nodes = <Rect>[source, close, upper];
  nodes.shuffle(random);
  return (
    source: startsAtSource ? source : other,
    target: startsAtSource ? other : source,
    nodes: nodes,
    labelSize: randomLoopLabelSize(random),
  );
}

Rect _randomLaneBox(Random random, int columnCount, int row) {
  final int column = random.nextInt(columnCount);
  return buildStepBox(column * _columnPitch, row * loopRowPitch);
}

LoopLayout randomLaneLayout(Random random) {
  final int columnCount = 2 + random.nextInt(4);
  final List<Rect> nodes = <Rect>[];
  for (int row = 0; row < _laneRowCount; row += 1) {
    for (int column = 0; column < columnCount; column += 1) {
      if (random.nextBool()) {
        nodes.add(buildStepBox(column * _columnPitch, row * loopRowPitch));
      }
    }
  }
  final int sourceRow = random.nextInt(_laneRowCount);
  final int rowDistance = 1 + random.nextInt(_laneRowCount - 1);
  final int targetRow = (sourceRow + rowDistance) % _laneRowCount;
  final Rect source = _randomLaneBox(random, columnCount, sourceRow);
  final Rect target = _randomLaneBox(random, columnCount, targetRow);
  for (final Rect end in <Rect>[source, target]) {
    if (!nodes.contains(end)) {
      nodes.add(end);
    }
  }
  return (
    source: source,
    target: target,
    nodes: nodes,
    labelSize: randomLoopLabelSize(random),
  );
}

LoopRoute routeLoopLayout(LoopLayout layout) {
  return routeLoopEdge(
    source: layout.source,
    target: layout.target,
    nodes: layout.nodes,
    labelSize: layout.labelSize,
  );
}

List<Offset> findSourceLeg(LoopRoute route) {
  final double outer = route.labelArea.center.dx;
  final List<Offset> leg = <Offset>[];
  for (final Offset corner in route.corners) {
    leg.add(corner);
    if ((corner.dx - outer).abs() < loopTolerance) {
      return leg;
    }
  }
  return leg;
}

List<Offset> findTargetLeg(LoopRoute route) {
  final LoopRoute reversed = LoopRoute(
    corners: route.corners.reversed.toList(),
    labelArea: route.labelArea,
  );
  return findSourceLeg(reversed);
}

List<List<Offset>> listLoopLegs(LoopRoute route) {
  return <List<Offset>>[findSourceLeg(route), findTargetLeg(route)];
}
