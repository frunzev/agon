import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'workflow_drafting_flow_scene.dart';
import 'workflow_drafting_scene.dart';

ReadOnlyWorkflowDiagram _readDiagram(WidgetTester tester) {
  return tester.widget<ReadOnlyWorkflowDiagram>(
    find.byType(ReadOnlyWorkflowDiagram),
  );
}

void main() {
  testWidgets('test_workflow_drafting_screen_constructor_property_two_'
      'screens_draft_their_own_drafts', (WidgetTester tester) async {
    final Random random = seededRandom(1220701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftingFlowScene first = await openDraftingFlow(tester, random);
      final DraftingFlowScene second = await openDraftingFlow(tester, random);
      await tester.pumpWidget(const SizedBox.shrink());

      expect(first.workflows.stoppedDrafts, <WorkflowDraft>[first.draft]);
      expect(second.workflows.stoppedDrafts, <WorkflowDraft>[second.draft]);
    }
  });

  testWidgets('test_workflow_drafting_screen_build_property_never_'
      'overflows', (WidgetTester tester) async {
    final Random random = seededRandom(1220702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftingFlowScene scene = await openDraftingFlow(tester, random);
      await addRandomDraftProgress(tester, random, scene);
      if (random.nextBool()) {
        scene.workflows.progress.addError(
          PeopleFacingRefusal(randomText(random)),
        );
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_workflow_drafting_screen_build_property_matches_the_'
      'design_wording', (WidgetTester tester) async {
    final Random random = seededRandom(1220703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftingFlowScene scene = await openDraftingFlow(tester, random);
      final WorkflowDraftProgress running = buildWorkflowDraftProgress(
        random,
        pending: 1 + random.nextInt(3),
      );
      scene.workflows.progress.add(running);
      await tester.pump();

      expect(find.text(newWorkflowTitle), findsOneWidget);
      expect(find.text('Drafting from your description'), findsOneWidget);
      expect(find.text(stopDraftingLabel), findsOneWidget);
      expect(
        find.text('Claude Code is drafting on mac-studio'),
        findsOneWidget,
      );
      expect(find.text('Draft progress'), findsOneWidget);
    }
  });

  testWidgets('test_workflow_drafting_screen_build_property_a_failure_leads_'
      'back_to_the_description', (WidgetTester tester) async {
    final Random random = seededRandom(1220704);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftingFlowScene scene = await openDraftingFlow(tester, random);
      await addRandomDraftProgress(tester, random, scene);
      scene.workflows.progress.addError(PeopleFacingRefusal('Failed $i'));
      await tester.pump();

      expect(find.text(draftFailedTitle), findsOneWidget);
      expect(find.text(stopDraftingLabel), findsNothing);
      await tapVisible(tester, find.text(backToDescriptionLabel));
      await tester.pump();

      expect(scene.navigation.routes, const <AppRoute>[
        flowWorkflowsRoute,
        NewWorkflowRoute(),
      ]);
      expect(scene.workflows.stoppedDrafts, isEmpty);
    }
  });

  testWidgets('test_workflow_drafting_screen_build_diagram_property_empty_'
      'before_progress', (WidgetTester tester) async {
    final Random random = seededRandom(1220705);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openDraftingFlow(tester, random);

      final ReadOnlyWorkflowDiagram diagram = _readDiagram(tester);
      expect(diagram.nodes, isEmpty);
      expect(diagram.edges, isEmpty);
    }
  });

  testWidgets('test_workflow_drafting_screen_build_diagram_property_agents_'
      'then_pending_steps', (WidgetTester tester) async {
    final Random random = seededRandom(1220706);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftingFlowScene scene = await openDraftingFlow(tester, random);
      final WorkflowDraftProgress running = buildWorkflowDraftProgress(
        random,
        pending: 1 + random.nextInt(4),
      );
      scene.workflows.progress.add(running);
      await tester.pump();

      final ReadOnlyWorkflowDiagram diagram = _readDiagram(tester);
      final List<String> expectedNames = <String>[
        for (final WorkflowAgent agent in running.workflow.agents) agent.name,
        for (final PendingAgent pending in running.pendingAgents) pending.name,
      ];
      expect(<String>[
        for (final DiagramNode node in diagram.nodes) node.name,
      ], expectedNames);
      final int agentCount = running.workflow.agents.length;
      for (int index = 0; index < diagram.nodes.length; index += 1) {
        final NodeLook expectedLook = index < agentCount
            ? NodeLook.normal
            : NodeLook.pending;
        expect(diagram.nodes[index].look, expectedLook);
      }
    }
  });

  testWidgets('test_workflow_drafting_screen_build_diagram_property_one_'
      'edge_per_connection_of_the_latest_progress', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1220707);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftingFlowScene scene = await openDraftingFlow(tester, random);
      WorkflowDraftProgress? latest;
      for (int step = 0; step < 1 + random.nextInt(3); step += 1) {
        latest = buildWorkflowDraftProgress(
          random,
          pending: 1 + random.nextInt(3),
        );
        scene.workflows.progress.add(latest);
        await tester.pump();
      }

      final ReadOnlyWorkflowDiagram diagram = _readDiagram(tester);
      expect(diagram.edges.length, latest!.workflow.connections.length);
      expect(
        diagram.nodes.length,
        latest.workflow.agents.length + latest.pendingAgents.length,
      );
    }
  });
}
