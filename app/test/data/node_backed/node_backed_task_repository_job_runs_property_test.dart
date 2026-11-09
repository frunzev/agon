import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../bridge/support/random_work_json.dart';
import '../../support/random_inputs.dart';
import 'support/held_next_reply_transport.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_work_node.dart';
import 'support/task_repository_rig.dart';

const int _rigIterations = 25;
const int _largestJobCount = 4;
const int _largestRunsPerJob = 3;

List<String> _seedJobsWithRuns(Random random, SimulatedWorkNode simulated) {
  final int jobCount = 1 + random.nextInt(_largestJobCount);
  final List<String> jobIds = <String>[];
  for (int job = 0; job < jobCount; job += 1) {
    final String jobId = simulated.addTaskFromElsewhere(random);
    simulated.tasks[jobId]!['schedule'] = randomScheduleJson(random);
    final int runCount = random.nextInt(_largestRunsPerJob + 1);
    for (int run = 0; run < runCount; run += 1) {
      simulated.addRunFromElsewhere(random, jobId);
    }
    jobIds.add(jobId);
  }
  return jobIds;
}

List<int> _listRunNumbers(List<Run> runs) {
  return <int>[for (final Run run in runs) run.number];
}

void main() {
  test(
    'test_node_backed_task_repository_load_property_lists_job_runs',
    () async {
      final Random random = seededRandom(112301);

      for (int i = 0; i < _rigIterations; i += 1) {
        final TaskRepositoryRig rig = openTaskRepositoryRig(
          livePollInterval: quietLivePollInterval,
        );
        seedTasksWithRuns(random, rig.node);
        final List<String> jobIds = _seedJobsWithRuns(random, rig.node);

        await rig.tasks.load();

        for (final String jobId in jobIds) {
          final List<Run> listed = rig.tasks.listRuns(TaskId(jobId));
          final Set<String> listedIds = <String>{
            for (final Run run in listed) run.id.value,
          };
          final List<int> numbers = _listRunNumbers(listed);
          final List<int> newestFirst = List<int>.of(numbers)
            ..sort((int first, int second) => second - first);
          expect(listedIds, listSimulatedRunIdsOf(rig.node, TaskId(jobId)));
          expect(numbers, newestFirst);
        }
        closeTaskRepositoryRig(rig);
      }
    },
  );

  test(
    'test_node_backed_task_repository_load_property_finds_every_run',
    () async {
      final Random random = seededRandom(112302);

      for (int i = 0; i < _rigIterations; i += 1) {
        final TaskRepositoryRig rig = openTaskRepositoryRig(
          livePollInterval: quietLivePollInterval,
        );
        seedTasksWithRuns(random, rig.node);
        _seedJobsWithRuns(random, rig.node);

        await rig.tasks.load();

        expect(rig.jobs.listJobs(), isEmpty);
        for (final String runId in rig.node.runs.keys) {
          final Run run = rig.tasks.findRun(RunId(runId));
          expect(run.taskId.value, rig.node.runs[runId]!['task_id']);
        }
        closeTaskRepositoryRig(rig);
      }
    },
  );

  test('test_node_backed_task_repository_load_property_late_job_listing_'
      'keeps_the_newer_run', () async {
    final Random random = seededRandom(112303);

    for (int i = 0; i < _rigIterations; i += 1) {
      final SimulatedWorkNode simulated = SimulatedWorkNode(
        thisDeviceId: 'job-device',
      );
      final String jobId = _seedJobsWithRuns(random, simulated).first;
      final String runId = simulated.addRunFromElsewhere(random, jobId);
      final HeldNextReplyTransport transport = HeldNextReplyTransport(
        answer: simulated.answer,
      );
      final NodeCommandChannel channel = NodeCommandChannel(
        transport: transport,
      );
      final WorkspaceRepository workspaces = buildSingleWorkspaceRepository();
      final NodeBackedJobRepository jobs = NodeBackedJobRepository(
        channel: channel,
        workspaceRepository: workspaces,
        clock: FixedClock(taskRigMoment),
      );
      final NodeBackedTaskRepository tasks = buildRigTaskRepository(
        channel: channel,
        workspaces: workspaces,
        jobs: jobs,
        livePollInterval: quietLivePollInterval,
      );
      simulated.runs[runId]!['status'] = 'running';
      transport.holdNextReply('list_runs');

      final Future<void> loading = tasks.load();
      await transport.heldReplyArrival;
      simulated.runs[runId]!['status'] = 'done';
      await tasks.refreshRun(RunId(runId));
      transport.releaseHeldReply();
      await loading;

      expect(tasks.findRun(RunId(runId)).status, RunStatus.done);
      tasks.dispose();
      jobs.dispose();
    }
  });
}
