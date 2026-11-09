import 'dart:math';

import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'project_repositories_editor_inputs.dart';

const int _largestTaskCount = 7;
const int _largestRunsPerTask = 3;

typedef RandomProjectWork = ({List<Task> tasks, List<Run> runs});

Run _buildRun(Random random, TaskId taskId, int number) {
  final Run template = galleryRuns.first;
  return Run(
    id: RunId('${taskId.value}-run-$number'),
    taskId: taskId,
    number: number,
    status: template.status,
    steps: const <RunStep>[],
    log: const <LogLine>[],
    chat: const <ChatMessage>[],
    failure: null,
    link: template.link,
    linkLostAt: null,
    agentSession: null,
    worktreeBranch: null,
    startedBy: template.startedBy,
    startedAt: randomUtcMoment(random),
    finishedAt: null,
    loopRounds: const <LoopRounds>[],
    notes: const <RunNote>[],
  );
}

RandomProjectWork randomProjectWork(Random random) {
  final List<Task> tasks = <Task>[];
  final List<Run> runs = <Run>[];
  for (int index = 0; index < random.nextInt(_largestTaskCount); index += 1) {
    final Task task = Task.fromDraft(
      id: TaskId('task-$index'),
      draft: randomTaskDraft(random),
      schedule: null,
      status: pickOne(random, TaskStatus.values),
      createdAt: randomUtcMoment(random),
    );
    tasks.add(task);
    for (int run = 0; run < random.nextInt(_largestRunsPerTask); run += 1) {
      runs.add(_buildRun(random, task.id, run + 1));
    }
  }
  return (tasks: tasks, runs: runs);
}

Project randomRowsProject(Random random, ProjectId projectId) {
  return Project(
    id: projectId,
    workspaceId: const WorkspaceId('rows'),
    name: 'p${randomHostileText(random)}',
    repositories: <Repository>[
      for (int index = 0; index < random.nextInt(5); index += 1)
        Repository(
          address: '${randomCanonicalHostedAddress(random)}-$index',
          defaultBranch: 'main',
          agentAccess: pickOne(random, AgentAccess.values),
        ),
    ],
    approvalPolicy: null,
  );
}
