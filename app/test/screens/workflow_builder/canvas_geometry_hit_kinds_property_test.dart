import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/random_canvas_points.dart';

void main() {
  test('test_canvas_hit_constructor_property_keeps_the_agent', () {
    final Random random = seededRandom(117509);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgentId agentId = randomHitAgentId(random);

      final List<CanvasHit> hits = <CanvasHit>[
        NodeHit(agentId),
        PortHit(agentId, pickOne(random, PortSide.values)),
      ];

      for (final CanvasHit hit in hits) {
        expect(hit.agentId, agentId);
      }
    }
  });

  test('test_canvas_hit_constructor_property_kinds_never_mix', () {
    final Random random = seededRandom(117510);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasHit node = NodeHit(randomHitAgentId(random));
      final CanvasHit port = PortHit(randomHitAgentId(random), PortSide.input);

      expect(node is PortHit, isFalse);
      expect(port is NodeHit, isFalse);
    }
  });

  test('test_canvas_hit_constructor_property_const_hits_are_shared', () {
    const CanvasHit first = NodeHit(WorkflowAgentId('plan'));
    const CanvasHit second = NodeHit(WorkflowAgentId('plan'));

    expect(identical(first, second), isTrue);
  });

  test('test_port_hit_constructor_property_keeps_agent_and_side', () {
    final Random random = seededRandom(117511);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgentId agentId = randomHitAgentId(random);
      final PortSide side = pickOne(random, PortSide.values);

      final PortHit hit = PortHit(agentId, side);

      expect(hit.agentId, agentId);
      expect(hit.side, side);
    }
  });

  test('test_port_hit_constructor_property_every_side_is_kept', () {
    final Random random = seededRandom(117512);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgentId agentId = randomHitAgentId(random);

      final List<PortSide> kept = <PortSide>[
        for (final PortSide side in PortSide.values)
          PortHit(agentId, side).side,
      ];

      expect(kept, PortSide.values);
    }
  });

  test('test_port_hit_constructor_property_const_hits_are_shared', () {
    const PortHit first = PortHit(WorkflowAgentId('plan'), PortSide.output);
    const PortHit second = PortHit(WorkflowAgentId('plan'), PortSide.output);
    const PortHit other = PortHit(WorkflowAgentId('plan'), PortSide.input);

    expect(identical(first, second), isTrue);
    expect(identical(first, other), isFalse);
  });

  test('test_node_hit_constructor_property_keeps_the_agent', () {
    final Random random = seededRandom(117513);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgentId agentId = randomHitAgentId(random);

      expect(NodeHit(agentId).agentId, agentId);
    }
  });

  test('test_node_hit_constructor_property_is_a_canvas_hit_not_a_port', () {
    final Random random = seededRandom(117514);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasHit hit = NodeHit(randomHitAgentId(random));

      expect(hit, isA<NodeHit>());
      expect(hit, isNot(isA<PortHit>()));
    }
  });

  test('test_node_hit_constructor_property_const_hits_are_shared', () {
    const NodeHit first = NodeHit(WorkflowAgentId('ship'));
    const NodeHit second = NodeHit(WorkflowAgentId('ship'));
    const NodeHit other = NodeHit(WorkflowAgentId('plan'));

    expect(identical(first, second), isTrue);
    expect(identical(first, other), isFalse);
  });
}
