import 'dart:ui';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

Rect _includeCurveLabel(Rect bounds, EdgeRoute curve, String? label) {
  if (label == null) {
    return bounds;
  }

  final Size labelSize = measureEdgeLabel(label);
  final Rect labelArea = Rect.fromCenter(
    center: findLabelCentre(curve),
    width: labelSize.width,
    height: labelSize.height,
  );
  return bounds.expandToInclude(labelArea);
}

Rect findDiagramBounds({
  required List<CanvasPosition> positions,
  required List<DiagramEdge> edges,
}) {
  Rect bounds = findNodesBounds(positions);

  for (final DiagramEdge edge in edges) {
    final EdgeRoute route = edge.route;
    if (route is! LoopRoute) {
      bounds = _includeCurveLabel(bounds, route, edge.label);
      continue;
    }
    bounds = bounds.expandToInclude(route.labelArea);
    for (final Offset corner in route.corners) {
      bounds = bounds.expandToInclude(Rect.fromPoints(corner, corner));
    }
  }

  return bounds;
}
