import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import 'support/random_diagram_layouts.dart';

const String _designUnconnected = 'Connect it by dragging';
const String _designNotSetUp = 'Not set up';
const String _designAdding = 'Adding…';

final DeviceNames _noDeviceNames = DeviceNames(const <Device>[]);

DiagramNode _describe(WorkflowAgent agent, Workflow workflow, NodeLook look) {
  return describeAgentNode(
    agent: agent,
    workflow: workflow,
    deviceNames: _noDeviceNames,
    look: look,
  );
}

PendingAgent _randomPending(Random random) {
  return PendingAgent(
    name: randomHostileText(random),
    position: randomCanvasPosition(random),
  );
}

void main() {
  test('test_describe_node_kind_property_agents_show_their_kind', () {
    final Random random = seededRandom(119301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgent agent = randomAgent(random, 0);
      final AgentKind? kind = agent.kind;
      final Workflow lone = randomValidWorkflow(random).withGraph(
        agents: <WorkflowAgent>[agent],
        connections: const <AgentConnection>[],
      );
      final String kindText = _describe(agent, lone, NodeLook.normal).kindText;

      expect(kindText, kind == null ? _designNotSetUp : kind.label);
    }
  });

  test('test_describe_node_kind_property_ignores_links_and_look', () {
    final Random random = seededRandom(119302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomValidWorkflow(random);
      final Workflow bare = workflow.withGraph(
        agents: workflow.agents,
        connections: const <AgentConnection>[],
      );

      for (final WorkflowAgent agent in workflow.agents) {
        final NodeLook look = pickOne(random, NodeLook.values);

        expect(
          _describe(agent, bare, look).kindText,
          _describe(agent, workflow, NodeLook.normal).kindText,
        );
      }
    }
  });

  test('test_describe_agent_node_property_keeps_the_step_identity', () {
    final Random random = seededRandom(119303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);

      for (final WorkflowAgent agent in workflow.agents) {
        final NodeLook look = pickOne(random, NodeLook.values);
        final DiagramNode node = _describe(agent, workflow, look);

        expect(node.position, same(agent.position));
        expect(node.name, agent.name);
        expect(node.stepKind, agent.stepKind);
        expect(node.look, look);
      }
    }
  });

  test('test_describe_agent_node_property_unconnected_wins_for_all', () {
    final Random random = seededRandom(119304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomValidWorkflow(random);
      final Workflow bare = workflow.withGraph(
        agents: workflow.agents,
        connections: const <AgentConnection>[],
      );

      for (final WorkflowAgent agent in bare.agents) {
        final DiagramNode node = _describe(agent, bare, NodeLook.selected);
        final bool hasCompany = bare.agents.length > 1;

        expect(node.targetText == _designUnconnected, hasCompany);
      }
    }
  });

  test('test_describe_pending_node_property_reads_adding_like_design', () {
    final Random random = seededRandom(119305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DiagramNode node = describePendingNode(_randomPending(random));

      expect(node.kindText, _designAdding);
      expect(node.stepKind, StepKind.agent);
      expect(node.look, NodeLook.pending);
      expect(node.targetText, isNull);
    }
  });

  test('test_describe_pending_node_property_keeps_name_and_position', () {
    final Random random = seededRandom(119306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PendingAgent pending = _randomPending(random);

      final DiagramNode node = describePendingNode(pending);

      expect(node.name.codeUnits, pending.name.codeUnits);
      expect(node.position, same(pending.position));
    }
  });

  test('test_diagram_node_new_property_keeps_a_missing_target', () {
    final Random random = seededRandom(119307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DiagramNode node = DiagramNode(
        position: randomCanvasPosition(random),
        kindText: randomText(random),
        name: randomText(random),
        targetText: null,
        stepKind: pickOne(random, StepKind.values),
        look: pickOne(random, NodeLook.values),
      );

      expect(node.targetText, isNull);
    }
  });

  test('test_diagram_node_new_property_fields_do_not_leak', () {
    final Random random = seededRandom(119308);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String kindText = randomHostileText(random);
      final String name = randomHostileText(random);
      final DiagramNode node = DiagramNode(
        position: randomCanvasPosition(random),
        kindText: kindText,
        name: name,
        targetText: name,
        stepKind: pickOne(random, StepKind.values),
        look: pickOne(random, NodeLook.values),
      );

      expect(node.kindText, kindText);
      expect(node.name, name);
      expect(node.targetText, name);
    }
  });
}
