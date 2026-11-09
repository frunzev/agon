import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import '../../support/workflow_repositories.dart';
import '../support/held_save_repositories.dart';
import '../support/planned_refusal.dart';
import '../support/refusing_library_action_repositories.dart';
import 'held_workflow_repository.dart';

const SectionRoute manualWorkflowsRoute = SectionRoute(AppSection.workflows);
const List<AppRoute> manualRoutes = <AppRoute>[
  manualWorkflowsRoute,
  NewWorkflowRoute(),
  ManualWorkflowRoute(),
];
const String filledTask = 'Build the release and fix any errors.';
const int loopRounds = 3;

typedef ManualScene = ({
  FakeWorkflowRepository stored,
  SaveHold saveHold,
  AppDependencies dependencies,
  AppNavigation navigation,
});

String describeManualSummary(int count) {
  if (count == 1) {
    return '1 agent · acme · not signed yet';
  }
  return '$count agents · acme · not signed yet';
}

ManualWorkflowScreen buildManualScreen({
  required WorkflowRepository workflows,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return ManualWorkflowScreen(
    workflowRepository: workflows,
    workspaceRepository: dependencies.workspaceRepository,
    deviceRepository: dependencies.deviceRepository,
    runnerRepository: dependencies.runnerRepository,
    skillRepository: dependencies.skillRepository,
    navigation: navigation,
  );
}

Future<ManualScene> openManualScene(
  WidgetTester tester,
  Random random, {
  required PlannedRefusal? refusal,
}) async {
  final AppDependencies dependencies = buildGalleryDependencies();
  final FakeWorkflowRepository stored = buildGalleryWorkflowRepository();
  final SaveHold saveHold = SaveHold();
  final WorkflowRepository workflows = refusal == null
      ? HeldWorkflowRepository(stored: stored, saveHold: saveHold)
      : RefusingWorkflowRepository(stored: stored, refusal: refusal);
  final AppNavigation navigation = AppNavigation(
    initialRoute: manualWorkflowsRoute,
  );
  navigation.openRoute(const NewWorkflowRoute());
  navigation.openRoute(const ManualWorkflowRoute());
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  useViewSize(tester, Size(width, desktopHeight));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    wrapInApp(
      buildManualScreen(
        workflows: workflows,
        dependencies: dependencies,
        navigation: navigation,
      ),
      platform: platformMeantByWidth(width),
    ),
  );
  await tester.pump();
  return (
    stored: stored,
    saveHold: saveHold,
    dependencies: dependencies,
    navigation: navigation,
  );
}

Future<void> tapManualLabel(WidgetTester tester, String label) async {
  final Finder target = find.text(label).first;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target, warnIfMissed: false);
  await tester.pump();
}

Future<int> addRandomSteps(WidgetTester tester, Random random) async {
  final int count = 1 + random.nextInt(4);
  for (int i = 0; i < count; i += 1) {
    final String label = random.nextBool()
        ? addAgentLabel
        : addPersonStepLabel;
    await tapManualLabel(tester, label);
  }
  return count;
}

Future<Workflow> openManualSceneWithSteps(
  WidgetTester tester,
  Random random,
) async {
  await openManualScene(tester, random, refusal: null);
  await addRandomSteps(tester, random);
  return readManualWorkflow(tester);
}

EditableWorkflowDiagram readManualDiagram(WidgetTester tester) {
  return tester.widget<EditableWorkflowDiagram>(
    find.byType(EditableWorkflowDiagram),
  );
}

Workflow readManualWorkflow(WidgetTester tester) {
  return readManualDiagram(tester).workflow;
}

Future<void> selectManualStep(
  WidgetTester tester,
  WorkflowAgentId agentId,
) async {
  readManualDiagram(tester).onAgentSelected(agentId);
  await tester.pump();
}

Future<void> changeSelectedStep(
  WidgetTester tester,
  WorkflowAgent changed,
) async {
  final Finder agentPanel = find.byType(AgentSettingsPanel);
  if (agentPanel.evaluate().isNotEmpty) {
    tester.widget<AgentSettingsPanel>(agentPanel).onAgentChanged(changed);
  } else {
    tester
        .widget<PersonStepPanel>(find.byType(PersonStepPanel))
        .onAgentChanged(changed);
  }
  await tester.pump();
}

Future<void> fillEveryStep(WidgetTester tester) async {
  for (final WorkflowAgent agent in readManualWorkflow(tester).agents) {
    await selectManualStep(tester, agent.id);
    await changeSelectedStep(
      tester,
      agent.copyWith(kind: AgentKind.claudeCode, task: filledTask),
    );
  }
}

Future<void> connectManualSteps(
  WidgetTester tester,
  AgentConnection connection,
) async {
  readManualDiagram(tester).onAgentsConnected(connection);
  await tester.pump();
}

AgentConnection plainConnection(WorkflowAgentId from, WorkflowAgentId to) {
  return AgentConnection(
    from: from,
    to: to,
    condition: null,
    roundLimit: null,
  );
}

Future<List<WorkflowAgent>> openManualSceneWithAgents(
  WidgetTester tester,
  Random random,
) async {
  await openManualScene(tester, random, refusal: null);
  final int count = 2 + random.nextInt(3);
  for (int i = 0; i < count; i += 1) {
    await tapManualLabel(tester, addAgentLabel);
  }
  return readManualWorkflow(tester).agents;
}

Future<AgentConnection> addLoopBack(
  WidgetTester tester,
  WorkflowAgent first,
  WorkflowAgent second,
) async {
  await connectManualSteps(tester, plainConnection(first.id, second.id));
  await connectManualSteps(tester, plainConnection(second.id, first.id));
  final AgentConnection loop = AgentConnection(
    from: second.id,
    to: first.id,
    condition: 'needs work',
    roundLimit: loopRounds,
  );
  tester.widget<NewLoopPanel>(find.byType(NewLoopPanel)).onLoopAdded(loop);
  await tester.pump();
  return loop;
}

Future<void> nameAndFillManualWorkflow(
  WidgetTester tester,
  Random random,
  String name,
) async {
  await tester.enterText(findFieldInput(workflowNameLabel), name);
  await tester.pump();
  await addRandomSteps(tester, random);
  await fillEveryStep(tester);
}

Workflow? findSavedWorkflow(ManualScene scene, String name) {
  for (final Workflow workflow in scene.stored.listWorkflows()) {
    if (workflow.name == name) {
      return workflow;
    }
  }
  return null;
}
