import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflow_builder/canvas_drags.dart';

typedef AgentMoved = void Function(
  WorkflowAgentId agentId,
  CanvasPosition position,
);

class EditableWorkflowDiagram extends StatefulWidget {
  const EditableWorkflowDiagram({
    required this.workflow,
    required this.selection,
    required this.deviceNames,
    required this.onAgentSelected,
    required this.onConnectionSelected,
    required this.onSelectionCleared,
    required this.onAgentMoved,
    required this.onAgentsConnected,
    super.key,
  });

  final Workflow workflow;
  final BuilderSelection? selection;
  final DeviceNames deviceNames;
  final ValueChanged<WorkflowAgentId> onAgentSelected;
  final ValueChanged<AgentConnection> onConnectionSelected;
  final VoidCallback onSelectionCleared;
  final AgentMoved onAgentMoved;
  final ValueChanged<AgentConnection> onAgentsConnected;

  @override
  State<EditableWorkflowDiagram> createState() =>
      _EditableWorkflowDiagramState();
}

class _EditableWorkflowDiagramState extends State<EditableWorkflowDiagram> {
  final ValueNotifier<CanvasView> _view = ValueNotifier<CanvasView>(
    startingCanvasView,
  );
  CanvasDrag? _drag;
  MouseCursor _hoveredCursor = SystemMouseCursors.basic;

  @override
  void didUpdateWidget(EditableWorkflowDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    final WorkflowAgentId? draggedAgentId = findDraggedAgentId(_drag);
    final bool isDraggedAgentGone =
        draggedAgentId != null &&
        widget.workflow.findAgentIfPresent(draggedAgentId) == null;
    if (isDraggedAgentGone) {
      _drag = null;
    }
  }

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  AgentConnection? _findShownDrawnLoop() {
    final AgentConnection? drawnLoop = findDrawnLoop(widget.selection);
    if (drawnLoop == null) {
      return null;
    }
    final Workflow workflow = widget.workflow;
    final bool hasBothEnds =
        workflow.findAgentIfPresent(drawnLoop.from) != null &&
        workflow.findAgentIfPresent(drawnLoop.to) != null;
    return hasBothEnds ? drawnLoop : null;
  }

  List<WorkflowAgent> _placeAgents() {
    final CanvasDrag? drag = _drag;
    if (drag is! NodeMove) {
      return widget.workflow.agents;
    }

    return <WorkflowAgent>[
      for (final WorkflowAgent agent in widget.workflow.agents)
        if (agent.id == drag.agentId)
          agent.copyWith(position: drag.position)
        else
          agent,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<WorkflowAgent> agents = _placeAgents();
    final Workflow placed = widget.workflow.withGraph(
      agents: agents,
      connections: widget.workflow.connections,
    );
    final List<DiagramNode> nodes = <DiagramNode>[
      for (final WorkflowAgent agent in agents)
        describeAgentNode(
          agent: agent,
          workflow: placed,
          deviceNames: widget.deviceNames,
          look: agent.id == findSelectedStepId(widget.selection)
              ? NodeLook.selected
              : NodeLook.normal,
        ),
    ];
    final List<DiagramEdge> edges = describeDiagramEdges(
      agents: agents,
      connections: placed.connections,
      selected: findSelectedConnection(widget.selection),
      drawnLoop: _findShownDrawnLoop(),
    );

    final Rect diagramBounds = findDiagramBounds(
      positions: <CanvasPosition>[
        for (final DiagramNode node in nodes) node.position,
      ],
      edges: edges,
    );

    return MouseRegion(
      cursor: _chooseShownCursor(),
      onHover: (PointerHoverEvent event) =>
          _showCursorAt(agents, edges, event.localPosition),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        supportedDevices: canvasDragDevices,
        onTapUp: (TapUpDetails details) =>
            _selectAt(agents, edges, details.localPosition),
        onPanStart: (DragStartDetails details) =>
            _startDrag(agents, details.localPosition),
        onPanUpdate: _continueDrag,
        onPanEnd: (DragEndDetails _) => _finishDrag(agents),
        onPanCancel: () => setState(() => _drag = null),
        child: ZoomableCanvas(
          view: _view,
          diagramBounds: diagramBounds,
          child: WorkflowDiagram(
            size: measureCanvas(diagramBounds),
            nodes: nodes,
            edges: edges,
            drawnEdge: _buildDrawnEdge(),
          ),
        ),
      ),
    );
  }

  MouseCursor _chooseShownCursor() {
    if (_drag is NodeMove) {
      return SystemMouseCursors.grabbing;
    }
    return _hoveredCursor;
  }

  void _showCursorAt(
    List<WorkflowAgent> agents,
    List<DiagramEdge> edges,
    Offset viewportPoint,
  ) {
    final Offset canvasPoint = _view.value.findCanvasPoint(viewportPoint);
    final MouseCursor pointedCursor = chooseCanvasCursor(
      agentHit: findCanvasHit(agents, canvasPoint),
      edgeHit: _findSavedEdgeHit(edges, canvasPoint),
    );

    if (pointedCursor != _hoveredCursor) {
      setState(() => _hoveredCursor = pointedCursor);
    }
  }

  DiagramEdge? _findSavedEdgeHit(List<DiagramEdge> edges, Offset canvasPoint) {
    final List<DiagramEdge> savedEdges = <DiagramEdge>[
      for (final DiagramEdge edge in edges)
        if (widget.workflow.connections.contains(edge.connection)) edge,
    ];
    return findEdgeHit(savedEdges, canvasPoint);
  }

  EdgeCurve? _buildDrawnEdge() {
    final CanvasDrag? drag = _drag;
    if (drag is! ConnectionDrawing) {
      return null;
    }

    final WorkflowAgent agent = widget.workflow.findAgent(drag.start.agentId);
    switch (drag.start.side) {
      case PortSide.output:
        final Offset outputPort = findOutputPort(agent.position);
        return connectPoints(start: outputPort, end: drag.pointer);
      case PortSide.input:
        final Offset inputPort = findInputPort(agent.position);
        return connectPoints(start: drag.pointer, end: inputPort);
    }
  }

  void _selectAt(
    List<WorkflowAgent> agents,
    List<DiagramEdge> edges,
    Offset viewportPoint,
  ) {
    final Offset canvasPoint = _view.value.findCanvasPoint(viewportPoint);
    final CanvasHit? hit = findCanvasHit(agents, canvasPoint);
    if (hit != null) {
      widget.onAgentSelected(hit.agentId);
      return;
    }

    final DiagramEdge? edgeHit = _findSavedEdgeHit(edges, canvasPoint);
    if (edgeHit == null) {
      widget.onSelectionCleared();
    } else {
      widget.onConnectionSelected(edgeHit.connection);
    }
  }

  void _startDrag(List<WorkflowAgent> agents, Offset viewportPoint) {
    final Offset canvasPoint = _view.value.findCanvasPoint(viewportPoint);
    final CanvasHit? hit = findCanvasHit(agents, canvasPoint);

    setState(() {
      switch (hit) {
        case PortHit():
          _drag = ConnectionDrawing(start: hit, pointer: canvasPoint);
        case NodeHit():
          _drag = NodeMove(
            agentId: hit.agentId,
            position: widget.workflow.findAgent(hit.agentId).position,
          );
        case null:
          _drag = const CanvasPan();
      }
    });
  }

  void _continueDrag(DragUpdateDetails details) {
    final CanvasDrag? drag = _drag;
    final CanvasView view = _view.value;

    switch (drag) {
      case NodeMove():
        final Offset canvasDelta = details.delta / view.scale;
        setState(() {
          _drag = NodeMove(
            agentId: drag.agentId,
            position: moveCanvasPosition(drag.position, canvasDelta),
          );
        });
      case ConnectionDrawing():
        setState(() {
          _drag = ConnectionDrawing(
            start: drag.start,
            pointer: view.findCanvasPoint(details.localPosition),
          );
        });
      case CanvasPan():
        _view.value = panCanvasView(view: view, delta: details.delta);
      case null:
        break;
    }
  }

  void _finishDrag(List<WorkflowAgent> agents) {
    final CanvasDrag? drag = _drag;
    setState(() => _drag = null);

    switch (drag) {
      case NodeMove():
        widget.onAgentMoved(drag.agentId, drag.position);
      case ConnectionDrawing():
        final AgentConnection? connection = resolveDraggedConnection(
          start: drag.start,
          end: findCanvasHit(agents, drag.pointer),
        );
        if (connection != null) {
          widget.onAgentsConnected(connection);
        }
      case CanvasPan():
      case null:
        break;
    }
  }
}
