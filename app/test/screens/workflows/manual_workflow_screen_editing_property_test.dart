import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'manual_workflow_scene.dart';

void main() {
  testWidgets('test_manual_workflow_screen_build_panel_property_panel_'
      'matches_the_selected_step_kind', (WidgetTester tester) async {
    final Random random = seededRandom(1221001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = await openManualSceneWithSteps(tester, random);
      final WorkflowAgent chosen = pickOne(random, workflow.agents);

      await selectManualStep(tester, chosen.id);

      final bool isPerson = chosen.stepKind == StepKind.person;
      expect(
        find.byType(PersonStepPanel),
        isPerson ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(AgentSettingsPanel),
        isPerson ? findsNothing : findsOneWidget,
      );
    }
  });

  testWidgets('test_manual_workflow_screen_build_panel_property_no_panel_'
      'without_a_selection', (WidgetTester tester) async {
    final Random random = seededRandom(1221002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualSceneWithSteps(tester, random);

      readManualDiagram(tester).onSelectionCleared();
      await tester.pump();

      expect(find.byType(AgentSettingsPanel), findsNothing);
      expect(find.byType(PersonStepPanel), findsNothing);
      expect(readManualDiagram(tester).selection, isNull);
    }
  });

  testWidgets('test_manual_workflow_screen_build_panel_property_done_closes_'
      'the_panel_and_keeps_the_steps', (WidgetTester tester) async {
    final Random random = seededRandom(1221003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow before = await openManualSceneWithSteps(tester, random);
      final Finder agentPanel = find.byType(AgentSettingsPanel);

      if (agentPanel.evaluate().isNotEmpty) {
        tester.widget<AgentSettingsPanel>(agentPanel).onDone();
      } else {
        tester.widget<PersonStepPanel>(find.byType(PersonStepPanel)).onDone();
      }
      await tester.pump();

      expect(readManualDiagram(tester).selection, isNull);
      expect(readManualWorkflow(tester).agents, before.agents);
    }
  });

  testWidgets('test_manual_workflow_screen_select_property_the_panel_shows_'
      'the_selected_step', (WidgetTester tester) async {
    final Random random = seededRandom(1221004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = await openManualSceneWithSteps(tester, random);
      final WorkflowAgent chosen = pickOne(random, workflow.agents);

      await selectManualStep(tester, chosen.id);

      final BuilderSelection? selection = readManualDiagram(tester).selection;
      expect((selection! as SelectedStep).agentId, chosen.id);
      final WorkflowAgent shown = chosen.stepKind == StepKind.person
          ? tester.widget<PersonStepPanel>(find.byType(PersonStepPanel)).agent
          : tester
                .widget<AgentSettingsPanel>(find.byType(AgentSettingsPanel))
                .agent;
      expect(shown, chosen);
    }
  });

  testWidgets('test_manual_workflow_screen_select_property_selecting_'
      'changes_no_step', (WidgetTester tester) async {
    final Random random = seededRandom(1221005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow before = await openManualSceneWithSteps(tester, random);

      for (int pick = 0; pick < 1 + random.nextInt(4); pick += 1) {
        await selectManualStep(tester, pickOne(random, before.agents).id);
      }

      expect(readManualWorkflow(tester).agents, before.agents);
      expect(readManualWorkflow(tester).connections, before.connections);
    }
  });

  testWidgets('test_manual_workflow_screen_select_property_the_last_'
      'selection_wins', (WidgetTester tester) async {
    final Random random = seededRandom(1221006);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = await openManualSceneWithSteps(tester, random);
      WorkflowAgentId? last;

      for (int pick = 0; pick < 1 + random.nextInt(4); pick += 1) {
        last = pickOne(random, workflow.agents).id;
        await selectManualStep(tester, last);
      }

      final BuilderSelection? selection = readManualDiagram(tester).selection;
      expect((selection! as SelectedStep).agentId, last);
    }
  });

  testWidgets('test_manual_workflow_screen_add_step_property_each_tap_adds_'
      'one_uniquely_named_step', (WidgetTester tester) async {
    final Random random = seededRandom(1221007);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualScene(tester, random, refusal: null);
      final int added = await addRandomSteps(tester, random);

      final List<WorkflowAgent> agents = readManualWorkflow(tester).agents;
      expect(agents.length, added);
      expect(
        <String>{for (final WorkflowAgent agent in agents) agent.name}.length,
        added,
      );
      expect(
        <WorkflowAgentId>{for (final WorkflowAgent agent in agents) agent.id}
            .length,
        added,
      );
    }
  });

  testWidgets('test_manual_workflow_screen_add_step_property_the_button_'
      'picks_the_step_kind', (WidgetTester tester) async {
    final Random random = seededRandom(1221008);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualScene(tester, random, refusal: null);
      final List<StepKind> expectedKinds = <StepKind>[];

      for (int tap = 0; tap < 1 + random.nextInt(4); tap += 1) {
        final bool addsPerson = random.nextBool();
        expectedKinds.add(addsPerson ? StepKind.person : StepKind.agent);
        await tapManualLabel(
          tester,
          addsPerson ? addPersonStepLabel : addAgentLabel,
        );
      }

      expect(<StepKind>[
        for (final WorkflowAgent agent in readManualWorkflow(tester).agents)
          agent.stepKind,
      ], expectedKinds);
    }
  });

  testWidgets('test_manual_workflow_screen_add_step_property_earlier_steps_'
      'stay_as_they_were', (WidgetTester tester) async {
    final Random random = seededRandom(1221009);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow before = await openManualSceneWithSteps(tester, random);

      await tapManualLabel(tester, addAgentLabel);

      final List<WorkflowAgent> after = readManualWorkflow(tester).agents;
      expect(after.sublist(0, before.agents.length), before.agents);
      expect(after.length, before.agents.length + 1);
    }
  });

  testWidgets('test_manual_workflow_screen_change_agent_property_the_new_'
      'settings_are_kept', (WidgetTester tester) async {
    final Random random = seededRandom(1221010);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = await openManualSceneWithSteps(tester, random);
      final WorkflowAgent chosen = pickOne(random, workflow.agents);
      await selectManualStep(tester, chosen.id);
      final WorkflowAgent changed = chosen.copyWith(
        task: randomText(random),
        kind: pickOne(random, AgentKind.values),
        runsOn: randomRunnerTarget(random),
      );

      await changeSelectedStep(tester, changed);

      expect(readManualWorkflow(tester).findAgent(chosen.id), changed);
    }
  });

  testWidgets('test_manual_workflow_screen_change_agent_property_other_steps_'
      'stay', (WidgetTester tester) async {
    final Random random = seededRandom(1221011);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = await openManualSceneWithSteps(tester, random);
      final WorkflowAgent chosen = pickOne(random, workflow.agents);
      await selectManualStep(tester, chosen.id);

      await changeSelectedStep(tester, chosen.copyWith(task: 'Changed $i'));

      for (final WorkflowAgent other in workflow.agents) {
        if (other.id != chosen.id) {
          expect(readManualWorkflow(tester).findAgent(other.id), other);
        }
      }
    }
  });

  testWidgets('test_manual_workflow_screen_change_agent_property_keeps_every_'
      'connection', (WidgetTester tester) async {
    final Random random = seededRandom(1221012);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualScene(tester, random, refusal: null);
      await tapManualLabel(tester, addAgentLabel);
      await tapManualLabel(tester, addAgentLabel);
      final List<WorkflowAgent> agents = readManualWorkflow(tester).agents;
      await connectManualSteps(
        tester,
        plainConnection(agents.first.id, agents.last.id),
      );
      final List<AgentConnection> before = readManualWorkflow(tester)
          .connections;
      final WorkflowAgent chosen = pickOne(random, agents);
      await selectManualStep(tester, chosen.id);

      await changeSelectedStep(tester, chosen.copyWith(name: 'renamed-$i'));

      expect(readManualWorkflow(tester).connections, before);
      expect(before.length, 1);
    }
  });
}
