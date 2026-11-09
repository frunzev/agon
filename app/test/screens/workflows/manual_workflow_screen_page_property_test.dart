import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'manual_workflow_scene.dart';

void main() {
  testWidgets('test_manual_workflow_screen_build_page_property_summary_'
      'counts_the_steps', (WidgetTester tester) async {
    final Random random = seededRandom(1220911);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualScene(tester, random, refusal: null);
      final int added = await addRandomSteps(tester, random);

      expect(find.text(describeManualSummary(added)), findsOneWidget);
    }
  });

  testWidgets('test_manual_workflow_screen_build_page_property_name_problem_'
      'clears_when_typing', (WidgetTester tester) async {
    final Random random = seededRandom(1220912);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualScene(tester, random, refusal: null);
      await tester.enterText(findFieldInput(workflowNameLabel), 'Bad Name');
      await tapManualLabel(tester, signAndSaveLabel);
      expect(
        find.text('Use lowercase letters, digits and dashes'),
        findsOneWidget,
      );

      await tester.enterText(findFieldInput(workflowNameLabel), 'good-$i');
      await tester.pump();

      expect(
        find.text('Use lowercase letters, digits and dashes'),
        findsNothing,
      );
    }
  });

  testWidgets('test_manual_workflow_screen_build_page_property_notice_'
      'clears_when_a_step_is_added', (WidgetTester tester) async {
    final Random random = seededRandom(1220913);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualScene(tester, random, refusal: null);
      await tapManualLabel(tester, signAndSaveLabel);
      expect(find.text('Add at least one agent'), findsOneWidget);

      await tapManualLabel(tester, addAgentLabel);

      expect(find.text('Add at least one agent'), findsNothing);
    }
  });

  testWidgets('test_manual_workflow_screen_build_canvas_property_empty_'
      'canvas_only_without_steps', (WidgetTester tester) async {
    final Random random = seededRandom(1220914);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualScene(tester, random, refusal: null);
      final bool adds = random.nextBool();
      if (adds) {
        await addRandomSteps(tester, random);
      }

      expect(find.text(emptyCanvasText), adds ? findsNothing : findsOneWidget);
      expect(
        find.byType(EditableWorkflowDiagram),
        adds ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_manual_workflow_screen_build_canvas_property_diagram_'
      'shows_every_added_step', (WidgetTester tester) async {
    final Random random = seededRandom(1220915);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualScene(tester, random, refusal: null);
      final int added = await addRandomSteps(tester, random);

      final Workflow shown = readManualWorkflow(tester);
      expect(shown.agents.length, added);
      for (final WorkflowAgent agent in shown.agents) {
        expect(find.text(agent.name), findsWidgets);
      }
    }
  });

  testWidgets('test_manual_workflow_screen_build_canvas_property_selection_'
      'follows_the_last_added_step', (WidgetTester tester) async {
    final Random random = seededRandom(1220916);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualScene(tester, random, refusal: null);
      await addRandomSteps(tester, random);

      final EditableWorkflowDiagram diagram = readManualDiagram(tester);
      final BuilderSelection? selection = diagram.selection;
      expect(selection, isA<SelectedStep>());
      expect(
        (selection! as SelectedStep).agentId,
        diagram.workflow.agents.last.id,
      );
    }
  });
}
