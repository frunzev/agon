import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/run_read_sequence.dart';

import '../../../bridge/support/random_live_json.dart';
import '../../../bridge/support/scripted_node_transport.dart';

const String watchRunCommandName = 'watch_run';
const String stopWatchingRunCommandName = 'stop_watching_run';
const Duration liveWatchPollInterval = Duration(milliseconds: 2);
const String _commandField = 'command';
const String _runIdField = 'run_id';
const String _refusedWatchText = 'the runner refused the live link: busy';
const int _settlingPolls = 6;

typedef LiveWatchExchange = ({String command, String runId});

typedef HandedView = ({String runId, Object? viewJson, int read});

final class LiveWatchNode implements NodeTransport {
  LiveWatchNode({required this.random});

  final Random random;
  final List<LiveWatchExchange> exchanges = <LiveWatchExchange>[];
  final Map<String, List<Object?>> answeredViews = <String, List<Object?>>{};
  final Set<String> refusedRuns = <String>{};
  final Set<String> refusedStops = <String>{};
  final Map<String, int> _pollsInFlight = <String, int>{};
  final List<Completer<void>> _heldPolls = <Completer<void>>[];
  int largestPollsInFlightForOneRun = 0;
  bool isHoldingPolls = false;

  int get heldPollCount => _heldPolls.length;

  void releaseHeldPolls() {
    isHoldingPolls = false;
    for (final Completer<void> held in _heldPolls) {
      held.complete();
    }
    _heldPolls.clear();
  }

  List<String> listCommandRuns(String command) {
    return <String>[
      for (final LiveWatchExchange exchange in exchanges)
        if (exchange.command == command) exchange.runId,
    ];
  }

  @override
  Future<String> exchange({
    required NodeEntryPoint entryPoint,
    required String inputJson,
  }) async {
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    final String name = command[_commandField]! as String;
    final String runId = command[_runIdField]! as String;
    exchanges.add((command: name, runId: runId));
    if (name == stopWatchingRunCommandName) {
      await Future<void>.delayed(Duration.zero);
      return _answerStop(runId);
    }
    return _answerPoll(runId);
  }

  @override
  Future<String> stop() {
    throw UnsupportedError('a live watch node is never stopped');
  }

  String _answerStop(String runId) {
    if (refusedStops.contains(runId)) {
      return encodeErrorReply(_refusedWatchText);
    }
    return encodeSuccessReply(null);
  }

  Future<String> _answerPoll(String runId) async {
    final int inFlight = (_pollsInFlight[runId] ?? 0) + 1;
    _pollsInFlight[runId] = inFlight;
    largestPollsInFlightForOneRun = max(
      largestPollsInFlightForOneRun,
      inFlight,
    );
    try {
      if (isHoldingPolls) {
        final Completer<void> held = Completer<void>();
        _heldPolls.add(held);
        await held.future;
      }
      await Future<void>.delayed(Duration.zero);
      if (refusedRuns.contains(runId)) {
        return encodeErrorReply(_refusedWatchText);
      }
      final Map<String, Object?> viewJson = randomWatchViewJson(random);
      answeredViews.putIfAbsent(runId, () => <Object?>[]).add(viewJson);
      return encodeSuccessReply(viewJson);
    } finally {
      _pollsInFlight[runId] = _pollsInFlight[runId]! - 1;
    }
  }
}

final class LiveWatchRig {
  LiveWatchRig(Random random) : liveNode = LiveWatchNode(random: random) {
    watches = NodeRunWatches(
      channel: NodeCommandChannel(transport: liveNode),
      pollInterval: liveWatchPollInterval,
      runReads: runReads,
      onView: _recordView,
    );
  }

  final LiveWatchNode liveNode;
  final RunReadSequence runReads = RunReadSequence();
  final List<HandedView> handedViews = <HandedView>[];
  late final NodeRunWatches watches;

  void _recordView(RunId runId, node.WatchView view, int read) {
    handedViews.add((runId: runId.value, viewJson: view.toJson(), read: read));
  }

  List<HandedView> listHandedViews(String runId) {
    return <HandedView>[
      for (final HandedView handed in handedViews)
        if (handed.runId == runId) handed,
    ];
  }

  Future<void> settle() async {
    for (int i = 0; i < _settlingPolls; i += 1) {
      await Future<void>.delayed(liveWatchPollInterval);
    }
  }

  Future<Set<String>> listRunsPolledWhileWaiting() async {
    final int exchangesBefore = liveNode.exchanges.length;
    await settle();
    return <String>{
      for (final LiveWatchExchange exchange in liveNode.exchanges.skip(
        exchangesBefore,
      ))
        if (exchange.command == watchRunCommandName) exchange.runId,
    };
  }
}

String randomLiveRunId(Random random, {required int runCount}) {
  return 'live-run-${random.nextInt(runCount)}';
}
