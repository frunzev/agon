import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'agent_settings_panel_scene.dart';

const List<String> _designLabels = <String>[
  agentSettingsTitle,
  'Name',
  'Agent',
  taskFieldLabel,
  'Runs on',
  skillsFieldLabel,
  automaticSkillsLabel,
  'Commands and pushes',
  removeAgentLabel,
];

String _readTaskText(WidgetTester tester) {
  final TextField field = tester.widget(findFieldInput(taskFieldLabel));
  return field.controller!.text;
}

void main() {
  testWidgets('test_agent_settings_panel_build_property_design_fields_fit', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162201);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpAgentSettings(
        tester,
        random: random,
        agent: randomSettingsAgent(random),
        canFillIn: random.nextBool(),
      );

      expect(tester.takeException(), isNull, reason: 'round $i');
      for (final String label in _designLabels) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    }
  });

  testWidgets(
    'test_agent_settings_panel_build_property_fill_in_only_offered',
    (WidgetTester tester) async {
      final Random random = seededRandom(1162202);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final bool canFillIn = random.nextBool();
        final AgentSettingsScene scene = await pumpAgentSettings(
          tester,
          random: random,
          agent: randomSettingsAgent(random),
          canFillIn: canFillIn,
        );
        final Finder fillIn = find.widgetWithText(
          AppButton,
          fillInWithAgentLabel,
        );

        expect(fillIn, canFillIn ? findsOneWidget : findsNothing);
        if (canFillIn) {
          await tapVisible(tester, fillIn);
          await tester.pump();
        }
        expect(scene.fillIns.count, canFillIn ? 1 : 0);
        expect(scene.changes, isEmpty);
      }
    },
  );

  testWidgets('test_agent_settings_panel_build_property_buttons_act_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162203);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentSettingsScene scene = await pumpAgentSettings(
        tester,
        random: random,
        agent: randomSettingsAgent(random),
        canFillIn: false,
      );

      await tapVisible(
        tester,
        find.widgetWithText(AppButton, removeAgentLabel),
      );
      await tester.pump();
      await tapVisible(tester, find.widgetWithText(AppButton, doneLabel));
      await tester.pump();

      expect(scene.removals.count, 1);
      expect(scene.dones.count, 1);
      expect(scene.changes, isEmpty);
    }
  });

  testWidgets('test_agent_settings_panel_build_property_choices_change_one', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162204);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowAgent agent = randomSettingsAgent(random);
      final AgentSettingsScene scene = await pumpAgentSettings(
        tester,
        random: random,
        agent: agent,
        canFillIn: false,
      );
      final SelectField<AgentKindChoice> kindField = tester.widget(
        find.byType(SelectField<AgentKindChoice>),
      );
      final SelectField<RunnerTarget> runnerField = tester.widget(
        find.byType(SelectField<RunnerTarget>),
      );
      final AgentKind kind = pickOne(random, AgentKind.values);
      final RunnerTarget target = pickOne(random, <RunnerTarget>[
        for (final SelectEntry<RunnerTarget> entry in runnerField.entries)
          if (entry is SelectOption<RunnerTarget>) entry.value,
      ]);

      expect(kindField.value, AgentKindChoice(agent.kind));
      expect(runnerField.value, agent.runsOn);
      kindField.onChanged(AgentKindChoice(kind));
      await tester.pump();
      final SelectField<RunnerTarget> shownRunnerField = tester.widget(
        find.byType(SelectField<RunnerTarget>),
      );
      shownRunnerField.onChanged(target);

      expect(scene.changes.first, agent.copyWith(kind: kind));
      expect(scene.changes.last, agent.copyWith(kind: kind, runsOn: target));
    }
  });

  testWidgets('test_did_update_widget_property_outside_task_replaces_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162205);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowAgent agent = randomSettingsAgent(random);
      final AgentSettingsScene scene = await pumpAgentSettings(
        tester,
        random: random,
        agent: agent,
        canFillIn: true,
      );
      final String filledTask = 'Filled ${randomText(random)}';

      scene.shownAgent.value = agent.copyWith(task: filledTask);
      await tester.pump();

      expect(_readTaskText(tester), filledTask);
      expect(scene.changes, isEmpty);
    }
  });

  testWidgets('test_did_update_widget_property_typed_text_survives_echo', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162206);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentSettingsScene scene = await pumpAgentSettings(
        tester,
        random: random,
        agent: randomSettingsAgent(random),
        canFillIn: false,
      );
      final String typed = 'Typed ${randomText(random)}';

      await enterFieldText(tester, label: taskFieldLabel, text: typed);

      expect(_readTaskText(tester), typed);
      expect(scene.changes.last.task, typed);
      expect(scene.shownAgent.value.task, typed);
    }
  });

  testWidgets('test_did_update_widget_property_other_fields_keep_the_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162207);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowAgent agent = randomSettingsAgent(random);
      final AgentSettingsScene scene = await pumpAgentSettings(
        tester,
        random: random,
        agent: agent,
        canFillIn: false,
      );
      final TextEditingController before = tester
          .widget<TextField>(findFieldInput(taskFieldLabel))
          .controller!;
      final TextSelection cursor = TextSelection.collapsed(
        offset: random.nextInt(agent.task.length + 1),
      );
      before.selection = cursor;

      scene.shownAgent.value = agent.copyWith(
        kind: pickOne(random, AgentKind.values),
        usesAutomaticSkills: !agent.usesAutomaticSkills,
      );
      await tester.pump();

      final TextEditingController after = tester
          .widget<TextField>(findFieldInput(taskFieldLabel))
          .controller!;
      expect(after, same(before));
      expect(after.text, agent.task);
      expect(after.selection, cursor);
    }
  });
}
