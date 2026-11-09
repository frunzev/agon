import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../data/fakes/support/task_inputs.dart';
import '../../support/app_harness.dart';
import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import '../support/held_save_repositories.dart';
import '../support/planned_refusal.dart';
import '../support/refusing_work_repositories.dart';
import 'random_workflow_records.dart';

const SectionRoute detailWorkflowsRoute = SectionRoute(AppSection.workflows);

final DateTime detailNow = galleryNow;

typedef DetailPage = ({
  Workflow workflow,
  WorkflowChange? change,
  FakeWorkflowRepository workflows,
  FakeTaskRepository tasks,
  AppDependencies dependencies,
  AppNavigation navigation,
});

WorkflowDetailScreen buildDetailScreen({
  required WorkflowId workflowId,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return WorkflowDetailScreen(
    workflowId: workflowId,
    workflowRepository: dependencies.workflowRepository,
    workspaceRepository: dependencies.workspaceRepository,
    deviceRepository: dependencies.deviceRepository,
    runnerRepository: dependencies.runnerRepository,
    projectRepository: dependencies.projectRepository,
    taskRepository: dependencies.taskRepository,
    clock: dependencies.clock,
    navigation: navigation,
  );
}

Future<DetailPage> openDetailPage(
  WidgetTester tester, {
  required Random random,
  required Workflow workflow,
  required WorkflowChange? change,
  required SaveHold? taskHold,
  required PlannedRefusal? taskRefusal,
}) async {
  final FakeWorkflowRepository workflows = buildRecordRepository(
    workflows: <Workflow>[workflow],
    changes: <WorkflowChange>[?change],
  );
  final FakeTaskRepository tasks = buildTaskRepository(
    tasks: const <Task>[],
    runs: const <Run>[],
    workflows: workflows,
  );
  workflows.linkWork(
    taskWork: buildTaskWorkOver(tasks),
    approvalRepository: FakeApprovalRepository(
      approvals: const <ApprovalRequest>[],
      clock: FixedClock(galleryNow),
      currentDeviceId: GalleryDeviceIds.airLaptop,
    ),
  );
  TaskRepository shownTasks = tasks;
  if (taskHold != null) {
    shownTasks = HeldTaskRepository(stored: tasks, saveHold: taskHold);
  }
  if (taskRefusal != null) {
    shownTasks = RefusingTaskRepository(stored: tasks, refusal: taskRefusal);
  }
  final AppDependencies dependencies = replaceRepositories(
    buildGalleryDependencies(),
    workflowRepository: workflows,
    taskRepository: shownTasks,
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
    route: detailWorkflowsRoute,
    dependencies: dependencies,
  );
  navigation.openRoute(WorkflowDetailRoute(workflow.id));
  await pumpFrames(tester);
  return (
    workflow: workflow,
    change: change,
    workflows: workflows,
    tasks: tasks,
    dependencies: dependencies,
    navigation: navigation,
  );
}

Future<DetailPage> openRandomDetailPage(WidgetTester tester, Random random) {
  final Workflow workflow = randomStoredWorkflow(random, index: 0);
  final bool hasChange = workflow.signature != null && random.nextBool();
  return openDetailPage(
    tester,
    random: random,
    workflow: workflow,
    change: hasChange ? randomChangeOf(random, workflow) : null,
    taskHold: null,
    taskRefusal: null,
  );
}

Future<void> tapDetailButton(WidgetTester tester, String label) async {
  final Finder button = find.widgetWithText(AppButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button, warnIfMissed: false);
  await pumpFrames(tester);
}
