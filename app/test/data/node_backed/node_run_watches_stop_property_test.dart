import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import 'support/live_watch_node.dart';

const int _iterations = 20;
const int _largestWatcherCount = 4;
const int _largestRunCount = 4;
const int _largestCycleCount = 4;
const int _largestRunIdNumber = 9;

List<RunId> _randomRunIds(Random random) {
  final int runCount = 1 + random.nextInt(_largestRunCount);
  return <RunId>[for (int i = 0; i < runCount; i += 1) RunId('live-run-$i')];
}

void main() {
  test('test_stop_watching_property_only_the_last_watcher_sends_one_'
      'stop', () async {
    final Random random = seededRandom(96201);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      const RunId runId = RunId('live-run-0');
      final int watcherCount = 1 + random.nextInt(_largestWatcherCount);

      for (int j = 0; j < watcherCount; j += 1) {
        rig.watches.watch(runId);
      }
      for (int j = 1; j < watcherCount; j += 1) {
        rig.watches.stopWatching(runId);
      }
      final Set<String> polledBeforeLastStop = await rig
          .listRunsPolledWhileWaiting();
      final List<String> stopsBeforeLastStop = rig.liveNode.listCommandRuns(
        stopWatchingRunCommandName,
      );
      rig.watches.stopWatching(runId);
      await rig.settle();

      expect(polledBeforeLastStop, <String>{runId.value});
      expect(stopsBeforeLastStop, isEmpty);
      expect(
        rig.liveNode.listCommandRuns(stopWatchingRunCommandName),
        <String>[runId.value],
      );
      expect(await rig.listRunsPolledWhileWaiting(), isEmpty);
    }
  });

  test('test_stop_watching_property_no_view_arrives_after_the_last_'
      'stop', () async {
    final Random random = seededRandom(96202);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      const RunId runId = RunId('live-run-0');

      rig.watches.watch(runId);
      await rig.settle();
      rig.liveNode.isHoldingPolls = true;
      await rig.settle();
      final int handedBeforeStop = rig.handedViews.length;
      rig.watches.stopWatching(runId);
      rig.liveNode.releaseHeldPolls();
      await rig.settle();

      expect(rig.handedViews, hasLength(handedBeforeStop));
      expect(await rig.listRunsPolledWhileWaiting(), isEmpty);
    }
  });

  test('test_stop_watching_property_stopping_one_run_keeps_the_others_'
      'polled', () async {
    final Random random = seededRandom(96203);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      final List<RunId> runIds = _randomRunIds(random);
      final RunId stoppedRun = pickOne(random, runIds);

      for (final RunId runId in runIds) {
        rig.watches.watch(runId);
      }
      await rig.settle();
      rig.watches.stopWatching(stoppedRun);
      await rig.settle();

      final Set<String> expectedPolled = <String>{
        for (final RunId runId in runIds)
          if (runId != stoppedRun) runId.value,
      };
      expect(await rig.listRunsPolledWhileWaiting(), expectedPolled);
      rig.watches.stopAll();
    }
  });

  test('test_stop_all_property_nothing_is_polled_or_handed_after_'
      'it', () async {
    final Random random = seededRandom(96204);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      final List<RunId> runIds = _randomRunIds(random);

      for (final RunId runId in runIds) {
        rig.watches.watch(runId);
      }
      await rig.settle();
      rig.liveNode.isHoldingPolls = true;
      await rig.settle();
      final int handedBeforeStop = rig.handedViews.length;
      rig.watches.stopAll();
      rig.liveNode.releaseHeldPolls();
      await rig.settle();

      expect(rig.handedViews, hasLength(handedBeforeStop));
      expect(await rig.listRunsPolledWhileWaiting(), isEmpty);
    }
  });

  test('test_stop_all_property_tells_the_node_to_stop_each_watched_run_'
      'once', () async {
    final Random random = seededRandom(96205);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      final List<RunId> runIds = _randomRunIds(random);

      for (final RunId runId in runIds) {
        final int watcherCount = 1 + random.nextInt(_largestWatcherCount);
        for (int j = 0; j < watcherCount; j += 1) {
          rig.watches.watch(runId);
        }
      }
      rig.watches.stopAll();
      await rig.settle();

      final List<String> stoppedRuns = rig.liveNode.listCommandRuns(
        stopWatchingRunCommandName,
      );
      expect(stoppedRuns.toSet(), <String>{
        for (final RunId runId in runIds) runId.value,
      });
      expect(stoppedRuns, hasLength(runIds.length));
    }
  });

  test('test_stop_all_property_watching_again_polls_with_one_'
      'follower', () async {
    final Random random = seededRandom(96206);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      const RunId runId = RunId('live-run-0');

      rig.liveNode.isHoldingPolls = true;
      rig.watches.watch(runId);
      await Future<void>.delayed(Duration.zero);
      rig.watches.stopAll();
      rig.watches.watch(runId);
      await Future<void>.delayed(Duration.zero);
      rig.liveNode.releaseHeldPolls();
      await rig.settle();

      expect(await rig.listRunsPolledWhileWaiting(), <String>{runId.value});
      expect(rig.liveNode.largestPollsInFlightForOneRun, 1);
      rig.watches.stopAll();
    }
  });

  test('test_send_stop_property_each_watch_period_ends_with_one_stop_for_'
      'its_run', () async {
    final Random random = seededRandom(96207);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      final RunId runId = RunId(
        'live-run-${random.nextInt(_largestRunIdNumber)}',
      );
      final int cycleCount = 1 + random.nextInt(_largestCycleCount);

      for (int cycle = 0; cycle < cycleCount; cycle += 1) {
        rig.watches.watch(runId);
        await Future<void>.delayed(liveWatchPollInterval);
        rig.watches.stopWatching(runId);
      }
      await rig.settle();

      expect(
        rig.liveNode.listCommandRuns(stopWatchingRunCommandName),
        List<String>.filled(cycleCount, runId.value),
      );
    }
  });

  test('test_send_stop_property_a_refused_stop_is_swallowed_and_stays_'
      'stopped', () async {
    final Random random = seededRandom(96208);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      const RunId runId = RunId('live-run-0');

      rig.liveNode.refusedStops.add(runId.value);
      rig.watches.watch(runId);
      await rig.settle();
      rig.watches.stopWatching(runId);
      await rig.settle();

      expect(
        rig.liveNode.listCommandRuns(stopWatchingRunCommandName),
        <String>[runId.value],
      );
      expect(await rig.listRunsPolledWhileWaiting(), isEmpty);
    }
  });

  test('test_send_stop_property_a_refused_stop_leaves_other_runs_'
      'polled', () async {
    final Random random = seededRandom(96209);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      final List<RunId> runIds = _randomRunIds(random);
      final RunId stoppedRun = pickOne(random, runIds);

      rig.liveNode.refusedStops.add(stoppedRun.value);
      for (final RunId runId in runIds) {
        rig.watches.watch(runId);
      }
      rig.watches.stopWatching(stoppedRun);
      await rig.settle();

      final Set<String> expectedPolled = <String>{
        for (final RunId runId in runIds)
          if (runId != stoppedRun) runId.value,
      };
      expect(await rig.listRunsPolledWhileWaiting(), expectedPolled);
      rig.watches.stopAll();
    }
  });
}
