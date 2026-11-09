import 'dart:ui';

import 'package:agent_orchestration/screens/workflow_builder.dart';

import 'edge_distance_model.dart';

const double _insideMargin = 1e-6;
const int _curveCheckSamples = 256;

bool doesSegmentEnterBox(Offset start, Offset end, Rect box) {
  final Rect inside = box.deflate(_insideMargin);
  final Rect segment = Rect.fromPoints(start, end);
  final bool overlapsAcross =
      segment.left < inside.right && inside.left < segment.right;
  final bool overlapsDown =
      segment.top < inside.bottom && inside.top < segment.bottom;
  return overlapsAcross && overlapsDown;
}

bool doesRouteEnterBox(EdgeRoute route, Rect box) {
  final List<Offset> points = switch (route) {
    EdgeCurve() => <Offset>[
      for (int sample = 0; sample <= _curveCheckSamples; sample += 1)
        findCurvePoint(route, sample / _curveCheckSamples),
    ],
    LoopRoute() => route.corners,
  };
  for (int i = 1; i < points.length; i += 1) {
    if (doesSegmentEnterBox(points[i - 1], points[i], box)) {
      return true;
    }
  }
  return false;
}

bool isRouteFinite(EdgeRoute route) {
  return findRouteBounds(route).isFinite;
}
