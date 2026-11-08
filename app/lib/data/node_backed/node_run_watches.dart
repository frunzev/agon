import 'dart:async';

import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/live_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/run_read_sequence.dart';

typedef LiveRunViewHandler = void Function(
  RunId runId,
  node.WatchView view,
  int read,
);

final class NodeRunWatches {
  NodeRunWatches({
    required NodeCommandChannel channel,
    required Duration pollInterval,
    required RunReadSequence runReads,
    required LiveRunViewHandler onView,
  }) : _channel = channel,
       _pollInterval = pollInterval,
       _runReads = runReads,
       _onView = onView;

  final NodeCommandChannel _channel;
  final Duration _pollInterval;
  final RunReadSequence _runReads;
  final LiveRunViewHandler _onView;
  final Map<RunId, int> _watcherCounts = <RunId, int>{};
  final Set<RunId> _followedRuns = <RunId>{};

  void watch(RunId runId) {
    final int watchers = _watcherCounts[runId] ?? 0;
    _watcherCounts[runId] = watchers + 1;
    final bool isNewlyFollowed = _followedRuns.add(runId);
    if (isNewlyFollowed) {
      unawaited(_followRun(runId));
    }
  }

  void stopWatching(RunId runId) {
    final int watchers = _watcherCounts[runId] ?? 0;
    if (watchers > 1) {
      _watcherCounts[runId] = watchers - 1;
      return;
    }
    _watcherCounts.remove(runId);
    unawaited(_sendStop(runId));
  }

  void stopAll() {
    final List<RunId> watchedRuns = List<RunId>.of(_watcherCounts.keys);
    _watcherCounts.clear();
    for (final RunId runId in watchedRuns) {
      unawaited(_sendStop(runId));
    }
  }

  Future<void> _followRun(RunId runId) async {
    while (_watcherCounts.containsKey(runId)) {
      final int read = _runReads.startRead();
      final node.WatchView? view = await _readLiveView(runId);
      if (view != null && _watcherCounts.containsKey(runId)) {
        _onView(runId, view, read);
      }
      await Future<void>.delayed(_pollInterval);
    }
    _followedRuns.remove(runId);
  }

  Future<node.WatchView?> _readLiveView(RunId runId) async {
    try {
      return await _channel.execute(node.WatchRunCommand(runId: runId));
    } on NodeCommandFailure catch (failure, stackTrace) {
      logLiveRunProblem(failure, stackTrace);
      return null;
    }
  }

  Future<void> _sendStop(RunId runId) async {
    try {
      await _channel.execute(node.StopWatchingRunCommand(runId: runId));
    } on NodeCommandFailure catch (failure, stackTrace) {
      logLiveRunProblem(failure, stackTrace);
    }
  }
}
