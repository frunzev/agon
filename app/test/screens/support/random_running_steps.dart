import 'dart:math';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../support/random_inputs.dart';
import '../../support/workflow_repositories.dart';

const List<DeviceId> stepRunnerIds = <DeviceId>[
  GalleryDeviceIds.airLaptop,
  GalleryDeviceIds.macStudio,
  GalleryDeviceIds.officeServer,
  GalleryDeviceIds.gpuBox,
];
const int _largestStepAgeMinutes = 600;

DateTime? _randomStepStart(Random random) {
  if (random.nextInt(4) == 0) {
    return null;
  }
  final int ageMinutes = random.nextInt(_largestStepAgeMinutes) - 5;
  return galleryNow.subtract(Duration(minutes: ageMinutes));
}

RunStep _scatterStep(Random random, RunStep step) {
  final bool isRunning = random.nextBool();

  return RunStep(
    name: step.name,
    agentId: step.agentId,
    runner: random.nextInt(5) == 0 ? null : pickOne(random, stepRunnerIds),
    status: isRunning
        ? StepStatus.running
        : pickOne(random, StepStatus.values),
    startedAt: _randomStepStart(random),
    finishedAt: step.finishedAt,
    result: step.result,
    outcome: step.outcome,
    loopSource: step.loopSource,
    earlierRounds: step.earlierRounds,
  );
}

Run _moveRunToJob(Run run, Task job) {
  return Run(
    id: RunId('${job.id.value}-run'),
    taskId: job.id,
    number: run.number,
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

List<Run> _listTaskAndJobRuns() {
  return <Run>[
    ...galleryRuns,
    for (final Task job in galleryJobs) _moveRunToJob(galleryRunningRun, job),
  ];
}

List<Run> scatterGalleryRunSteps(Random random) {
  final List<Run> runs = <Run>[];

  for (final Run run in _listTaskAndJobRuns()) {
    final List<RunStep> steps = <RunStep>[
      for (final RunStep step in run.steps) _scatterStep(random, step),
    ];
    runs.add(
      run.withProgress(
        nextStatus: run.status,
        nextSteps: steps,
        nextFinishedAt: run.finishedAt,
      ),
    );
  }

  return runs;
}

FakeTaskRepository buildTaskRepositoryWithRuns(List<Run> runs) {
  return FakeTaskRepository(
    tasks: <Task>[...galleryTasks, ...galleryJobs],
    runs: runs,
    clock: FixedClock(galleryNow),
    currentDeviceId: GalleryDeviceIds.airLaptop,
    workflowRepository: buildGalleryWorkflowRepository(),
  );
}

FakeJobRepository buildJobRepositoryOver(FakeTaskRepository tasks) {
  return FakeJobRepository(
    taskRepository: tasks,
    clock: FixedClock(galleryNow),
  );
}
