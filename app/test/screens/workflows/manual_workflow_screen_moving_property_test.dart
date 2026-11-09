import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import 'manual_workflow_scene.dart';

void main() {
  testWidgets('test_manual_workflow_screen_move_agent_property_lands_where_'
      'dropped', (WidgetTester tester) async {
    final Random random = seededRandom(1221013);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = await openManualSceneWithSteps(tester, random);
      final WorkflowAgent chosen = pickOne(random, workflow.agents);
      final CanvasPosition target = randomCanvasPosition(random);

      readManualDiagram(tester).onAgentMoved(chosen.id, target);
      await tester.pump();

      expect(readManualWorkflow(tester).findAgent(chosen.id).position, target);
    }
  });

  testWidgets('test_manual_workflow_screen_move_agent_property_other_steps_'
      'do_not_move', (WidgetTester tester) async {
    final Random random = seededRandom(1221014);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = await openManualSceneWithSteps(tester, random);
      final WorkflowAgent chosen = pickOne(random, workflow.agents);

      readManualDiagram(tester)
          .onAgentMoved(chosen.id, randomCanvasPosition(random));
      await tester.pump();

      for (final WorkflowAgent other in workflow.agents) {
        if (other.id != chosen.id) {
          expect(
            readManualWorkflow(tester).findAgent(other.id).position,
            other.position,
          );
        }
      }
    }
  });

  testWidgets('test_manual_workflow_screen_move_agent_property_moving_back_'
      'restores_the_design', (WidgetTester tester) async {
    final Random random = seededRandom(1221015);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow before = await openManualSceneWithSteps(tester, random);
      final WorkflowAgent chosen = pickOne(random, before.agents);

      readManualDiagram(tester)
          .onAgentMoved(chosen.id, randomCanvasPosition(random));
      await tester.pump();
      readManualDiagram(tester)
          .onAgentMoved(chosen.id, copyPosition(chosen.position));
      await tester.pump();

      expect(readManualWorkflow(tester).agents, before.agents);
    }
  });
}
