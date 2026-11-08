import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'support/live_watch_node.dart';

const int _iterations = 60;
const int _watchIterations = 10;
const int _largestRepeatCount = 4;
const int _hugeTextRepeat = 2000;
const int _liveRunCount = 3;

typedef _ProblemLogger = void Function(Object problem, StackTrace stackTrace);

final class _UnfinishedWork implements Exception {
  const _UnfinishedWork(this.reason);

  final String reason;

  @override
  String toString() => 'unfinished: $reason';
}

Object _randomProblem(Random random) {
  final String text = randomHostileText(random);
  final List<Object> problems = <Object>[
    StateError(text),
    RecordNotFound(kind: text, identifier: randomText(random)),
    NodeCommandFailure(text),
    FormatException(text),
    ArgumentError.value(text),
    _UnfinishedWork(text),
    text,
    text * _hugeTextRepeat,
    <String, Object?>{'problem': text},
  ];
  return pickOne(random, problems);
}

StackTrace _randomStackTrace(Random random) {
  return random.nextBool() ? StackTrace.current : StackTrace.empty;
}

void _expectLoggingIsTotal(int seed, _ProblemLogger logProblem) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < _iterations; i += 1) {
    final Object problem = _randomProblem(random);
    final String describedBefore = problem.toString();

    logProblem(problem, _randomStackTrace(random));

    expect(problem.toString(), describedBefore);
  }
}

void _expectRepeatedLoggingIsHarmless(int seed, _ProblemLogger logProblem) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < _iterations; i += 1) {
    final Object problem = _randomProblem(random);
    final StackTrace stackTrace = _randomStackTrace(random);
    final int repeatCount = 1 + random.nextInt(_largestRepeatCount);

    final String describedBefore = problem.toString();

    for (int j = 0; j < repeatCount; j += 1) {
      logProblem(problem, stackTrace);
    }

    expect(problem.toString(), describedBefore);
  }
}

void main() {
  test('test_log_node_synchronization_problem_property_never_throws_'
      'for_any_problem', () {
    _expectLoggingIsTotal(96801, logNodeSynchronizationProblem);
  });

  test('test_log_node_synchronization_problem_property_repeating_it_is_'
      'harmless', () {
    _expectRepeatedLoggingIsHarmless(96802, logNodeSynchronizationProblem);
  });

  test('test_log_node_synchronization_problem_property_background_node_'
      'failures_end_quietly', () async {
    final Random random = seededRandom(96803);

    for (int i = 0; i < _iterations; i += 1) {
      final String text = randomHostileText(random);
      final Object nodeFailure = random.nextBool()
          ? StateError(text)
          : RecordNotFound(kind: text, identifier: randomText(random));
      final _UnfinishedWork otherProblem = _UnfinishedWork(text);

      await runLoggingNodeFailures(() => Future<void>.error(nodeFailure));

      await expectLater(
        runLoggingNodeFailures(() => Future<void>.error(otherProblem)),
        throwsA(same(otherProblem)),
      );
    }
  });

  test('test_log_live_run_problem_property_never_throws_for_any_'
      'problem', () {
    _expectLoggingIsTotal(96804, logLiveRunProblem);
  });

  test('test_log_live_run_problem_property_repeating_it_is_harmless', () {
    _expectRepeatedLoggingIsHarmless(96805, logLiveRunProblem);
  });

  test('test_log_live_run_problem_property_a_logged_poll_keeps_the_watch_'
      'going', () async {
    final Random random = seededRandom(96806);

    for (int i = 0; i < _watchIterations; i += 1) {
      final LiveWatchRig rig = LiveWatchRig(random);
      final RunId runId = RunId(
        randomLiveRunId(random, runCount: _liveRunCount),
      );

      rig.liveNode.refusedRuns.add(runId.value);
      rig.liveNode.refusedStops.add(runId.value);
      rig.watches.watch(runId);
      final Set<String> polledWhileRefused = await rig
          .listRunsPolledWhileWaiting();
      rig.watches.stopWatching(runId);
      await rig.settle();

      expect(polledWhileRefused, <String>{runId.value});
      expect(rig.handedViews, isEmpty);
      expect(await rig.listRunsPolledWhileWaiting(), isEmpty);
    }
  });
}
