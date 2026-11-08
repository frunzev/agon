import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_node_replies.dart';
import 'support/task_repository_rig.dart';

const String _typePrefix = 'test_node_backed_task_repository_constructor';
const String _watchCommand = 'watch_run';
const int _iterations = 20;
const int _settleTurns = 5;
const Duration _settleStep = Duration(milliseconds: 1);

Future<void> _settle() async {
  for (int i = 0; i < _settleTurns; i += 1) {
    await Future<void>.delayed(_settleStep);
  }
}

void main() {
  test('${_typePrefix}_property_starts_empty_and_asks_the_node_'
      'nothing', () async {
    final Random random = seededRandom(91201);
    for (int i = 0; i < _iterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: quietLivePollInterval,
      );
      seedTasksWithRuns(random, rig.node);
      await _settle();

      expect(rig.tasks.listTasks(), isEmpty);
      expect(
        () => rig.tasks.findRun(RunId('run-${randomText(random)}')),
        throwsA(isA<RecordNotFound>()),
      );
      expect(rig.node.receivedCommands, isEmpty);
      closeTaskRepositoryRig(rig);
    }
  });

  test('${_typePrefix}_property_follows_a_workspace_switch_without_a_'
      'load', () async {
    final Random random = seededRandom(91202);
    for (int i = 0; i < _iterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: quietLivePollInterval,
      );
      seedTasksWithRuns(random, rig.node);

      await rig.workspaces.switchWorkspace(harnessWorkspaceId);
      await _settle();

      final Set<String> shown = <String>{
        for (final Task task in rig.tasks.listTasks()) task.id.value,
      };
      expect(shown, listSimulatedOneTimeTaskIds(rig.node).toSet());
      closeTaskRepositoryRig(rig);
    }
  });

  test('${_typePrefix}_property_a_first_watch_polls_once_right_'
      'away', () async {
    final Random random = seededRandom(91203);
    for (int i = 0; i < _iterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: quietLivePollInterval,
      );
      final RunId runId = RunId('run-${randomText(random)}');

      rig.tasks.watchRun(runId);
      await _settle();

      expect(
        countReceivedCommands(rig.node.receivedCommands, _watchCommand),
        1,
      );
      rig.tasks.stopWatchingRun(runId);
      closeTaskRepositoryRig(rig);
    }
  });
}
