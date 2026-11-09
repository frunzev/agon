import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/task_views.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/task_node_reads.dart';

import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import '../fakes/support/workspace_work_rig.dart';
import 'support/simulated_node_replies.dart';
import 'support/simulated_work_node.dart';
import 'support/task_repository_rig.dart';

const int _readIterations = 25;

List<String> _expectedWorkspaceJobIds(WorkspaceWorkRig rig) {
  final WorkspaceId current = rig.workspaces.currentWorkspace().id;
  return <String>[
    for (final WireRecord task in rig.simulated.work.tasks.values)
      if (isJob(task) &&
          rig.simulated.projectWorkspaces[task['project_id']] == current.value)
        task['id']! as String,
  ];
}

List<String> _listJobIds(List<node.JobView> views) {
  return <String>[for (final node.JobView view in views) view.task.id.value];
}

void main() {
  test('test_fetch_current_workspace_job_views_property_no_workspace_asks_'
      'nothing', () async {
    final Random random = seededRandom(112401);
    for (int i = 0; i < _readIterations; i += 1) {
      final SimulatedWorkNode simulated = SimulatedWorkNode(
        thisDeviceId: 'job-reads-device',
      );
      seedTasksWithRuns(random, simulated);
      final NodeCommandChannel channel = buildSimulatedChannel(
        simulated.answer,
      );
      final NodeBackedWorkspaceRepository noWorkspaces =
          NodeBackedWorkspaceRepository(
            channel: channel,
            clock: FixedClock(taskRigMoment),
            retryInterval: const Duration(seconds: 30),
            choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
          );

      final List<node.JobView> views = await fetchCurrentWorkspaceJobViews(
        channel: channel,
        workspaceRepository: noWorkspaces,
      );

      expect(views, isEmpty);
      expect(simulated.receivedCommands, isEmpty);
      noWorkspaces.dispose();
    }
  });

  test('test_fetch_current_workspace_job_views_property_lists_the_current_'
      'workspace_jobs_in_node_order', () async {
    final Random random = seededRandom(112402);
    for (int i = 0; i < _readIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));

      final List<node.JobView> views = await fetchCurrentWorkspaceJobViews(
        channel: buildSimulatedChannel(rig.simulated.answer),
        workspaceRepository: rig.workspaces,
      );

      expect(_listJobIds(views), _expectedWorkspaceJobIds(rig));
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('test_fetch_current_workspace_job_views_property_never_lists_one_'
      'time_tasks', () async {
    final Random random = seededRandom(112403);
    for (int i = 0; i < _readIterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: quietLivePollInterval,
      );
      seedTasksWithRuns(random, rig.node);

      final List<node.JobView> views = await fetchCurrentWorkspaceJobViews(
        channel: buildSimulatedChannel(rig.node.answer),
        workspaceRepository: rig.workspaces,
      );

      for (final String jobId in _listJobIds(views)) {
        expect(isJob(rig.node.tasks[jobId]!), isTrue);
      }
      expect(
        views.length,
        rig.node.tasks.length - listSimulatedOneTimeTaskIds(rig.node).length,
      );
      closeTaskRepositoryRig(rig);
    }
  });
}
