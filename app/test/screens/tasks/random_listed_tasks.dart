import 'dart:math';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../task_run/support/random_shown_runs.dart';

const int _mostListedTasks = 6;
const int _mostRunsPerTask = 2;

typedef TasksScene = ({
  AppDependencies dependencies,
  FakeTaskRepository tasks,
  List<Task> allTasks,
});

TaskDoer _randomDoer(Random random) {
  if (random.nextBool()) {
    return OneAgentDoer(pickOne(random, AgentKind.values));
  }
  final Workflow workflow = pickOne(random, galleryWorkflows);
  return WorkflowDoer(workflow.id);
}

Task randomListedTask(Random random, int index) {
  return Task(
    id: TaskId('listed-task-$index'),
    title: 'Task $index ${randomWordPhrase(random)}'.trim(),
    details: randomWordPhrase(random),
    projectId: pickOne(random, galleryProjects).id,
    doer: _randomDoer(random),
    runsOn: randomRunnerTarget(random),
    agentPlace: pickOne(random, AgentPlace.values),
    skills: const <SkillId>[],
    usesAutomaticSkills: random.nextBool(),
    approvalPolicy: null,
    schedule: null,
    status: pickOne(random, TaskStatus.values),
    createdAt: galleryNow,
  );
}

Run randomListedRun(Random random, Task task, int index) {
  final Workflow? workflow = findWorkflowForDoer(task.doer, galleryWorkflows);
  final List<RunStep> steps = workflow == null
      ? randomOneAgentSteps(random, galleryNow)
      : randomStepsOfWorkflow(random, workflow: workflow, now: galleryNow);
  final Run run = buildShownRun(
    random,
    runId: RunId('${task.id.value}-run-$index'),
    taskId: task.id,
    steps: steps,
    now: galleryNow,
  );
  return Run(
    id: run.id,
    taskId: run.taskId,
    number: index + 1,
    status: run.status,
    steps: run.steps,
    log: run.log,
    chat: run.chat,
    failure: run.failure,
    link: run.link,
    linkLostAt: run.linkLostAt,
    agentSession: run.agentSession,
    worktreeBranch: run.worktreeBranch,
    startedBy: run.startedBy,
    startedAt: run.startedAt,
    finishedAt: run.finishedAt,
    loopRounds: run.loopRounds,
    notes: run.notes,
  );
}

List<Run> _randomRunsOf(Random random, Task task) {
  final int count = random.nextInt(_mostRunsPerTask + 1);
  return <Run>[
    for (int index = 0; index < count; index += 1)
      randomListedRun(random, task, index),
  ];
}

ApprovalRequest _randomPushDecision(Random random, Run run, int index) {
  return ApprovalRequest(
    id: ApprovalId('listed-push-$index'),
    runId: run.id,
    action: PushCommitsAction(
      repository: 'github.com/acme/app',
      branch: 'task/listed-$index',
      commits: const <String>['listed commit'],
    ),
    requestedBy: pickOne(random, shownRunners),
    requestedAt: galleryNow,
    decision: SignedDecision(
      decision: pickOne(random, ApprovalDecision.values),
      decidedBy: GalleryDeviceIds.airLaptop,
      decidedAt: galleryNow,
      signature: const <int>[0],
    ),
  );
}

TasksScene buildTasksScene(Random random, {required int leastTaskCount}) {
  final AppDependencies base = buildGalleryDependencies();
  final int taskCount =
      leastTaskCount + random.nextInt(_mostListedTasks - leastTaskCount + 1);
  final List<Task> allTasks = <Task>[
    for (int index = 0; index < taskCount; index += 1)
      randomListedTask(random, index),
  ];
  final List<Run> runs = <Run>[
    for (final Task task in allTasks) ..._randomRunsOf(random, task),
  ];
  final List<ApprovalRequest> approvals = <ApprovalRequest>[
    for (int index = 0; index < runs.length; index += 1)
      if (random.nextBool()) _randomPushDecision(random, runs[index], index),
  ];
  final FakeTaskRepository tasks = FakeTaskRepository(
    tasks: allTasks,
    runs: runs,
    clock: base.clock,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    workflowRepository: base.workflowRepository as FakeWorkflowRepository,
  );
  tasks.linkPlaces((
    workspaceRepository: base.workspaceRepository,
    projectRepository: base.projectRepository,
  ));
  final AppDependencies dependencies = replaceRepositories(
    base,
    taskRepository: tasks,
    approvalRepository: FakeApprovalRepository(
      approvals: approvals,
      clock: base.clock,
      currentDeviceId: GalleryDeviceIds.airLaptop,
    ),
  );
  return (dependencies: dependencies, tasks: tasks, allTasks: allTasks);
}

Run? findLatestRun(TasksScene scene, Task task) {
  final List<Run> runs = scene.tasks.listRuns(task.id);
  if (runs.isEmpty) {
    return null;
  }
  Run latest = runs.first;
  for (final Run run in runs) {
    if (run.number > latest.number) {
      latest = run;
    }
  }
  return latest;
}
