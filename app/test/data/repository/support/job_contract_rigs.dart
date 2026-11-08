import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/job_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../../support/random_inputs.dart';
import '../../fakes/support/job_inputs.dart';
import '../../fakes/support/workspace_work_rig.dart';
import '../../fakes/support/workspace_work_steps.dart';
import 'contract_step_failures.dart';

const String jobKind = 'job';
const int jobSequenceIterations = 20;
const int _longestSequence = 6;
const List<WorkRigStep> _jobRigSteps = <WorkRigStep>[
  createJobInBoth,
  updateJobInBoth,
  deleteJobInBoth,
  switchWorkRigWorkspace,
];

typedef NamedJobRepository = ({
  String name,
  JobRepository repository,
  TaskId Function(TaskId fakeId) translate,
});

typedef JobStepOutcome = ({String name, Object? failure});

TaskId _keepIdentifier(TaskId fakeId) => fakeId;

List<NamedJobRepository> listJobImplementations(WorkspaceWorkRig rig) {
  return <NamedJobRepository>[
    (name: 'fake', repository: rig.fakeJobs, translate: _keepIdentifier),
    (
      name: 'node backed',
      repository: rig.nodeJobs,
      translate: (TaskId fakeId) => findNodeIdOf(rig, fakeId),
    ),
  ];
}

Future<WorkspaceWorkRig> buildJobRigAfterRandomSteps(Random random) async {
  final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
  final int stepCount = random.nextInt(_longestSequence);
  for (int step = 0; step < stepCount; step += 1) {
    final WorkRigStep chosen = pickOne(random, _jobRigSteps);
    await chosen(random, rig);
  }
  return rig;
}

TaskId? pickListedJobId(Random random, WorkspaceWorkRig rig) {
  final List<Task> jobs = rig.fakeJobs.listJobs();
  if (jobs.isEmpty) {
    return null;
  }
  return pickOne(random, jobs).id;
}

List<String> describeListedJobs(JobRepository repository) {
  return <String>[
    for (final Task job in repository.listJobs()) describeJobContent(job),
  ];
}

List<String> listJobIdentifiers(JobRepository repository) {
  return <String>[for (final Task job in repository.listJobs()) job.id.value];
}

Set<ProjectId> listCurrentProjectIds(WorkspaceWorkRig rig) {
  final WorkspaceId current = rig.workspaces.currentWorkspace().id;
  return <ProjectId>{
    for (final Project project in rig.projects)
      if (project.workspaceId == current) project.id,
  };
}

List<TaskId> listStoredPlainTaskIds(WorkspaceWorkRig rig) {
  return <TaskId>[
    for (final Task task in rig.fakeTasks.listTasksAndJobs())
      if (task.schedule == null) task.id,
  ];
}

Future<List<JobStepOutcome>> runOnEveryJobRepository(
  WorkspaceWorkRig rig,
  Future<Object?> Function(NamedJobRepository implementation) step,
) async {
  final List<JobStepOutcome> outcomes = <JobStepOutcome>[];
  for (final NamedJobRepository implementation in listJobImplementations(
    rig,
  )) {
    final Object? failure = await findStepFailure(() => step(implementation));
    outcomes.add((name: implementation.name, failure: failure));
  }
  return outcomes;
}

void expectEveryJobStepRefused(List<JobStepOutcome> outcomes) {
  for (final JobStepOutcome outcome in outcomes) {
    final bool isExpectedRefusal =
        isContractRefusal(outcome.failure) ||
        outcome.failure is RecordNotFound;
    expect(isExpectedRefusal, isTrue, reason: '${outcome.name}: $outcome');
  }
}

void expectSameJobStepOutcome(List<JobStepOutcome> outcomes) {
  final bool isFirstRefused = outcomes.first.failure != null;
  for (final JobStepOutcome outcome in outcomes) {
    expect(
      outcome.failure != null,
      isFirstRefused,
      reason: '${outcome.name}: ${outcome.failure}',
    );
  }
}

void expectJobListingsAgree(WorkspaceWorkRig rig) {
  final List<NamedJobRepository> implementations = listJobImplementations(rig);
  final List<String> expected = describeListedJobs(
    implementations.first.repository,
  );
  for (final NamedJobRepository implementation in implementations) {
    expect(
      describeListedJobs(implementation.repository),
      unorderedEquals(expected),
      reason: implementation.name,
    );
  }
}
