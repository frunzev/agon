import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../support/form_finders.dart';
import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import '../task_form/task_form_scene.dart';

const String _offlineSuffix = ', offline';

final class _StepActions {
  final List<WorkflowAgentId> removed = <WorkflowAgentId>[];
  final List<WorkflowAgentId> filled = <WorkflowAgentId>[];
  final TapCounter dones = TapCounter();

  BuilderPanelActions build({required bool canFillIn}) {
    return BuilderPanelActions(
      onAgentChanged: (WorkflowAgent _) {},
      onFillInRequested: canFillIn ? filled.add : null,
      onAgentRemoved: removed.add,
      onConnectionChanged: (AgentConnection _) {},
      onConnectionRemoved: (AgentConnection _) {},
      onLoopAdded: (AgentConnection _) {},
      onDone: dones.countTap,
    );
  }
}

typedef _PickedStep = ({Workflow workflow, WorkflowAgent agent});

_PickedStep _randomStep(Random random) {
  Workflow workflow = randomBranchingWorkflow(random);
  while (workflow.agents.isEmpty) {
    workflow = randomBranchingWorkflow(random);
  }
  return (workflow: workflow, agent: pickOne(random, workflow.agents));
}

Future<void> _pumpStepPanel(
  WidgetTester tester,
  Random random, {
  required _PickedStep step,
  required _StepActions actions,
  required bool canFillIn,
  required List<Runner> runners,
}) async {
  final Widget? panel = buildBuilderPanel(
    workflow: step.workflow,
    selection: SelectedStep(step.agent.id),
    sources: BuilderPanelSources(
      runners: runners,
      skills: gallerySkills,
      deviceNames: DeviceNames(galleryDevices),
    ),
    actions: actions.build(canFillIn: canFillIn),
  );
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: SingleChildScrollView(child: panel!),
  );
}

String _removeLabelFor(WorkflowAgent agent) {
  return agent.stepKind == StepKind.person ? removeStepLabel : 'Remove agent';
}

void main() {
  testWidgets('test_build_step_panel_property_remove_names_this_step', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162701);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _PickedStep step = _randomStep(random);
      final _StepActions actions = _StepActions();
      await _pumpStepPanel(
        tester,
        random,
        step: step,
        actions: actions,
        canFillIn: random.nextBool(),
        runners: randomRunnersOnDistinctDevices(random),
      );

      await tapVisible(
        tester,
        find.widgetWithText(AppButton, _removeLabelFor(step.agent)),
      );
      await tester.pump();
      await tapVisible(tester, find.widgetWithText(AppButton, 'Done'));
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(actions.removed, <WorkflowAgentId>[step.agent.id]);
      expect(actions.dones.count, 1);
    }
  });

  testWidgets('test_build_step_panel_property_fill_in_names_this_agent', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162702);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _PickedStep step = _randomStep(random);
      final bool canFillIn = random.nextBool();
      final _StepActions actions = _StepActions();
      await _pumpStepPanel(
        tester,
        random,
        step: step,
        actions: actions,
        canFillIn: canFillIn,
        runners: randomRunnersOnDistinctDevices(random),
      );
      final Finder fillIn = find.widgetWithText(
        AppButton,
        fillInWithAgentLabel,
      );
      final bool isOffered =
          canFillIn && step.agent.stepKind == StepKind.agent;

      expect(fillIn, isOffered ? findsOneWidget : findsNothing);
      if (isOffered) {
        await tapVisible(tester, fillIn);
        await tester.pump();
      }
      expect(actions.filled, <WorkflowAgentId>[if (isOffered) step.agent.id]);
    }
  });

  testWidgets('test_build_step_panel_property_runs_on_lists_choice_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162703);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _PickedStep picked = _randomStep(random);
      final Device device = pickOne(random, galleryDevices);
      final WorkflowAgent agent = WorkflowAgent(
        id: picked.agent.id,
        name: picked.agent.name,
        stepKind: StepKind.agent,
        kind: picked.agent.kind,
        task: picked.agent.task,
        runsOn: SpecificRunner(device.id),
        skills: picked.agent.skills,
        usesAutomaticSkills: picked.agent.usesAutomaticSkills,
        approvalPolicy: picked.agent.approvalPolicy,
        position: picked.agent.position,
      );
      final List<Runner> runners = <Runner>[
        for (final Runner runner in randomRunnersOnDistinctDevices(random))
          if (runner.deviceId != device.id || runner.online) runner,
      ];
      final bool isOnline = runners.any(
        (Runner runner) => runner.deviceId == device.id,
      );
      await _pumpStepPanel(
        tester,
        random,
        step: (
          workflow: picked.workflow.withGraph(
            agents: <WorkflowAgent>[
              for (final WorkflowAgent other in picked.workflow.agents)
                if (other.id == agent.id) agent else other,
            ],
            connections: picked.workflow.connections,
          ),
          agent: agent,
        ),
        actions: _StepActions(),
        canFillIn: false,
        runners: runners,
      );

      final AgentSettingsPanel panel = tester.widget(
        find.byType(AgentSettingsPanel),
      );
      final List<SelectOption<RunnerTarget>> chosen =
          <SelectOption<RunnerTarget>>[
            for (final SelectOption<RunnerTarget> option
                in panel.runnerOptions)
              if (option.value == agent.runsOn) option,
          ];
      expect(chosen, hasLength(1));
      expect(chosen.single.label.endsWith(_offlineSuffix), !isOnline);
    }
  });
}
