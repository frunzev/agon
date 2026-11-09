import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import 'support/random_canvas_points.dart';

const double _reachShare = 0.99;
const double _beyondReach = 1.01;
const double _halfTurn = pi;

Offset _findSidePort(CanvasPosition position, PortSide side) {
  switch (side) {
    case PortSide.input:
      return findInputPort(position);
    case PortSide.output:
      return findOutputPort(position);
  }
}

Offset _randomPointInside(Random random, Rect node) {
  return Offset(
    node.left + random.nextDouble() * node.width,
    node.top + random.nextDouble() * node.height,
  );
}

bool _isNearOwnPort(CanvasPosition position, Offset point) {
  final double inputDistance = (findInputPort(position) - point).distance;
  final double outputDistance = (findOutputPort(position) - point).distance;
  return inputDistance <= CanvasMetrics.portHitRadius ||
      outputDistance <= CanvasMetrics.portHitRadius;
}

WorkflowAgent _placeHiddenPortAt(Random random, int index, Offset point) {
  final double portDepth = random.nextBool() ? CanvasMetrics.nodeHeight : 0;
  return randomAgent(random, index).copyWith(
    position: CanvasPosition(
      horizontal: point.dx - CanvasMetrics.nodeWidth / 2,
      vertical: point.dy - portDepth,
    ),
  );
}

void _expectHitIsSound(List<WorkflowAgent> agents, Offset point) {
  final CanvasHit? hit = findCanvasHit(agents, point);
  if (hit == null) {
    for (final WorkflowAgent agent in agents) {
      expect(findNodeRect(agent.position).contains(point), isFalse);
      expect(_isNearOwnPort(agent.position, point), isFalse);
    }
    return;
  }

  final WorkflowAgent agent = agents.lastWhere(
    (WorkflowAgent candidate) => candidate.id == hit.agentId,
  );
  switch (hit) {
    case PortHit(:final PortSide side):
      final double distance =
          (_findSidePort(agent.position, side) - point).distance;
      expect(distance, lessThanOrEqualTo(CanvasMetrics.portHitRadius));
    case NodeHit():
      expect(findNodeRect(agent.position).contains(point), isTrue);
  }
}

void main() {
  test('test_find_canvas_hit_property_topmost_step_body_wins', () {
    final Random random = seededRandom(117501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> lower = randomAgents(random);
      final WorkflowAgent top = randomAgent(random, lower.length);
      final Offset point = _randomPointInside(
        random,
        findNodeRect(top.position),
      );
      if (_isNearOwnPort(top.position, point)) {
        continue;
      }
      final WorkflowAgent hidden = _placeHiddenPortAt(
        random,
        lower.length + 1,
        point,
      );

      final CanvasHit? hit = findCanvasHit(<WorkflowAgent>[
        ...lower,
        hidden,
        top,
      ], point);

      expect(hit, isA<NodeHit>());
      expect(hit?.agentId, top.id);
    }
  });

  test('test_find_canvas_hit_property_every_answer_is_drawn_there', () {
    final Random random = seededRandom(117502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomAgents(random);
      final Offset point = Offset(
        random.nextDouble() * ordinaryCanvasReach / 2,
        random.nextDouble() * ordinaryCanvasReach / 2,
      );

      _expectHitIsSound(agents, point);
    }
  });

  test('test_find_canvas_hit_property_no_steps_means_no_hit', () {
    final Random random = seededRandom(117503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset point = randomCanvasPoint(random, reach: hugeCanvasReach);

      expect(findCanvasHit(const <WorkflowAgent>[], point), isNull);
    }
  });

  test('test_is_near_port_property_points_within_reach_grab_the_port', () {
    final Random random = seededRandom(117504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgent agent = randomAgent(random, 0);
      final PortSide side = pickOne(random, PortSide.values);
      final Offset nearby =
          _findSidePort(agent.position, side) +
          Offset.fromDirection(
            random.nextDouble() * 2 * _halfTurn,
            random.nextDouble() * CanvasMetrics.portHitRadius * _reachShare,
          );

      final CanvasHit? hit = findCanvasHit(<WorkflowAgent>[agent], nearby);

      expect(hit, isA<PortHit>());
      expect((hit! as PortHit).side, side);
      expect(hit.agentId, agent.id);
    }
  });

  test('test_is_near_port_property_points_out_of_reach_outside_miss', () {
    final Random random = seededRandom(117505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgent agent = randomAgent(random, 0);
      final PortSide side = pickOne(random, PortSide.values);
      final double awayFromStep = side == PortSide.input ? -_halfTurn : 0;
      final Offset faraway =
          _findSidePort(agent.position, side) +
          Offset.fromDirection(
            awayFromStep + random.nextDouble() * _halfTurn,
            CanvasMetrics.portHitRadius * _beyondReach +
                random.nextDouble() * ordinaryCanvasReach,
          );
      if (findNodeRect(agent.position).contains(faraway)) {
        continue;
      }

      expect(findCanvasHit(<WorkflowAgent>[agent], faraway), isNull);
    }
  });

  test('test_is_near_port_property_reach_is_alike_at_every_position', () {
    final Random random = seededRandom(117506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset fromPort = Offset.fromDirection(
        random.nextDouble() * 2 * _halfTurn,
        random.nextDouble() * CanvasMetrics.portHitRadius * _reachShare,
      );
      final PortSide side = pickOne(random, PortSide.values);
      final WorkflowAgent near = randomAgent(random, 0);
      final WorkflowAgent far = near.copyWith(
        position: randomPlacedPosition(random, reach: hugeCanvasReach),
      );

      final CanvasHit? nearHit = findCanvasHit(<WorkflowAgent>[
        near,
      ], _findSidePort(near.position, side) + fromPort);
      final CanvasHit? farHit = findCanvasHit(<WorkflowAgent>[
        far,
      ], _findSidePort(far.position, side) + fromPort);

      expect((nearHit! as PortHit).side, side);
      expect((farHit! as PortHit).side, side);
    }
  });

  test('test_resolve_dragged_connection_property_a_drag_is_plain', () {
    final Random random = seededRandom(117507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PortHit start = PortHit(
        randomHitAgentId(random),
        pickOne(random, PortSide.values),
      );
      final WorkflowAgentId endId = randomHitAgentId(random);
      final CanvasHit end = random.nextBool()
          ? NodeHit(endId)
          : PortHit(endId, pickOne(random, PortSide.values));

      final AgentConnection? connection = resolveDraggedConnection(
        start: start,
        end: end,
      );

      expect(connection?.condition, isNull);
      expect(connection?.roundLimit, isNull);
      expect(
        <WorkflowAgentId?>{connection?.from, connection?.to},
        <WorkflowAgentId>{start.agentId, endId},
      );
    }
  });

  test('test_resolve_dragged_connection_property_either_end_alike', () {
    final Random random = seededRandom(117508);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgentId source = randomHitAgentId(random);
      final WorkflowAgentId target = randomHitAgentId(random);

      final AgentConnection? fromSource = resolveDraggedConnection(
        start: PortHit(source, PortSide.output),
        end: NodeHit(target),
      );
      final AgentConnection? fromTarget = resolveDraggedConnection(
        start: PortHit(target, PortSide.input),
        end: PortHit(source, pickOne(random, PortSide.values)),
      );

      expect(fromTarget, fromSource);
      expect(fromSource?.from, source);
    }
  });
}
