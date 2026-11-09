import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import 'manual_workflow_scene.dart';

void main() {
  testWidgets('test_manual_workflow_screen_store_workflow_property_a_retry_'
      'signs_the_created_workflow', (WidgetTester tester) async {
    final Random random = seededRandom(1221207);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PlannedRefusal refusal = PlannedRefusal();
      final ManualScene scene = await openManualScene(
        tester,
        random,
        refusal: refusal,
      );
      final int countBefore = scene.stored.listWorkflows().length;
      await nameAndFillManualWorkflow(tester, random, 'retry-$i');
      refusal.problem = PeopleFacingRefusal('Busy $i');
      await tapManualLabel(tester, signAndSaveLabel);
      await tester.pump();
      refusal.problem = null;

      await tapManualLabel(tester, signAndSaveLabel);
      await tester.pump();

      expect(scene.stored.listWorkflows().length, countBefore + 1);
      expect(findSavedWorkflow(scene, 'retry-$i')!.signature, isNotNull);
      expect(scene.navigation.routes, const <AppRoute>[manualWorkflowsRoute]);
    }
  });

  testWidgets('test_manual_workflow_screen_store_workflow_property_the_'
      'created_workflow_gets_a_real_id', (WidgetTester tester) async {
    final Random random = seededRandom(1221208);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ManualScene scene = await openManualScene(
        tester,
        random,
        refusal: null,
      );
      final Set<Object> idsBefore = <Object>{
        for (final Workflow workflow in scene.stored.listWorkflows())
          workflow.id,
      };
      await nameAndFillManualWorkflow(tester, random, 'fresh-$i');

      await tapManualLabel(tester, signAndSaveLabel);
      await tester.pump();

      final Workflow saved = findSavedWorkflow(scene, 'fresh-$i')!;
      expect(saved.id.value, isNot('unsaved'));
      expect(idsBefore.contains(saved.id), isFalse);
    }
  });

  testWidgets('test_manual_workflow_screen_store_workflow_property_keeps_'
      'the_drawn_positions', (WidgetTester tester) async {
    final Random random = seededRandom(1221209);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ManualScene scene = await openManualScene(
        tester,
        random,
        refusal: null,
      );
      await nameAndFillManualWorkflow(tester, random, 'placed-$i');
      final Workflow designed = readManualWorkflow(tester);

      await tapManualLabel(tester, signAndSaveLabel);
      await tester.pump();

      final Workflow saved = findSavedWorkflow(scene, 'placed-$i')!;
      for (final WorkflowAgent agent in designed.agents) {
        expect(saved.findAgent(agent.id).position, agent.position);
      }
    }
  });
}
