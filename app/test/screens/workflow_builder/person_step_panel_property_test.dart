import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'support/held_builder_page.dart';
import 'support/step_panel_host.dart';

const String _questionHint =
    'The run waits here until you answer. Each outcome on an outgoing '
    'connection becomes an answer button.';
const String _doneLabel = 'Done';

Future<StepPanelHost> _pumpPersonPanel(
  WidgetTester tester,
  Random random, {
  double? width,
}) async {
  final ({Workflow workflow, WorkflowAgent step}) scene =
      randomPersonStepScene(random);
  return pumpStepHost(
    tester,
    workflow: scene.workflow,
    agent: scene.step,
    buildStep: buildShownPersonPanel,
    width: width ?? randomStepPanelWidth(random),
  );
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final Finder button = find.text(label).last;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  testWidgets('test_person_step_panel_build_property_shows_the_design_'
      'wording', (WidgetTester tester) async {
    final Random random = seededRandom(1191801);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StepPanelHost host = await _pumpPersonPanel(tester, random);

      expect(tester.takeException(), isNull);
      for (final String text in <String>[
        personStepPanelTitle,
        nameFieldLabel,
        questionLabel,
        _questionHint,
        removeStepLabel,
        _doneLabel,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(
        readFieldInputText(tester, questionLabel),
        host.shownAgent.value.task,
      );
    }
  });

  testWidgets('test_person_step_panel_build_property_question_changes_'
      'only_the_task', (WidgetTester tester) async {
    final Random random = seededRandom(1191802);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StepPanelHost host = await _pumpPersonPanel(tester, random);
      final WorkflowAgent before = host.shownAgent.value;
      final String question = randomText(random);
      if (question == before.task) {
        continue;
      }

      await typeIntoField(tester, label: questionLabel, text: question);

      expect(host.changes, <WorkflowAgent>[before.copyWith(task: question)]);
    }
  });

  testWidgets('test_person_step_panel_build_property_buttons_report_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191803);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StepPanelHost host = await _pumpPersonPanel(tester, random);

      await _tapButton(tester, removeStepLabel);
      await _tapButton(tester, _doneLabel);

      expect(host.removals.count, 1);
      expect(host.dones.count, 1);
      expect(host.changes, isEmpty);
    }
  });

  testWidgets('test_person_step_panel_did_update_widget_property_outside_'
      'question_replaces_the_text', (WidgetTester tester) async {
    final Random random = seededRandom(1191804);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StepPanelHost host = await _pumpPersonPanel(tester, random);
      final String outside = randomText(random);

      host.shownAgent.value = host.shownAgent.value.copyWith(task: outside);
      await tester.pump();

      expect(readFieldInputText(tester, questionLabel), outside);
      expect(host.changes, isEmpty);
    }
  });

  testWidgets('test_person_step_panel_did_update_widget_property_typing_'
      'never_jumps_back', (WidgetTester tester) async {
    final Random random = seededRandom(1191805);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpPersonPanel(tester, random);
      final String question = 'q ${randomText(random)}';

      for (int length = 1; length <= question.length; length += 1) {
        final String typed = question.substring(0, length);
        await typeIntoField(tester, label: questionLabel, text: typed);

        expect(readFieldInputText(tester, questionLabel), typed);
      }
    }
  });

  testWidgets('test_person_step_panel_did_update_widget_property_other_'
      'changes_keep_the_question', (WidgetTester tester) async {
    final Random random = seededRandom(1191806);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StepPanelHost host = await _pumpPersonPanel(tester, random);
      final String question = host.shownAgent.value.task;

      host.shownAgent.value = host.shownAgent.value.copyWith(
        position: CanvasPosition(
          horizontal: random.nextDouble() * 900,
          vertical: random.nextDouble() * 900,
        ),
      );
      await tester.pump();

      expect(readFieldInputText(tester, questionLabel), question);
    }
  });

  testWidgets('test_person_step_panel_dispose_property_unmounting_is_'
      'quiet', (WidgetTester tester) async {
    final Random random = seededRandom(1191807);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StepPanelHost host = await _pumpPersonPanel(tester, random);
      await typeIntoField(tester, label: questionLabel, text: 'q');
      final int changeCount = host.changes.length;

      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.takeException(), isNull);
      expect(host.changes, hasLength(changeCount));
    }
  });

  testWidgets('test_person_step_panel_dispose_property_a_new_panel_shows_'
      'its_own_question', (WidgetTester tester) async {
    final Random random = seededRandom(1191808);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomStepPanelWidth(random);
      await _pumpPersonPanel(tester, random, width: width);
      await typeIntoField(tester, label: questionLabel, text: 'old');

      final StepPanelHost fresh = await _pumpPersonPanel(
        tester,
        random,
        width: width,
      );

      expect(
        readFieldInputText(tester, questionLabel),
        fresh.shownAgent.value.task,
      );
    }
  });

  testWidgets('test_person_step_panel_dispose_property_releases_the_'
      'question_controller', (WidgetTester tester) async {
    final Random random = seededRandom(1191809);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StepPanelHost host = await _pumpPersonPanel(tester, random);
      final TextEditingController question = tester
          .widget<TextField>(findFieldInput(questionLabel))
          .controller!;

      await tester.pumpWidget(const SizedBox.shrink());

      expect(() => question.addListener(() {}), throwsFlutterError);
      expect(host.removals.count + host.dones.count, 0);
    }
  });
}
