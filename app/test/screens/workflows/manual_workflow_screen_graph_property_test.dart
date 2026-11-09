import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'manual_workflow_scene.dart';

bool _hasForwardCycle(Workflow workflow) {
  final Map<WorkflowAgentId, int> incoming = <WorkflowAgentId, int>{
    for (final WorkflowAgent agent in workflow.agents) agent.id: 0,
  };
  final List<AgentConnection> forward = <AgentConnection>[
    for (final AgentConnection connection in workflow.connections)
      if (!connection.isLoop) connection,
  ];
  for (final AgentConnection connection in forward) {
    incoming[connection.to] = incoming[connection.to]! + 1;
  }
  final List<WorkflowAgentId> ready = <WorkflowAgentId>[
    for (final MapEntry<WorkflowAgentId, int> entry in incoming.entries)
      if (entry.value == 0) entry.key,
  ];
  int visited = 0;
  while (ready.isNotEmpty) {
    final WorkflowAgentId next = ready.removeLast();
    visited += 1;
    for (final AgentConnection connection in forward) {
      if (connection.from == next) {
        incoming[connection.to] = incoming[connection.to]! - 1;
        if (incoming[connection.to] == 0) {
          ready.add(connection.to);
        }
      }
    }
  }
  return visited != workflow.agents.length;
}

void main() {
  testWidgets('test_manual_workflow_screen_connect_agents_property_random_'
      'drawings_never_close_a_forward_cycle', (WidgetTester tester) async {
    final Random random = seededRandom(1221101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<WorkflowAgent> agents = await openManualSceneWithAgents(
        tester,
        random,
      );

      for (int drawing = 0; drawing < 6; drawing += 1) {
        await connectManualSteps(
          tester,
          plainConnection(
            pickOne(random, agents).id,
            pickOne(random, agents).id,
          ),
        );
      }

      final Workflow shown = readManualWorkflow(tester);
      expect(_hasForwardCycle(shown), isFalse);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_manual_workflow_screen_connect_agents_property_refused_'
      'drawings_say_why_and_change_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1221102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<WorkflowAgent> agents = await openManualSceneWithAgents(
        tester,
        random,
      );
      final WorkflowAgent from = agents.first;
      final bool drawsToItself = random.nextBool();
      if (!drawsToItself) {
        await connectManualSteps(
          tester,
          plainConnection(from.id, agents[1].id),
        );
      }
      final Workflow before = readManualWorkflow(tester);
      final WorkflowAgentId to = drawsToItself ? from.id : agents[1].id;

      await connectManualSteps(tester, plainConnection(from.id, to));

      final ConnectionProblem problem = drawsToItself
          ? ConnectionProblem.sameAgent
          : ConnectionProblem.alreadyConnected;
      expect(find.text(problem.message), findsOneWidget);
      expect(readManualWorkflow(tester).connections, before.connections);
    }
  });

  testWidgets('test_manual_workflow_screen_connect_agents_property_drawing_'
      'back_offers_a_loop_first', (WidgetTester tester) async {
    final Random random = seededRandom(1221103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<WorkflowAgent> agents = await openManualSceneWithAgents(
        tester,
        random,
      );
      await connectManualSteps(
        tester,
        plainConnection(agents.first.id, agents.last.id),
      );
      final Workflow before = readManualWorkflow(tester);

      await connectManualSteps(
        tester,
        plainConnection(agents.last.id, agents.first.id),
      );

      expect(readManualDiagram(tester).selection, isA<DrawnLoop>());
      expect(find.byType(NewLoopPanel), findsOneWidget);
      expect(readManualWorkflow(tester).connections, before.connections);
    }
  });

  testWidgets('test_manual_workflow_screen_add_loop_property_the_loop_joins_'
      'and_is_selected', (WidgetTester tester) async {
    final Random random = seededRandom(1221104);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<WorkflowAgent> agents = await openManualSceneWithAgents(
        tester,
        random,
      );

      final AgentConnection loop = await addLoopBack(
        tester,
        agents.first,
        agents.last,
      );

      final Workflow shown = readManualWorkflow(tester);
      expect(shown.connections.last, loop);
      final BuilderSelection? selection = readManualDiagram(tester).selection;
      expect((selection! as SelectedConnection).connection, loop);
    }
  });

  testWidgets('test_manual_workflow_screen_add_loop_property_every_kept_loop_'
      'points_back', (WidgetTester tester) async {
    final Random random = seededRandom(1221105);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<WorkflowAgent> agents = await openManualSceneWithAgents(
        tester,
        random,
      );
      await addLoopBack(tester, agents.first, agents[1]);

      final Workflow shown = readManualWorkflow(tester);
      for (final AgentConnection connection in shown.connections) {
        if (connection.isLoop) {
          expect(pointsBack(shown, connection), isTrue);
          expect(connection.roundLimit, loopRounds);
        }
      }
    }
  });

  testWidgets('test_manual_workflow_screen_add_loop_property_cancelling_'
      'adds_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1221106);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<WorkflowAgent> agents = await openManualSceneWithAgents(
        tester,
        random,
      );
      await connectManualSteps(
        tester,
        plainConnection(agents.first.id, agents.last.id),
      );
      final Workflow before = readManualWorkflow(tester);
      await connectManualSteps(
        tester,
        plainConnection(agents.last.id, agents.first.id),
      );

      tester.widget<NewLoopPanel>(find.byType(NewLoopPanel)).onCancelled();
      await tester.pump();

      expect(readManualWorkflow(tester).connections, before.connections);
      expect(readManualDiagram(tester).selection, isNull);
    }
  });
}
