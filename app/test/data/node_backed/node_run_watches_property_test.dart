import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import 'support/live_watch_node.dart';

const int _iterations = 20;
const int _largestRunCount = 3;
const int _largestStepCount = 14;

Object? _normalizeViewJson(Object? viewJson) {
  return node.WatchView.fromJson(viewJson).toJson();
}

void main() {
  test('test_node_run_watches_constructor_property_contacts_nobody_'
      'before_a_watch', () async {
    final Random random = seededRandom(96101);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);

      await rig.settle();

      expect(rig.liveNode.exchanges, isEmpty);
      expect(rig.handedViews, isEmpty);
    }
  });

  test('test_node_run_watches_constructor_property_reads_come_from_the_'
      'given_sequence', () async {
    final Random random = seededRandom(96102);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      final int readBeforeWatching = rig.runReads.startRead();
      const RunId runId = RunId('live-run-0');

      rig.watches.watch(runId);
      await rig.settle();
      rig.watches.stopWatching(runId);
      final int readAfterWatching = rig.runReads.startRead();

      expect(rig.handedViews, isNotEmpty);
      for (final HandedView handed in rig.handedViews) {
        expect(handed.read, greaterThan(readBeforeWatching));
        expect(handed.read, lessThan(readAfterWatching));
      }
    }
  });

  test('test_node_run_watches_constructor_property_polls_one_run_no_faster_'
      'than_the_interval', () async {
    final Random random = seededRandom(96103);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      const RunId runId = RunId('live-run-0');
      final Stopwatch stopwatch = Stopwatch()..start();

      rig.watches.watch(runId);
      await rig.settle();
      rig.watches.stopWatching(runId);
      final Duration watchedFor = stopwatch.elapsed;

      final int polls = rig.liveNode
          .listCommandRuns(watchRunCommandName)
          .length;
      final int mostPolls =
          1 +
          watchedFor.inMicroseconds ~/ liveWatchPollInterval.inMicroseconds;
      expect(polls, greaterThan(0));
      expect(polls, lessThanOrEqualTo(mostPolls));
    }
  });

  test('test_watch_property_matches_a_counting_model', () async {
    final Random random = seededRandom(96104);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      final Map<String, int> modelCounts = <String, int>{};
      final List<String> expectedStops = <String>[];
      final int stepCount = 1 + random.nextInt(_largestStepCount);

      for (int step = 0; step < stepCount; step += 1) {
        final String runId = randomLiveRunId(
          random,
          runCount: _largestRunCount,
        );
        final int count = modelCounts[runId] ?? 0;
        if (count > 0 && random.nextBool()) {
          rig.watches.stopWatching(RunId(runId));
          modelCounts[runId] = count - 1;
          if (count == 1) {
            expectedStops.add(runId);
          }
        } else {
          rig.watches.watch(RunId(runId));
          modelCounts[runId] = count + 1;
        }
        await Future<void>.delayed(Duration.zero);
      }
      await rig.settle();

      final Set<String> watchedRuns = <String>{
        for (final MapEntry<String, int> entry in modelCounts.entries)
          if (entry.value > 0) entry.key,
      };
      expect(await rig.listRunsPolledWhileWaiting(), watchedRuns);
      expect(
        rig.liveNode.listCommandRuns(stopWatchingRunCommandName),
        expectedStops,
      );
      for (final String runId in watchedRuns) {
        rig.watches.stopWatching(RunId(runId));
      }
      rig.watches.stopAll();
    }
  });

  test('test_watch_property_one_poll_per_run_even_when_watched_again_'
      'mid_poll', () async {
    final Random random = seededRandom(96105);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      const RunId runId = RunId('live-run-0');
      final int rewatchCount = 1 + random.nextInt(_largestRunCount);

      rig.liveNode.isHoldingPolls = true;
      rig.watches.watch(runId);
      await Future<void>.delayed(Duration.zero);
      for (int j = 0; j < rewatchCount; j += 1) {
        rig.watches.stopWatching(runId);
        rig.watches.watch(runId);
        await Future<void>.delayed(Duration.zero);
      }
      rig.liveNode.releaseHeldPolls();
      await rig.settle();
      rig.watches.stopWatching(runId);
      await rig.settle();

      final List<HandedView> handed = rig.listHandedViews(runId.value);
      final int answeredCount =
          rig.liveNode.answeredViews[runId.value]?.length ?? 0;
      expect(rig.liveNode.largestPollsInFlightForOneRun, 1);
      expect(handed.length, lessThanOrEqualTo(answeredCount));
      for (int j = 1; j < handed.length; j += 1) {
        expect(handed[j].read, greaterThan(handed[j - 1].read));
      }
    }
  });

  test('test_watch_property_every_answered_view_reaches_the_handler_in_'
      'order', () async {
    final Random random = seededRandom(96106);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      final String runId = randomLiveRunId(random, runCount: _largestRunCount);

      rig.watches.watch(RunId(runId));
      await rig.settle();
      rig.liveNode.isHoldingPolls = true;
      await rig.settle();
      final List<Object?> answered = <Object?>[
        for (final Object? viewJson in rig.liveNode.answeredViews[runId]!)
          _normalizeViewJson(viewJson),
      ];
      final List<HandedView> handed = rig.listHandedViews(runId);
      rig.watches.stopWatching(RunId(runId));
      rig.liveNode.releaseHeldPolls();

      expect(<Object?>[
        for (final HandedView view in handed) view.viewJson,
      ], answered);
      for (int j = 1; j < handed.length; j += 1) {
        expect(handed[j].read, greaterThan(handed[j - 1].read));
      }
    }
  });

  test('test_read_live_view_property_a_refused_poll_hands_nothing_and_'
      'polling_goes_on', () async {
    final Random random = seededRandom(96107);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      const RunId runId = RunId('live-run-0');

      rig.liveNode.refusedRuns.add(runId.value);
      rig.watches.watch(runId);
      await rig.settle();
      final int refusedPolls = rig.liveNode
          .listCommandRuns(watchRunCommandName)
          .length;
      expect(rig.handedViews, isEmpty);
      rig.liveNode.refusedRuns.clear();
      await rig.settle();
      rig.watches.stopWatching(runId);

      expect(refusedPolls, greaterThan(1));
      expect(rig.handedViews, isNotEmpty);
    }
  });

  test('test_read_live_view_property_one_refused_run_leaves_the_others_'
      'alone', () async {
    final Random random = seededRandom(96108);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      const RunId refusedRun = RunId('live-run-refused');
      const RunId healthyRun = RunId('live-run-healthy');

      rig.liveNode.refusedRuns.add(refusedRun.value);
      rig.watches.watch(refusedRun);
      rig.watches.watch(healthyRun);
      await rig.settle();
      rig.watches.stopAll();

      final List<HandedView> healthyViews = rig.listHandedViews(
        healthyRun.value,
      );
      expect(rig.listHandedViews(refusedRun.value), isEmpty);
      expect(healthyViews, isNotEmpty);
    }
  });

  test('test_read_live_view_property_the_handed_view_is_the_node_'
      'reply', () async {
    final Random random = seededRandom(96109);

    for (int i = 0; i < _iterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      const RunId runId = RunId('live-run-0');

      rig.watches.watch(runId);
      await rig.settle();
      rig.liveNode.isHoldingPolls = true;
      await rig.settle();

      final List<Object?> answered = rig.liveNode.answeredViews[runId.value]!;
      final List<HandedView> handed = rig.listHandedViews(runId.value);
      rig.watches.stopWatching(runId);
      rig.liveNode.releaseHeldPolls();
      expect(handed.length, answered.length);
      for (int j = 0; j < handed.length; j += 1) {
        expect(handed[j].runId, runId.value);
        expect(handed[j].viewJson, _normalizeViewJson(answered[j]));
      }
    }
  });
}
