import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/lists/stacked_list_row.dart';

import '../../data/fakes/support/task_inputs.dart';
import '../../data/fakes/support/workflow_usage_inputs.dart';
import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../support/random_page_windows.dart';
import 'random_workflow_records.dart';

const SectionRoute workflowsSectionRoute = SectionRoute(AppSection.workflows);
const int _largestWorkflowCount = 6;
const int _largestWorkCount = 7;

typedef WorkflowsScene = ({
  FakeWorkflowRepository workflows,
  FakeWorkspaceRepository workspaces,
  FakeTaskRepository tasks,
  FakeJobRepository jobs,
  AppNavigation navigation,
  WorkflowsScreen screen,
});

WorkspaceScope _randomAvailability(Random random) {
  return pickOne<WorkspaceScope>(random, <WorkspaceScope>[
    const AllWorkspaces(),
    OnlyWorkspaces(const <WorkspaceId>[GalleryWorkspaceIds.acme]),
    OnlyWorkspaces(const <WorkspaceId>[GalleryWorkspaceIds.personal]),
    OnlyWorkspaces(const <WorkspaceId>[
      GalleryWorkspaceIds.personal,
      GalleryWorkspaceIds.acme,
    ]),
    OnlyWorkspaces(const <WorkspaceId>[]),
  ]);
}

Workflow _randomSceneWorkflow(Random random, int index) {
  final Workflow stored = randomStoredWorkflow(random, index: index);
  return Workflow(
    id: stored.id,
    name: stored.name,
    availability: _randomAvailability(random),
    agents: stored.agents,
    connections: stored.connections,
    signature: stored.signature,
  );
}

List<Workflow> randomSceneWorkflows(Random random) {
  final int count = random.nextInt(_largestWorkflowCount + 1);
  final List<Workflow> workflows = <Workflow>[
    for (int index = 0; index < count; index += 1)
      _randomSceneWorkflow(random, index),
  ];
  workflows.shuffle(random);
  return workflows;
}

List<WorkflowChange> _randomChanges(Random random, List<Workflow> workflows) {
  return <WorkflowChange>[
    for (final Workflow workflow in workflows)
      if (workflow.signature != null && random.nextBool())
        randomChangeOf(random, workflow),
  ];
}

List<Task> _randomWork(Random random, List<Workflow> workflows) {
  final List<WorkflowId> workflowIds = <WorkflowId>[
    for (final Workflow workflow in workflows) workflow.id,
  ];
  final int count = random.nextInt(_largestWorkCount + 1);
  return <Task>[
    for (int index = 0; index < count; index += 1)
      buildWorkWithDoer(
        random,
        identifier: 'scene-work-$index',
        doer: randomDoerAmong(random, workflowIds),
        schedule: random.nextBool() ? randomJobSchedule(random) : null,
      ),
  ];
}

typedef SceneWork = ({List<Task> work, List<Run> runs});

WorkflowsScene buildWorkflowsScene(Random random, List<Workflow> workflows) {
  final List<Task> work = _randomWork(random, workflows);
  return buildWorkflowsSceneWithWork(
    random,
    workflows: workflows,
    sceneWork: (work: work, runs: randomSeededRuns(random, work)),
  );
}

WorkflowsScene buildWorkflowsSceneWithWork(
  Random random, {
  required List<Workflow> workflows,
  required SceneWork sceneWork,
}) {
  final FakeWorkspaceRepository workspaces = buildAcmeWorkspaceRepository();
  final FakeWorkflowRepository workflowRepository = FakeWorkflowRepository(
    workflows: workflows,
    changes: _randomChanges(random, workflows),
    clock: FixedClock(galleryNow),
    currentDeviceId: GalleryDeviceIds.airLaptop,
    draftTemplate: galleryWorkflows.first,
    drafterDeviceId: GalleryDeviceIds.officeServer,
    draftStepDelay: Duration.zero,
    workspaceRepository: workspaces,
  );
  final FakeTaskRepository tasks = buildTaskRepository(
    tasks: sceneWork.work,
    runs: sceneWork.runs,
    workflows: workflowRepository,
  );
  final FakeJobRepository jobs = FakeJobRepository(
    taskRepository: tasks,
    clock: FixedClock(galleryNow),
  );
  final AppNavigation navigation = AppNavigation(
    initialRoute: workflowsSectionRoute,
  );
  final WorkflowsScreen screen = WorkflowsScreen(
    workflowRepository: workflowRepository,
    workspaceRepository: workspaces,
    taskRepository: tasks,
    jobRepository: jobs,
    clock: FixedClock(galleryNow),
    navigation: navigation,
  );
  return (
    workflows: workflowRepository,
    workspaces: workspaces,
    tasks: tasks,
    jobs: jobs,
    navigation: navigation,
    screen: screen,
  );
}

Future<WorkflowsScene> pumpRandomWorkflowsScene(
  WidgetTester tester,
  Random random,
) async {
  final WorkflowsScene scene = buildWorkflowsScene(
    random,
    randomSceneWorkflows(random),
  );
  await pumpPageInRandomWindow(tester, random: random, page: scene.screen);
  return scene;
}

DateTime? findExpectedLastUse(WorkflowsScene scene, WorkflowId workflowId) {
  return findLastWorkflowUse(
    workflowId: workflowId,
    tasks: scene.tasks.listTasksAndJobs(),
    listRuns: scene.tasks.listRuns,
  );
}

SignatureState findExpectedState(WorkflowsScene scene, Workflow workflow) {
  return findSignatureState(
    workflow,
    scene.workflows.findPendingChange(workflow.id),
  );
}

Finder findWorkflowName(Workflow workflow) {
  return find.text(workflow.name, findRichText: true);
}

bool _isRowBox(Widget widget) {
  return widget is StackedListRow || widget is TableRowInkWell;
}

Rect _findGlobalRect(Element element) {
  final RenderBox box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

List<String> readWorkflowRowTexts(Workflow workflow) {
  final Finder rowBox = find
      .ancestor(
        of: findWorkflowName(workflow),
        matching: find.byWidgetPredicate(_isRowBox),
      )
      .first;
  final Rect band = _findGlobalRect(rowBox.evaluate().single);
  final List<String> texts = <String>[];
  for (final Element element in find.byType(RichText).evaluate()) {
    final double top = _findGlobalRect(element).top;
    final bool isInRow = top >= band.top - 1 && top < band.bottom;
    if (isInRow) {
      final RichText shown = element.widget as RichText;
      texts.add(shown.text.toPlainText());
    }
  }
  return texts;
}
