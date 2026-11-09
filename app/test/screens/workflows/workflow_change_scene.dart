import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import '../support/held_save_repositories.dart';
import '../support/planned_refusal.dart';
import '../support/refusing_library_action_repositories.dart';
import 'held_workflow_repository.dart';
import 'random_workflow_records.dart';

const String discardChangeLabel = 'Discard change';
const String signChangeLabel = 'Sign change';
const SectionRoute changeWorkflowsRoute = SectionRoute(AppSection.workflows);

typedef SettlePage = ({
  Workflow workflow,
  FakeWorkflowRepository stored,
  SaveHold saveHold,
  AppNavigation navigation,
});

Future<SettlePage> openSettlePage(
  WidgetTester tester,
  Random random, {
  required PlannedRefusal? refusal,
}) async {
  final Workflow workflow = randomSignableWorkflow(random);
  final FakeWorkflowRepository stored = buildRecordRepository(
    workflows: <Workflow>[workflow],
    changes: <WorkflowChange>[randomChangeOf(random, workflow)],
  );
  final SaveHold saveHold = SaveHold();
  final WorkflowRepository shown = refusal == null
      ? HeldWorkflowRepository(stored: stored, saveHold: saveHold)
      : RefusingWorkflowRepository(stored: stored, refusal: refusal);
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: Size(
      randomWidth(random, least: narrowestWidth, most: widestWidth),
      desktopHeight,
    ),
    route: changeWorkflowsRoute,
    dependencies: replaceRepositories(
      buildGalleryDependencies(),
      workflowRepository: shown,
    ),
  );
  navigation.openRoute(WorkflowChangeRoute(workflow.id));
  await pumpFrames(tester);
  return (
    workflow: workflow,
    stored: stored,
    saveHold: saveHold,
    navigation: navigation,
  );
}

Future<void> tapChangeAction(WidgetTester tester, String label) async {
  final Finder button = find.widgetWithText(AppButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button, warnIfMissed: false);
}

bool isChangeActionEnabled(WidgetTester tester, String label) {
  final AppButton button = tester.widget<AppButton>(
    find.widgetWithText(AppButton, label),
  );
  return button.onPressed != null;
}

typedef RandomChangePage = ({
  Workflow workflow,
  WorkflowChange? change,
  FakeWorkflowRepository workflows,
  AppNavigation navigation,
});

Future<RandomChangePage> openRandomChangePage(
  WidgetTester tester,
  Random random,
) async {
  final Workflow workflow = randomStoredWorkflow(random, index: 0);
  final WorkflowChange? change = random.nextInt(4) == 0
      ? null
      : randomChangeOf(random, workflow);
  final FakeWorkflowRepository workflows = buildRecordRepository(
    workflows: <Workflow>[workflow],
    changes: <WorkflowChange>[?change],
  );
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: Size(width, desktopHeight),
    route: const SectionRoute(AppSection.workflows),
    dependencies: replaceRepositories(
      buildGalleryDependencies(),
      workflowRepository: workflows,
    ),
  );
  navigation.openRoute(WorkflowChangeRoute(workflow.id));
  await pumpFrames(tester);
  return (
    workflow: workflow,
    change: change,
    workflows: workflows,
    navigation: navigation,
  );
}
