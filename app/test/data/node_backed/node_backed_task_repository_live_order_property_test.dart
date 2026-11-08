import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../bridge/support/node_wire_names.dart';
import '../../bridge/support/random_run_json.dart';
import '../../support/random_inputs.dart';
import 'support/held_next_reply_transport.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_work_node.dart';
import 'support/task_repository_rig.dart';

const int _iterations = 20;
const int _largestLiveLineCount = 5;
const int _waitLimit = 400;
const Duration _waitStep = Duration(milliseconds: 1);
const String _showRunCommand = 'show_run';
const String _watchRunCommand = 'watch_run';
const String _finishedRunStatus = 'done';

typedef _LiveRig = ({
  SimulatedWorkNode node,
  HeldNextReplyTransport transport,
  NodeBackedJobRepository jobs,
  NodeBackedTaskRepository tasks,
  String taskId,
  RunId runId,
});

Future<_LiveRig> _openLiveRig(
  Random random, {
  required Duration livePollInterval,
}) async {
  final SimulatedWorkNode simulated = SimulatedWorkNode(
    thisDeviceId: 'live-device',
  );
  final String taskId = addOneTimeTaskElsewhere(random, simulated);
  final String runId = simulated.addRunFromElsewhere(random, taskId);
  simulated.runs[runId]!['status'] = _finishedRunStatus;
  final HeldNextReplyTransport transport = HeldNextReplyTransport(
    answer: simulated.answer,
  );
  final NodeCommandChannel channel = NodeCommandChannel(transport: transport);
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
    livePollInterval: livePollInterval,
  );
  await jobs.load();
  await tasks.load();
  return (
    node: simulated,
    transport: transport,
    jobs: jobs,
    tasks: tasks,
    taskId: taskId,
    runId: RunId(runId),
  );
}

Map<String, Object?> _buildLiveLine(Random random, String text) {
  final Map<String, Object?> line = randomLogLineJson(random);
  line['text'] = text;
  return <String, Object?>{'kind': 'log_appended', 'line': line};
}

bool _showsLine(_LiveRig rig, String text) {
  final Run run = rig.tasks.findRun(rig.runId);
  return run.log.any((LogLine line) => line.text == text);
}

Future<void> _waitUntil(bool Function() isReached) async {
  for (int i = 0; i < _waitLimit; i += 1) {
    if (isReached()) {
      return;
    }
    await Future<void>.delayed(_waitStep);
  }
  fail('the live polling did not reach the expected point in time');
}

Future<void> _settle() async {
  for (int i = 0; i < 5; i += 1) {
    await Future<void>.delayed(_waitStep);
  }
}

void _closeLiveRig(_LiveRig rig) {
  rig.tasks.dispose();
  rig.jobs.dispose();
}

RunnerLink _mapLinkWireName(String wireName) {
  final node.RunnerLink link = node.RunnerLink.values.firstWhere(
    (node.RunnerLink candidate) => candidate.wireName == wireName,
  );
  return mapRunnerLinkFromNode(link);
}

({String older, String newer}) _pickTwoLinks(Random random) {
  final List<String> links = List<String>.of(nodeRunnerLinks)..shuffle(random);
  return (older: links[0], newer: links[1]);
}

Future<void> _holdShowRunThenPoll(Random random, _LiveRig rig) async {
  final String liveText = 'live-${randomText(random)}';
  rig.transport.holdNextReply(_showRunCommand);
  final Future<Run> refreshing = rig.tasks.refreshRun(rig.runId);
  await rig.transport.heldReplyArrival;
  rig.node.liveEvents[rig.runId.value] = <Map<String, Object?>>[
    _buildLiveLine(random, liveText),
  ];

  rig.tasks.watchRun(rig.runId);
  await _waitUntil(() => _showsLine(rig, liveText));
  rig.transport.releaseHeldReply();
  await refreshing;

  expect(_showsLine(rig, liveText), isTrue);
  rig.tasks.stopWatchingRun(rig.runId);
}

Future<void> _holdPollThenShowRun(Random random, _LiveRig rig) async {
  final ({String older, String newer}) links = _pickTwoLinks(random);
  rig.node.liveLinks[rig.runId.value] = links.older;
  rig.transport.holdNextReply(_watchRunCommand);
  rig.tasks.watchRun(rig.runId);
  await rig.transport.heldReplyArrival;
  rig.node.runs[rig.runId.value]!['link'] = links.newer;

  await rig.tasks.refreshRun(rig.runId);
  rig.transport.releaseHeldReply();
  await _settle();

  final RunnerLink shown = rig.tasks.findRun(rig.runId).link;
  expect(shown, _mapLinkWireName(links.newer));
  rig.tasks.stopWatchingRun(rig.runId);
}

void main() {
  test('test_apply_live_view_property_a_late_show_run_keeps_the_newer_live_'
      'events', () async {
    final Random random = seededRandom(90501);
    for (int i = 0; i < _iterations; i += 1) {
      final _LiveRig rig = await _openLiveRig(
        random,
        livePollInterval: quietLivePollInterval,
      );

      await _holdShowRunThenPoll(random, rig);
      _closeLiveRig(rig);
    }
  });

  test('test_apply_live_view_property_a_late_live_view_keeps_the_newer_show_'
      'run', () async {
    final Random random = seededRandom(90502);
    for (int i = 0; i < _iterations; i += 1) {
      final _LiveRig rig = await _openLiveRig(
        random,
        livePollInterval: quietLivePollInterval,
      );

      await _holdPollThenShowRun(random, rig);
      _closeLiveRig(rig);
    }
  });

  test('test_apply_live_view_property_a_late_view_of_a_deleted_run_is_'
      'ignored', () async {
    final Random random = seededRandom(90503);
    for (int i = 0; i < _iterations; i += 1) {
      final _LiveRig rig = await _openLiveRig(
        random,
        livePollInterval: quietLivePollInterval,
      );
      rig.node.liveEvents[rig.runId.value] = <Map<String, Object?>>[
        _buildLiveLine(random, 'late-${randomText(random)}'),
      ];
      rig.transport.holdNextReply(_watchRunCommand);
      rig.tasks.watchRun(rig.runId);
      await rig.transport.heldReplyArrival;

      await rig.tasks.deleteTask(TaskId(rig.taskId));
      rig.transport.releaseHeldReply();
      await _settle();

      expect(
        () => rig.tasks.findRun(rig.runId),
        throwsA(isA<RecordNotFound>()),
      );
      rig.tasks.stopWatchingRun(rig.runId);
      _closeLiveRig(rig);
    }
  });

  test('test_follow_run_property_in_order_polls_apply_every_live_'
      'event', () async {
    final Random random = seededRandom(90504);
    for (int i = 0; i < _iterations; i += 1) {
      final _LiveRig rig = await _openLiveRig(
        random,
        livePollInterval: Duration.zero,
      );
      final int lineCount = 1 + random.nextInt(_largestLiveLineCount);
      final List<String> texts = <String>[
        for (int line = 0; line < lineCount; line += 1)
          'live-$line-${randomText(random)}',
      ];
      rig.tasks.watchRun(rig.runId);

      for (final String text in texts) {
        rig.node.liveEvents[rig.runId.value] = <Map<String, Object?>>[
          _buildLiveLine(random, text),
        ];
        await _waitUntil(() => _showsLine(rig, text));
      }

      for (final String text in texts) {
        expect(_showsLine(rig, text), isTrue);
      }
      rig.tasks.stopWatchingRun(rig.runId);
      _closeLiveRig(rig);
    }
  });

  test('test_follow_run_property_the_newest_sent_read_wins_either_'
      'way', () async {
    final Random random = seededRandom(90505);
    for (int i = 0; i < _iterations; i += 1) {
      final _LiveRig rig = await _openLiveRig(
        random,
        livePollInterval: quietLivePollInterval,
      );

      if (random.nextBool()) {
        await _holdShowRunThenPoll(random, rig);
      } else {
        await _holdPollThenShowRun(random, rig);
      }
      _closeLiveRig(rig);
    }
  });

  test('test_follow_run_property_a_poll_held_past_stop_watching_changes_'
      'nothing', () async {
    final Random random = seededRandom(90506);
    for (int i = 0; i < _iterations; i += 1) {
      final _LiveRig rig = await _openLiveRig(
        random,
        livePollInterval: quietLivePollInterval,
      );
      final String liveText = 'stopped-${randomText(random)}';
      rig.node.liveEvents[rig.runId.value] = <Map<String, Object?>>[
        _buildLiveLine(random, liveText),
      ];
      rig.transport.holdNextReply(_watchRunCommand);
      rig.tasks.watchRun(rig.runId);
      await rig.transport.heldReplyArrival;
      final Run before = rig.tasks.findRun(rig.runId);

      rig.tasks.stopWatchingRun(rig.runId);
      rig.transport.releaseHeldReply();
      await _settle();

      expect(rig.tasks.findRun(rig.runId), same(before));
      expect(_showsLine(rig, liveText), isFalse);
      _closeLiveRig(rig);
    }
  });
}
