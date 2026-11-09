import 'dart:ui';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder/canvas_geometry.dart';

sealed class CanvasDrag {
  const CanvasDrag();
}

final class NodeMove extends CanvasDrag {
  const NodeMove({required this.agentId, required this.position});

  final WorkflowAgentId agentId;
  final CanvasPosition position;
}

final class ConnectionDrawing extends CanvasDrag {
  const ConnectionDrawing({required this.start, required this.pointer});

  final PortHit start;
  final Offset pointer;
}

final class CanvasPan extends CanvasDrag {
  const CanvasPan();
}

WorkflowAgentId? findDraggedAgentId(CanvasDrag? drag) {
  switch (drag) {
    case NodeMove():
      return drag.agentId;
    case ConnectionDrawing():
      return drag.start.agentId;
    case CanvasPan():
    case null:
      return null;
  }
}
