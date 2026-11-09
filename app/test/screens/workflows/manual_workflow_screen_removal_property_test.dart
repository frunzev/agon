import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'manual_workflow_scene.dart';

Future<void> _removeSelectedConnection(
  WidgetTester tester,
  AgentConnection connection,
) async {
  readManualDiagram(tester).onConnectionSelected(connection);
  await tester.pump();
  tester
      .widget<ConnectionSettingsPanel>(find.byType(ConnectionSettingsPanel))
      .onRemoved();
  await tester.pump();
}

void main() {
  testWidgets('test_manual_workflow_screen_remove_connection_property_drops_'
      'exactly_that_connection', (WidgetTester tester) async {
    final Random random = seededRandom(1221107);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<WorkflowAgent> agents = await openManualSceneWithAgents(
        tester,
        random,
      );
      for (int index = 1; index < agents.length; index += 1) {
        await connectManualSteps(
          tester,
          plainConnection(agents[index - 1].id, agents[index].id),
        );
      }
      final Workflow before = readManualWorkflow(tester);
      final AgentConnection removed = pickOne(random, before.connections);

      await _removeSelectedConnection(tester, removed);

      final Workflow after = readManualWorkflow(tester);
      expect(after.connections, <AgentConnection>[
        for (final AgentConnection kept in before.connections)
          if (kept != removed) kept,
      ]);
      expect(after.agents, before.agents);
      expect(readManualDiagram(tester).selection, isNull);
    }
  });

  testWidgets('test_manual_workflow_screen_remove_connection_property_loops_'
      'that_stop_pointing_back_go_too', (WidgetTester tester) async {
    final Random random = seededRandom(1221108);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<WorkflowAgent> agents = await openManualSceneWithAgents(
        tester,
        random,
      );
      await addLoopBack(tester, agents.first, agents.last);

      await _removeSelectedConnection(
        tester,
        plainConnection(agents.first.id, agents.last.id),
      );

      final Workflow after = readManualWorkflow(tester);
      for (final AgentConnection connection in after.connections) {
        expect(!connection.isLoop || pointsBack(after, connection), isTrue);
      }
      expect(after.connections, isEmpty);
    }
  });

  testWidgets('test_manual_workflow_screen_remove_connection_property_the_'
      'panel_closes', (WidgetTester tester) async {
    final Random random = seededRandom(1221109);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<WorkflowAgent> agents = await openManualSceneWithAgents(
        tester,
        random,
      );
      final AgentConnection connection = plainConnection(
        agents.first.id,
        agents.last.id,
      );
      await connectManualSteps(tester, connection);

      await _removeSelectedConnection(tester, connection);

      expect(find.byType(ConnectionSettingsPanel), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_manual_workflow_screen_remove_agent_property_the_step_'
      'and_its_connections_go', (WidgetTester tester) async {
    final Random random = seededRandom(1221110);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<WorkflowAgent> agents = await openManualSceneWithAgents(
        tester,
        random,
      );
      for (int index = 1; index < agents.length; index += 1) {
        await connectManualSteps(
          tester,
          plainConnection(agents[index - 1].id, agents[index].id),
        );
      }
      final WorkflowAgent removed = pickOne(random, agents);
      await selectManualStep(tester, removed.id);

      tester
          .widget<AgentSettingsPanel>(find.byType(AgentSettingsPanel))
          .onRemoved();
      await tester.pump();

      final Workflow after = readManualWorkflow(tester);
      expect(after.findAgentIfPresent(removed.id), isNull);
      for (final AgentConnection connection in after.connections) {
        expect(connection.from == removed.id, isFalse);
        expect(connection.to == removed.id, isFalse);
      }
    }
  });

  testWidgets('test_manual_workflow_screen_remove_agent_property_other_steps_'
      'stay', (WidgetTester tester) async {
    final Random random = seededRandom(1221111);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<WorkflowAgent> agents = await openManualSceneWithAgents(
        tester,
        random,
      );
      final WorkflowAgent removed = pickOne(random, agents);
      await selectManualStep(tester, removed.id);

      tester
          .widget<AgentSettingsPanel>(find.byType(AgentSettingsPanel))
          .onRemoved();
      await tester.pump();

      expect(readManualWorkflow(tester).agents, <WorkflowAgent>[
        for (final WorkflowAgent agent in agents)
          if (agent.id != removed.id) agent,
      ]);
    }
  });

  testWidgets('test_manual_workflow_screen_remove_agent_property_clears_the_'
      'selection_and_count', (WidgetTester tester) async {
    final Random random = seededRandom(1221112);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<WorkflowAgent> agents = await openManualSceneWithAgents(
        tester,
        random,
      );
      await selectManualStep(tester, pickOne(random, agents).id);

      tester
          .widget<AgentSettingsPanel>(find.byType(AgentSettingsPanel))
          .onRemoved();
      await tester.pump();

      expect(readManualDiagram(tester).selection, isNull);
      expect(find.byType(AgentSettingsPanel), findsNothing);
      expect(
        find.text(describeManualSummary(agents.length - 1)),
        findsOneWidget,
      );
    }
  });
}
