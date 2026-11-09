import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/app_harness.dart';
import '../../support/builder_harness.dart';
import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'support/held_builder_page.dart';

const String _plannerName = 'plan';
const String _questionLabel = 'Question';
const int _mostTypedLetters = 12;
const String _typedLetters = 'abcdefghij klmnopqrstuvwxyz0123456789';

String _randomTask(Random random) {
  final StringBuffer task = StringBuffer('task ');
  final int letterCount = 1 + random.nextInt(_mostTypedLetters);
  for (int i = 0; i < letterCount; i += 1) {
    task.write(_typedLetters[random.nextInt(_typedLetters.length)]);
  }
  return task.toString();
}

AgentKind _pickOtherKind(Random random, AgentKind? current) {
  final List<AgentKind> others = <AgentKind>[
    for (final AgentKind kind in AgentKind.values)
      if (kind != current) kind,
  ];
  return pickOne(random, others);
}

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

void main() {
  testWidgets('test_save_edit_property_agent_choice_survives_a_quick_'
      'task', (WidgetTester tester) async {
    final Random random = seededRandom(1190801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldBuilderPage page = await _openOnPlanner(tester, random);
      final WorkflowAgent planner = page.readSavedAgentNamed(_plannerName);
      final AgentKind chosenKind = _pickOtherKind(random, planner.kind);
      final String typedTask = _randomTask(random);

      chooseSelectValue(tester, AgentKindChoice(chosenKind));
      await tester.pump();
      await typeIntoField(tester, label: taskFieldLabel, text: typedTask);
      await page.releaseEveryReply(tester);

      final WorkflowAgent saved = page.readSavedAgentNamed(_plannerName);
      expect(saved.kind, chosenKind);
      expect(saved.task, typedTask);
      expect(page.held.mostSavesInFlight, 1);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_save_edit_property_task_field_never_jumps_back', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1190802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldBuilderPage page = await _openOnPlanner(tester, random);
      final String finalTask = _randomTask(random);

      for (int length = 1; length <= finalTask.length; length += 1) {
        final String typed = finalTask.substring(0, length);
        await typeIntoField(tester, label: taskFieldLabel, text: typed);
        if (page.held.heldReplyCount > 1 && random.nextBool()) {
          await page.releaseOneReply(tester);
        }

        expect(readFieldInputText(tester, taskFieldLabel), typed);
      }
      await page.releaseEveryReply(tester);

      expect(readFieldInputText(tester, taskFieldLabel), finalTask);
      expect(page.readSavedAgentNamed(_plannerName).task, finalTask);
    }
  });

  testWidgets('test_save_edit_property_moved_step_keeps_panel_edits', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1190803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldBuilderPage page = await _openOnPlanner(tester, random);
      final WorkflowAgent planner = page.readSavedAgentNamed(_plannerName);
      final Offset dragShift = Offset(
        20 + random.nextDouble() * 40,
        10 + random.nextDouble() * 20,
      );
      final String typedTask = _randomTask(random);

      await tester.dragFrom(
        tester.getCenter(findDiagramNode(_plannerName)),
        dragShift,
      );
      await tester.pump();
      await typeIntoField(tester, label: taskFieldLabel, text: typedTask);
      await page.releaseEveryReply(tester);

      final WorkflowAgent saved = page.readSaved().findAgent(planner.id);
      final CanvasPosition dropped = page.held.sentWorkflows.first
          .findAgent(planner.id)
          .position;
      expect(dropped, isNot(planner.position));
      expect(saved.position, dropped);
      expect(saved.task, typedTask);
    }
  });

  testWidgets('test_save_edit_property_person_step_name_and_question_'
      'both_land', (WidgetTester tester) async {
    final Random random = seededRandom(1190804);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldBuilderPage page = HeldBuilderPage(workflowId: pipelineId);
      await tester.pumpWidget(const SizedBox.shrink());
      await page.open(tester, size: randomActionWindowSize(random));
      await tapButtonLabelled(tester, addPersonStepLabel);
      await page.releaseEveryReply(tester);
      final WorkflowAgent added = page.readSaved().agents.last;
      final String name = 'asker-${random.nextInt(999)}';
      final String question = _randomTask(random);

      await typeIntoField(tester, label: nameFieldLabel, text: name);
      await typeIntoField(tester, label: _questionLabel, text: question);
      await page.releaseEveryReply(tester);

      final WorkflowAgent saved = page.readSaved().findAgent(added.id);
      expect(saved.name, name);
      expect(saved.task, question);
    }
  });

  testWidgets('test_save_edit_property_refused_save_shows_the_saved_'
      'task', (WidgetTester tester) async {
    final Random random = seededRandom(1190805);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldBuilderPage page = await _openOnPlanner(tester, random);
      final String savedTask = page.readSavedAgentNamed(_plannerName).task;
      final String refusal = 'Refused ${randomWordPhrase(random)}'.trim();

      await typeIntoField(
        tester,
        label: taskFieldLabel,
        text: _randomTask(random),
      );
      page.held.refuseNextReply(PeopleFacingRefusal(refusal));
      await tester.pump();
      await tester.pump();
      await tapButtonLabelled(tester, refusalCloseLabel);

      expect(find.text(refusal), findsNothing);
      expect(readFieldInputText(tester, taskFieldLabel), savedTask);
      expect(page.readSavedAgentNamed(_plannerName).task, savedTask);
    }
  });

  testWidgets('test_add_step_property_quick_steps_all_stay', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1190806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldBuilderPage page = HeldBuilderPage(workflowId: pipelineId);
      await tester.pumpWidget(const SizedBox.shrink());
      await page.open(tester, size: randomActionWindowSize(random));
      final int stepsBefore = page.readSaved().agents.length;
      final int addedCount = 2 + random.nextInt(3);

      for (int step = 0; step < addedCount; step += 1) {
        await tapButtonLabelled(tester, addAgentLabel);
      }
      await page.releaseEveryReply(tester);

      final Set<WorkflowAgentId> ids = <WorkflowAgentId>{
        for (final WorkflowAgent agent in page.readSaved().agents) agent.id,
      };
      expect(ids, hasLength(stepsBefore + addedCount));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_add_step_property_unsaved_step_opens_its_'
      'panel', (WidgetTester tester) async {
    final Random random = seededRandom(1190807);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldBuilderPage page = HeldBuilderPage(workflowId: pipelineId);
      await tester.pumpWidget(const SizedBox.shrink());
      await page.open(tester, size: randomActionWindowSize(random));
      final bool addsPerson = random.nextBool();

      await tapButtonLabelled(
        tester,
        addsPerson ? addPersonStepLabel : addAgentLabel,
      );

      expect(page.held.heldReplyCount, 1);
      expect(
        find.byType(PersonStepPanel),
        addsPerson ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(AgentSettingsPanel),
        addsPerson ? findsNothing : findsOneWidget,
      );
      await page.releaseEveryReply(tester);
    }
  });

  testWidgets('test_build_page_property_unsaved_choice_is_on_the_'
      'diagram', (WidgetTester tester) async {
    final Random random = seededRandom(1190808);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldBuilderPage page = await _openOnPlanner(tester, random);
      final WorkflowAgent planner = page.readSavedAgentNamed(_plannerName);
      final AgentKind chosenKind = _pickOtherKind(random, planner.kind);

      chooseSelectValue(tester, AgentKindChoice(chosenKind));
      await pumpFrames(tester);

      expect(page.held.heldReplyCount, 1);
      expect(
        find.descendant(
          of: findDiagramNode(_plannerName),
          matching: find.text(chosenKind.label),
        ),
        findsOneWidget,
      );
      await page.releaseEveryReply(tester);
    }
  });
}
