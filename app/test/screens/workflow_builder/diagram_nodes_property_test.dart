import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import '../../support/unknown_device_names.dart';
import 'support/random_diagram_layouts.dart';

const String _designUnconnected = 'Connect it by dragging';
const String _designPersonKind = 'You';
const String _designPersonTarget = 'Waits for your answer';
const String _designNotSetUp = 'Not set up';
const int _agentIndexCount = 9;

final DeviceNames _noDeviceNames = DeviceNames(const <Device>[]);

bool _touches(AgentConnection connection, WorkflowAgent agent) {
  return connection.from == agent.id || connection.to == agent.id;
}

Workflow _withoutConnections(Workflow workflow) {
  return workflow.withGraph(
    agents: workflow.agents,
    connections: const <AgentConnection>[],
  );
}

DiagramNode _describe(
  WorkflowAgent agent,
  Workflow workflow,
  DeviceNames deviceNames,
) {
  return describeAgentNode(
    agent: agent,
    workflow: workflow,
    deviceNames: deviceNames,
    look: NodeLook.normal,
  );
}

void main() {
  test('test_diagram_node_new_property_keeps_every_field', () {
    final Random random = seededRandom(119201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = randomCanvasPosition(random);
      final String kindText = randomHostileText(random);
      final String name = randomHostileText(random);
      final String? targetText = randomOptionalHostileText(random);
      final StepKind stepKind = pickOne(random, StepKind.values);
      final NodeLook look = pickOne(random, NodeLook.values);

      final DiagramNode node = DiagramNode(
        position: position,
        kindText: kindText,
        name: name,
        targetText: targetText,
        stepKind: stepKind,
        look: look,
      );

      expect(node.position, same(position));
      expect(node.kindText.codeUnits, kindText.codeUnits);
      expect(node.name.codeUnits, name.codeUnits);
      expect(node.targetText, targetText);
      expect(node.stepKind, stepKind);
      expect(node.look, look);
    }
  });

  test('test_is_agent_unconnected_property_matches_the_connection_model', () {
    final Random random = seededRandom(119202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomValidWorkflow(random);

      for (final WorkflowAgent agent in workflow.agents) {
        final bool isTouched = workflow.connections.any(
          (AgentConnection connection) => _touches(connection, agent),
        );
        final bool expected = !isTouched && workflow.agents.length > 1;

        expect(isAgentUnconnected(workflow, agent.id), expected);
      }
    }
  });

  test('test_is_agent_unconnected_property_connecting_joins_both_ends', () {
    final Random random = seededRandom(119203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow bare = _withoutConnections(randomValidWorkflow(random));
      if (bare.agents.length < 2) {
        continue;
      }
      final List<WorkflowAgent> shuffled = List<WorkflowAgent>.of(bare.agents);
      shuffled.shuffle(random);
      final AgentConnection connection = AgentConnection(
        from: shuffled.first.id,
        to: shuffled.last.id,
        condition: null,
        roundLimit: null,
      );
      final Workflow joined = bare.withGraph(
        agents: bare.agents,
        connections: <AgentConnection>[connection],
      );

      for (final WorkflowAgent agent in bare.agents) {
        expect(isAgentUnconnected(bare, agent.id), isTrue);
        expect(
          isAgentUnconnected(joined, agent.id),
          !_touches(connection, agent),
        );
      }
    }
  });

  test(
    'test_is_agent_unconnected_property_a_lone_step_is_not_unconnected',
    () {
      final Random random = seededRandom(119204);

      for (int i = 0; i < propertyIterations; i += 1) {
        final WorkflowAgent agent = randomAgent(
          random,
          random.nextInt(_agentIndexCount),
        );
        final Workflow lone = randomValidWorkflow(random).withGraph(
          agents: <WorkflowAgent>[agent],
          connections: const <AgentConnection>[],
        );

        expect(isAgentUnconnected(lone, agent.id), isFalse);
        expect(
          _describe(agent, lone, _noDeviceNames).targetText,
          isNot(_designUnconnected),
        );
      }
    },
  );

  test('test_describe_node_target_property_people_wait_for_an_answer', () {
    final Random random = seededRandom(119205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomValidWorkflow(random);
      final DeviceNames deviceNames = randomKnownDeviceNames(random)
          .deviceNames;

      for (final WorkflowAgent agent in workflow.agents) {
        if (agent.stepKind != StepKind.person ||
            isAgentUnconnected(workflow, agent.id)) {
          continue;
        }
        final DiagramNode node = _describe(agent, workflow, deviceNames);

        expect(node.targetText, _designPersonTarget);
      }
    }
  });

  test('test_describe_node_target_property_agents_name_their_runner', () {
    final Random random = seededRandom(119206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final KnownDeviceNames known = randomKnownDeviceNames(random);
      final WorkflowAgent agent = randomAgent(
        random,
        0,
      ).copyWith(runsOn: SpecificRunner(known.device.id));
      final Workflow lone = randomValidWorkflow(random).withGraph(
        agents: <WorkflowAgent>[agent],
        connections: const <AgentConnection>[],
      );

      final DiagramNode node = _describe(agent, lone, known.deviceNames);

      expect(node.targetText, known.device.name);
    }
  });

  test('test_describe_node_target_property_is_never_blank', () {
    final Random random = seededRandom(119207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomValidWorkflow(random);
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);

      for (final WorkflowAgent agent in workflow.agents) {
        final DiagramNode node = _describe(
          agent,
          workflow,
          unknown.withoutDevice,
        );

        expect(node.targetText, isNotNull);
        expect(node.targetText!.trim(), isNotEmpty);
      }
    }
  });

  test('test_describe_node_kind_property_people_say_you', () {
    final Random random = seededRandom(119208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomValidWorkflow(random);

      for (final WorkflowAgent agent in workflow.agents) {
        final DiagramNode node = _describe(agent, workflow, _noDeviceNames);
        final String expected = switch (agent.stepKind) {
          StepKind.person => _designPersonKind,
          StepKind.agent => agent.kind?.label ?? _designNotSetUp,
        };

        expect(node.kindText, expected);
      }
    }
  });
}
