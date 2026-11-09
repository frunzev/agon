import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/app.dart';
import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_chat.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/windows/run_window_opener.dart';

import '../../../support/app_harness.dart';
import '../../../support/random_inputs.dart';
import '../../../support/recording_native_windows.dart';
import '../../../support/run_window_harness.dart';
import '../../../support/widget_harness.dart';
import '../../support/random_running_steps.dart';
import 'run_page_retry_harness.dart';

const SectionRoute tasksSectionRoute = SectionRoute(AppSection.tasks);
const List<AppRoute> otherSectionRoutes = <AppRoute>[
  SectionRoute(AppSection.projects),
  SectionRoute(AppSection.jobs),
  SectionRoute(AppSection.approvals),
];

final class RecordingRunWindowOpener implements RunWindowOpener {
  final List<(RunId, String)> openedRuns = <(RunId, String)>[];

  @override
  void openRunWindow({required RunId runId, required String title}) {
    openedRuns.add((runId, title));
  }
}

final class RunPageCase {
  const RunPageCase({required this.dependencies, required this.run});

  final AppDependencies dependencies;
  final Run run;

  Task get task => dependencies.taskRepository.findTask(run.taskId);

  String get runLabel {
    final Workflow? workflow = findWorkflowForDoer(
      task.doer,
      dependencies.workflowRepository.listWorkflows(),
    );
    return describeRunLabel(task: task, workflow: workflow, run: run);
  }
}

RunPageCase randomRunPageCase(Random random) {
  final List<Run> runs = <Run>[
    for (final Run run in scatterGalleryRunSteps(random))
      run.withProgress(
        nextStatus: pickOne(random, RunStatus.values),
        nextSteps: run.steps,
        nextFinishedAt: run.finishedAt,
      ),
  ];
  final FakeTaskRepository taskRepository = buildTaskRepositoryWithRuns(runs);
  final AppDependencies gallery = buildGalleryDependencies();
  final AppDependencies dependencies = replaceRepositories(
    gallery,
    taskRepository: taskRepository,
    jobRepository: buildJobRepositoryOver(taskRepository),
    chatRepository: FakeChatRepository(
      conversations: <Conversation>[galleryConversationAwaitingApproval],
      taskRepository: taskRepository,
      clock: gallery.clock,
    ),
  );
  return RunPageCase(dependencies: dependencies, run: pickOne(random, runs));
}

Future<AppNavigation> openRunPageInMainWindow(
  WidgetTester tester, {
  required Random random,
  required RunPageCase page,
  required List<AppRoute> routesBelow,
  required RunWindowOpener? opener,
}) async {
  final List<AppRoute> routes = <AppRoute>[
    ...routesBelow,
    TaskRunRoute(page.run.id),
  ];
  final AppNavigation navigation = AppNavigation(initialRoute: routes.first);
  navigation.restoreRoutes(routes);
  await tester.pumpWidget(const SizedBox.shrink());
  useViewSize(tester, randomRunWindowSize(random));
  await tester.pumpWidget(
    AgentOrchestrationApp(
      key: UniqueKey(),
      dependencies: page.dependencies,
      navigation: navigation,
      messengerKey: GlobalKey<ScaffoldMessengerState>(),
      runWindowOpener: opener,
    ),
  );
  await pumpFrames(tester);
  return navigation;
}

Future<AppNavigation> openRunPageInRunWindow(
  WidgetTester tester, {
  required RunPageCase page,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  return pumpRunWindow(
    tester,
    runId: page.run.id,
    dependencies: removeApprovals(page.dependencies),
    onTopSwitch: RecordingOnTopSwitch(),
  );
}

List<AppRoute> randomRoutesBelowRun(Random random) {
  return pickOne(random, <List<AppRoute>>[
    const <AppRoute>[tasksSectionRoute],
    <AppRoute>[pickOne(random, otherSectionRoutes)],
  ]);
}
