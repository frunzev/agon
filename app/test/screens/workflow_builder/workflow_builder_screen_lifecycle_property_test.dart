import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/builder_harness.dart';
import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'support/held_builder_page.dart';

const String _plannerName = 'plan';

Future<HeldBuilderPage> _openOnPlanner(
  WidgetTester tester,
  Random random,
) async {
  final HeldBuilderPage page = HeldBuilderPage(workflowId: pipelineId);
  await tester.pumpWidget(const SizedBox.shrink());
  await page.open(tester, size: randomActionWindowSize(random));
  await selectDiagramNode(tester, _plannerName);
  return page;
}

String _randomTask(Random random) => 'task ${random.nextInt(99999)}';

Future<String> _typeTaskThenLeave(
  WidgetTester tester,
  Random random,
  HeldBuilderPage page,
) async {
  final String typed = _randomTask(random);
  await typeIntoField(tester, label: taskFieldLabel, text: typed);
  page.navigation.returnTo(workflowsSectionRoute);
  await pumpFrames(tester);
  return typed;
}

void main() {
  testWidgets('test_workflow_builder_screen_dispose_property_leaving_mid_'
      'save_still_saves', (WidgetTester tester) async {
    final Random random = seededRandom(1192401);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldBuilderPage page = await _openOnPlanner(tester, random);

      final String typed = await _typeTaskThenLeave(tester, random, page);
      await page.releaseEveryReply(tester);

      expect(find.byType(WorkflowBuilderScreen), findsNothing);
      expect(page.readSavedAgentNamed(_plannerName).task, typed);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_workflow_builder_screen_dispose_property_late_refusal_'
      'is_quiet', (WidgetTester tester) async {
    final Random random = seededRandom(1192402);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldBuilderPage page = await _openOnPlanner(tester, random);
      final String savedTask = page.readSavedAgentNamed(_plannerName).task;
      await _typeTaskThenLeave(tester, random, page);

      page.held.refuseNextReply(PeopleFacingRefusal('Refused $i'));
      await pumpFrames(tester);
      if (find.text(refusalCloseLabel).evaluate().isNotEmpty) {
        await tapButtonLabelled(tester, refusalCloseLabel);
      }

      expect(tester.takeException(), isNull);
      expect(page.readSavedAgentNamed(_plannerName).task, savedTask);
    }
  });

  testWidgets('test_workflow_builder_screen_dispose_property_reopening_'
      'shows_the_saved_edit', (WidgetTester tester) async {
    final Random random = seededRandom(1192403);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldBuilderPage page = await _openOnPlanner(tester, random);
      final String typed = await _typeTaskThenLeave(tester, random, page);
      await page.releaseEveryReply(tester);

      page.navigation.openRoute(
        const WorkflowBuilderRoute(
          pipelineId,
          opening: BuilderOpening.forEditing,
        ),
      );
      await pumpFrames(tester);
      await selectDiagramNode(tester, _plannerName);

      expect(readFieldInputText(tester, taskFieldLabel), typed);
    }
  });

  testWidgets('test_build_page_property_header_counts_unsaved_steps', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1192404);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldBuilderPage page = HeldBuilderPage(workflowId: pipelineId);
      await tester.pumpWidget(const SizedBox.shrink());
      await page.open(tester, size: randomActionWindowSize(random));
      final int stepsBefore = page.readSaved().agents.length;

      await tapButtonLabelled(tester, addAgentLabel);

      expect(page.held.heldReplyCount, 1);
      expect(find.textContaining('${stepsBefore + 1} agents'), findsWidgets);
      await page.releaseEveryReply(tester);
      expect(find.textContaining('${stepsBefore + 1} agents'), findsWidgets);
    }
  });

  testWidgets('test_build_page_property_saved_state_shows_after_the_last_'
      'reply', (WidgetTester tester) async {
    final Random random = seededRandom(1192405);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldBuilderPage page = await _openOnPlanner(tester, random);
      final String typed = _randomTask(random);
      await typeIntoField(tester, label: taskFieldLabel, text: typed);

      await page.releaseEveryReply(tester);

      final WorkflowAgent saved = page.readSavedAgentNamed(_plannerName);
      expect(saved.task, typed);
      expect(readFieldInputText(tester, taskFieldLabel), saved.task);
      expect(page.held.heldReplyCount, 0);
    }
  });
}
