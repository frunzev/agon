import 'dart:math';
import 'dart:ui';

import 'package:agent_orchestration/screens/workflow_builder.dart';

const int _referenceSampleCount = 4096;

double measureReferenceDistanceToSegment(
  Offset start,
  Offset end,
  Offset point,
) {
  final Offset segment = end - start;
  final double lengthSquared = segment.distanceSquared;
  if (lengthSquared == 0) {
    return (point - start).distance;
  }

  final Offset fromStart = point - start;
  final double projection =
      (fromStart.dx * segment.dx + fromStart.dy * segment.dy) / lengthSquared;
  final double share = clampDouble(projection, 0, 1);
  final Offset nearest = start + segment * share;
  return (point - nearest).distance;
}

double measureReferenceDistanceToPoints(List<Offset> points, Offset point) {
  double nearest = double.infinity;
  for (int i = 1; i < points.length; i += 1) {
    final double distance = measureReferenceDistanceToSegment(
      points[i - 1],
      points[i],
      point,
    );
    nearest = min(nearest, distance);
  }
  return nearest;
}

List<Offset> sampleCurveDensely(EdgeCurve curve) {
  return <Offset>[
    for (int sample = 0; sample <= _referenceSampleCount; sample += 1)
      findCurvePoint(curve, sample / _referenceSampleCount),
  ];
}

double measureReferenceDistanceToRoute(EdgeRoute route, Offset point) {
  switch (route) {
    case EdgeCurve():
      return measureReferenceDistanceToPoints(
        sampleCurveDensely(route),
        point,
      );
    case LoopRoute():
      return measureReferenceDistanceToPoints(route.corners, point);
  }
}

Offset pickPointOnRoute(Random random, EdgeRoute route) {
  switch (route) {
    case EdgeCurve():
      return findCurvePoint(route, random.nextDouble());
    case LoopRoute():
      final int segmentEnd = 1 + random.nextInt(route.corners.length - 1);
      final Offset start = route.corners[segmentEnd - 1];
      final Offset end = route.corners[segmentEnd];
      return start + (end - start) * random.nextDouble();
  }
}

Rect findRouteBounds(EdgeRoute route) {
  final List<Offset> points = switch (route) {
    EdgeCurve() => <Offset>[
      route.start,
      route.controlStart,
      route.controlEnd,
      route.end,
    ],
    LoopRoute() => route.corners,
  };
  Rect bounds = Rect.fromPoints(points.first, points.first);
  for (final Offset point in points) {
    bounds = bounds.expandToInclude(Rect.fromPoints(point, point));
  }
  return bounds;
}
