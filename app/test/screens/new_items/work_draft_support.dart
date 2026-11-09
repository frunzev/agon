import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/new_items/work_draft_review.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/task_route_screens.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'new_item_harness.dart';
import 'random_drafts.dart';

const ProjectId _unlistedProjectId = ProjectId('project-nowhere');
const TaskDoer _unlistedWorkflowDoer = WorkflowDoer(
  WorkflowId('workflow-nowhere'),
);
const RunnerTarget _unknownRunner = SpecificRunner(DeviceId('device-nowhere'));

const List<DraftKind> workDraftKinds = <DraftKind>[
  DraftKind.task,
  DraftKind.job,
];

DraftedWork rebuildWork(
  DraftedWork work, {
  required String title,
  required ProjectId? projectId,
  required Schedule? schedule,
}) {
  return DraftedWork(
    title: title,
    details: work.details,
    projectId: projectId,
    doer: work.doer,
    runsOn: work.runsOn,
    agentPlace: work.agentPlace,
    skills: work.skills,
    usesAutomaticSkills: work.usesAutomaticSkills,
    approvalPolicy: work.approvalPolicy,
    schedule: schedule,
  );
}

DraftedWork randomScheduledWork(Random random) {
  return randomListedWork(random, DraftKind.job);
}

DraftedWork randomUnscheduledWork(Random random) {
  final DraftedWork work = randomListedWork(random, DraftKind.task);
  return rebuildWork(
    work,
    title: work.title,
    projectId: work.projectId,
    schedule: null,
  );
}

DraftedWork randomHostileWork(Random random, DraftKind kind) {
  final DraftedWork work = randomListedWork(random, kind);
  final ProjectId? projectId = pickOne(random, <ProjectId?>[
    work.projectId,
    work.projectId,
    _unlistedProjectId,
    null,
  ]);
  return DraftedWork(
    title: '${work.title} ${randomHostileText(random)}',
    details: work.details,
    projectId: projectId,
    doer: pickOne(random, <TaskDoer>[work.doer, _unlistedWorkflowDoer]),
    runsOn: pickOne(random, <RunnerTarget>[
      randomRunnerTarget(random),
      _unknownRunner,
    ]),
    agentPlace: work.agentPlace,
    skills: work.skills,
    usesAutomaticSkills: work.usesAutomaticSkills,
    approvalPolicy: work.approvalPolicy,
    schedule: work.schedule,
  );
}

AppNavigation openWorkNavigation(DraftKind kind) {
  final AppRoute newItemRoute = newItemRoutes[kind]!;
  final AppNavigation navigation = AppNavigation(
    initialRoute: SectionRoute(newItemRoute.section),
  );
  navigation.openRoute(newItemRoute);
  return navigation;
}

WorkDraftReview buildRecordingWorkReview({
  required DraftKind kind,
  required AppDependencies dependencies,
  required AppNavigation navigation,
  required List<RunnerTarget> chosenTargets,
}) {
  return WorkDraftReview(
    kind: kind,
    buildOptions: (RunnerTarget chosenTarget) {
      chosenTargets.add(chosenTarget);
      return buildTaskFormOptionsFor(
        dependencies: dependencies,
        chosenTarget: chosenTarget,
      );
    },
    taskRepository: dependencies.taskRepository,
    jobRepository: dependencies.jobRepository,
    navigation: navigation,
  );
}

Set<TaskId> listWorkIds(AppDependencies dependencies) {
  return <TaskId>{
    for (final Task task in dependencies.taskRepository.listTasks()) task.id,
    for (final Task job in dependencies.jobRepository.listJobs()) job.id,
  };
}

Task findOnlyNewWork(AppDependencies dependencies, Set<TaskId> idsBefore) {
  final Map<TaskId, Task> created = <TaskId, Task>{
    for (final Task task in dependencies.taskRepository.listTasks())
      if (!idsBefore.contains(task.id)) task.id: task,
    for (final Task job in dependencies.jobRepository.listJobs())
      if (!idsBefore.contains(job.id)) job.id: job,
  };
  if (created.length != 1) {
    throw StateError('Expected one new task or job, found $created');
  }
  return created.values.single;
}

typedef ApprovalScene = ({
  AppDependencies dependencies,
  AppNavigation navigation,
  WorkDraftReview review,
  Set<TaskId> idsBefore,
  List<AppRoute> routesBefore,
});

ApprovalScene setUpWorkApproval(DraftKind kind) {
  final AppDependencies dependencies = buildGalleryDependencies();
  final AppNavigation navigation = openWorkNavigation(kind);
  return (
    dependencies: dependencies,
    navigation: navigation,
    review: buildRecordingWorkReview(
      kind: kind,
      dependencies: dependencies,
      navigation: navigation,
      chosenTargets: <RunnerTarget>[],
    ),
    idsBefore: listWorkIds(dependencies),
    routesBefore: navigation.routes,
  );
}

void expectNoWorkChanged(ApprovalScene scene) {
  expect(listWorkIds(scene.dependencies), scene.idsBefore);
  expect(scene.navigation.routes, scene.routesBefore);
}
