import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/node/support/feed_poll_transport.dart';
import '../../support/random_inputs.dart';
import 'support/long_poll_feed_node.dart';
import 'support/synchronization_rig.dart';

const int _firstSeed = 8612000;
const int _iterations = 12;
const int _largestScriptLength = 10;
const int _largestEndsInARow = 9;
const int _shortestRetrySeconds = 2;
const int _retrySecondsSpan = 30;
const int _largestHealthyMinutes = 6 * 60;
const int _largestQuietSeconds = 20;
const int _patienceSteps = 600;
const Duration _clockStep = Duration(seconds: 1);
const Duration _productionRetryDelay = Duration(seconds: 30);

typedef _FeedRun = ({
  LongPollFeedNode node,
  NodeSynchronization synchronization,
});

Future<void> _waitOneRealTurn() => Future<void>.delayed(Duration.zero);

Future<void> _pumpThenLetRealMicrotasksRun(
  WidgetTester tester,
  Duration duration,
) async {
  await tester.pump(duration);
  await tester.runAsync(_waitOneRealTurn);
}

Future<void> _advanceStepByStep(WidgetTester tester, Duration total) async {
  Duration advanced = Duration.zero;
  while (advanced < total) {
    await _pumpThenLetRealMicrotasksRun(tester, _clockStep);
    advanced += _clockStep;
  }
}

Future<_FeedRun> _startFeedRun(
  WidgetTester tester, {
  required Random random,
  required List<ScriptedFeedPoll> script,
  required Duration retryDelay,
}) async {
  final LongPollFeedNode node = LongPollFeedNode(
    script: script,
    random: random,
    readNow: tester.binding.clock.now,
  );
  final NodeSynchronization synchronization = NodeSynchronization(
    channel: NodeCommandChannel(
      transport: FeedPollTransport(answer: node.answer),
    ),
    repositoriesInLoadOrder: <NodeSynchronized>[
      RecordingSynchronizedRepository(),
    ],
    retryDelay: retryDelay,
    recheckAppServer: AppServerRecheckCounter().recheck,
  );

  final Future<void> starting = synchronization.start();
  await _pumpThenLetRealMicrotasksRun(tester, Duration.zero);
  await starting;
  return (node: node, synchronization: synchronization);
}

Future<void> _stopFeedRun(WidgetTester tester, _FeedRun run) async {
  final Future<void> stopping = run.synchronization.stop();
  await _pumpThenLetRealMicrotasksRun(tester, idleLongPoll);
  await stopping;
}

Duration _longestScriptTime(
  List<ScriptedFeedPoll> script,
  Duration retryDelay,
) {
  Duration total = _clockStep;
  for (final ScriptedFeedPoll poll in script) {
    total += poll.hold + retryDelay;
  }
  return total;
}

List<ScriptedFeedPoll> _randomScript(Random random) {
  final int length = 1 + random.nextInt(_largestScriptLength);
  final List<ScriptedFeedPoll> script = <ScriptedFeedPoll>[];
  for (int i = 0; i < length; i += 1) {
    if (random.nextBool()) {
      script.add(endingFeedPoll());
      continue;
    }
    final Duration hold = Duration(
      seconds: random.nextInt(_largestQuietSeconds),
    );
    script.add(healthyFeedPoll(random, hold: hold));
  }
  return script;
}

Duration _randomRetryDelay(Random random) {
  return Duration(
    seconds: _shortestRetrySeconds + random.nextInt(_retrySecondsSpan),
  );
}

Future<List<Duration>> _measureScriptGaps(
  WidgetTester tester, {
  required Random random,
  required List<ScriptedFeedPoll> script,
  required Duration retryDelay,
}) async {
  final _FeedRun run = await _startFeedRun(
    tester,
    random: random,
    script: script,
    retryDelay: retryDelay,
  );
  await _advanceStepByStep(tester, _longestScriptTime(script, retryDelay));
  await _stopFeedRun(tester, run);
  return run.node.measureGapsAfterEachScriptedPoll();
}

Future<void> _advanceUntilPollCount(
  WidgetTester tester,
  LongPollFeedNode node,
  int pollCount,
) async {
  int steps = 0;
  while (node.feedPollMoments.length < pollCount && steps < _patienceSteps) {
    await _pumpThenLetRealMicrotasksRun(tester, _clockStep);
    steps += 1;
  }
}

void main() {
  testWidgets(
    'test_reset_resubscribe_delay_property_gaps_follow_the_backoff_model',
    (WidgetTester tester) async {
      final Random random = seededRandom(_firstSeed);

      for (int i = 0; i < _iterations; i += 1) {
        final List<ScriptedFeedPoll> script = _randomScript(random);
        final Duration retryDelay = _randomRetryDelay(random);

        final List<Duration> gaps = await _measureScriptGaps(
          tester,
          random: random,
          script: script,
          retryDelay: retryDelay,
        );

        final BackoffModel model = BackoffModel(retryDelay: retryDelay);
        expect(gaps, orderedEquals(model.predictGapsAfterEachPoll(script)));
      }
    },
  );

  testWidgets(
    'test_reset_resubscribe_delay_property_ends_in_a_row_double_to_the_cap',
    (WidgetTester tester) async {
      final Random random = seededRandom(_firstSeed + 1);

      for (int i = 0; i < _iterations; i += 1) {
        final int endsInARow = 1 + random.nextInt(_largestEndsInARow);
        final List<ScriptedFeedPoll> script = <ScriptedFeedPoll>[
          for (int end = 0; end < endsInARow; end += 1) endingFeedPoll(),
        ];
        final Duration retryDelay = _randomRetryDelay(random);

        final List<Duration> gaps = await _measureScriptGaps(
          tester,
          random: random,
          script: script,
          retryDelay: retryDelay,
        );

        expect(gaps, hasLength(endsInARow));
        for (int end = 0; end < endsInARow; end += 1) {
          final Duration doubled = firstResubscribeDelay * (1 << end);
          final Duration expected = doubled < retryDelay
              ? doubled
              : retryDelay;
          expect(gaps[end], expected);
        }
      }
    },
  );

  testWidgets(
    'test_reset_resubscribe_delay_property_healthy_hours_later_waits_first',
    (WidgetTester tester) async {
      final Random random = seededRandom(_firstSeed + 2);

      for (int i = 0; i < _iterations; i += 1) {
        final int endsInARow = 1 + random.nextInt(_largestEndsInARow);
        final Duration healthyTime = Duration(
          minutes: 1 + random.nextInt(_largestHealthyMinutes),
        );
        final List<ScriptedFeedPoll> script = <ScriptedFeedPoll>[
          for (int end = 0; end < endsInARow; end += 1) endingFeedPoll(),
          healthyFeedPoll(random, hold: healthyTime),
          endingFeedPoll(),
        ];
        final _FeedRun run = await _startFeedRun(
          tester,
          random: random,
          script: script,
          retryDelay: _productionRetryDelay,
        );

        await _advanceUntilPollCount(tester, run.node, endsInARow + 1);
        final DateTime healthyEnd = run.node.feedPollMoments.last.add(
          healthyTime,
        );
        final DateTime now = tester.binding.clock.now();
        await _pumpThenLetRealMicrotasksRun(
          tester,
          healthyEnd.difference(now),
        );
        await _advanceStepByStep(tester, _productionRetryDelay + _clockStep);
        await _stopFeedRun(tester, run);

        final List<Duration> gaps = run.node
            .measureGapsAfterEachScriptedPoll();
        expect(gaps, hasLength(script.length));
        expect(gaps[endsInARow], healthyTime);
        expect(gaps.last, firstResubscribeDelay);
      }
    },
  );
}
