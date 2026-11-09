import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder/canvas_drags.dart';
import 'package:agent_orchestration/screens/workflow_builder/canvas_geometry.dart';

import '../../support/random_inputs.dart';
import 'support/random_canvas_points.dart';

const double _reach = 5000;

NodeMove _randomNodeMove(Random random) {
  return NodeMove(
    agentId: randomHitAgentId(random),
    position: randomPlacedPosition(random, reach: _reach),
  );
}

ConnectionDrawing _randomConnectionDrawing(Random random) {
  return ConnectionDrawing(
    start: PortHit(randomHitAgentId(random), pickOne(random, PortSide.values)),
    pointer: randomCanvasPoint(random, reach: _reach),
  );
}

CanvasDrag? _randomDrag(Random random) {
  return pickOne(random, <CanvasDrag?>[
    _randomNodeMove(random),
    _randomConnectionDrawing(random),
    const CanvasPan(),
    null,
  ]);
}

void main() {
  test('test_node_move_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(1192301);
    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgentId agentId = randomHitAgentId(random);
      final CanvasPosition position = randomPlacedPosition(
        random,
        reach: _reach,
      );

      final NodeMove move = NodeMove(agentId: agentId, position: position);

      expect(move.agentId, agentId);
      expect(move.position, position);
    }
  });

  test('test_node_move_constructor_property_is_a_canvas_drag', () {
    final Random random = seededRandom(1192302);
    for (int i = 0; i < propertyIterations; i += 1) {
      expect(_randomNodeMove(random), isA<CanvasDrag>());
    }
  });

  test('test_node_move_constructor_property_names_the_dragged_step', () {
    final Random random = seededRandom(1192303);
    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeMove move = _randomNodeMove(random);
      expect(findDraggedAgentId(move), move.agentId);
    }
  });

  test('test_connection_drawing_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(1192304);
    for (int i = 0; i < propertyIterations; i += 1) {
      final PortHit start = PortHit(
        randomHitAgentId(random),
        pickOne(random, PortSide.values),
      );
      final Offset pointer = randomCanvasPoint(random, reach: _reach);

      final ConnectionDrawing drawing = ConnectionDrawing(
        start: start,
        pointer: pointer,
      );

      expect(drawing.start, same(start));
      expect(drawing.pointer, pointer);
    }
  });

  test('test_connection_drawing_constructor_property_is_a_canvas_drag', () {
    final Random random = seededRandom(1192305);
    for (int i = 0; i < propertyIterations; i += 1) {
      expect(_randomConnectionDrawing(random), isA<CanvasDrag>());
    }
  });

  test('test_connection_drawing_constructor_property_names_the_start_'
      'step', () {
    final Random random = seededRandom(1192306);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ConnectionDrawing drawing = _randomConnectionDrawing(random);
      expect(findDraggedAgentId(drawing), drawing.start.agentId);
    }
  });

  test('test_canvas_pan_constructor_property_const_pans_are_one', () {
    expect(identical(const CanvasPan(), const CanvasPan()), isTrue);
  });

  test('test_canvas_pan_constructor_property_is_a_canvas_drag', () {
    expect(const CanvasPan(), isA<CanvasDrag>());
    expect(const CanvasPan(), isNot(isA<NodeMove>()));
  });

  test('test_canvas_pan_constructor_property_names_no_step', () {
    expect(findDraggedAgentId(const CanvasPan()), isNull);
  });

  test('test_canvas_drag_constructor_property_every_drag_is_one_kind', () {
    final Random random = seededRandom(1192307);
    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasDrag? drag = _randomDrag(random);
      if (drag == null) {
        continue;
      }
      final List<bool> kinds = <bool>[
        drag is NodeMove,
        drag is ConnectionDrawing,
        drag is CanvasPan,
      ];
      expect(kinds.where((bool isKind) => isKind), hasLength(1));
    }
  });

  test('test_canvas_drag_constructor_property_kinds_stay_apart', () {
    final Random random = seededRandom(1192308);
    for (int i = 0; i < propertyIterations; i += 1) {
      expect(_randomNodeMove(random), isNot(isA<ConnectionDrawing>()));
      expect(_randomConnectionDrawing(random), isNot(isA<NodeMove>()));
    }
  });

  test('test_canvas_drag_constructor_property_drags_hold_steps_or_none', () {
    final Random random = seededRandom(1192309);
    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasDrag? drag = _randomDrag(random);
      final bool holdsStep = drag is NodeMove || drag is ConnectionDrawing;
      expect(findDraggedAgentId(drag) != null, holdsStep);
    }
  });

  test('test_find_dragged_agent_id_property_matches_the_drag_kind', () {
    final Random random = seededRandom(1192310);
    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasDrag? drag = _randomDrag(random);
      final WorkflowAgentId? expected = switch (drag) {
        NodeMove(:final WorkflowAgentId agentId) => agentId,
        ConnectionDrawing(:final PortHit start) => start.agentId,
        CanvasPan() || null => null,
      };
      expect(findDraggedAgentId(drag), expected);
    }
  });

  test('test_find_dragged_agent_id_property_ignores_where_it_is', () {
    final Random random = seededRandom(1192311);
    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeMove move = _randomNodeMove(random);
      final NodeMove elsewhere = NodeMove(
        agentId: move.agentId,
        position: randomPlacedPosition(random, reach: _reach),
      );
      expect(findDraggedAgentId(elsewhere), findDraggedAgentId(move));
    }
  });

  test('test_find_dragged_agent_id_property_no_drag_no_step', () {
    expect(findDraggedAgentId(null), isNull);
    expect(findDraggedAgentId(const CanvasPan()), isNull);
  });
}
