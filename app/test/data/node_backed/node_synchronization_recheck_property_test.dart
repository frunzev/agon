import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../bridge/node/support/feed_poll_transport.dart';
import '../../support/random_inputs.dart';
import 'support/synchronization_rig.dart';
import 'support/synchronization_steps.dart';

const int _iterations = 25;
const int _largestStepCount = 10;
const int _largestBatchLength = 3;
const int _settlingTurns = 12;

const List<SynchronizationStep> _failureAndChangeSteps = <SynchronizationStep>[
  SynchronizationStep.deliverBatch,
  SynchronizationStep.failPoll,
];

final class _HeldRecheck {
  final Completer<void> release = Completer<void>();
  int startedChecks = 0;

  Future<void> recheck() async {
    startedChecks += 1;
    await release.future;
  }
}

final class _FailingRecheck {
  _FailingRecheck(this.problem);

  final Object problem;
  int startedChecks = 0;

  Future<void> recheck() {
    startedChecks += 1;
    return Future<void>.error(problem);
  }
}

typedef _ManualSync = ({
  SynchronizationNode node,
  FeedPollTransport transport,
  RecordingSynchronizedRepository repository,
  NodeSynchronization synchronization,
});

_ManualSync _buildManualSync(AppServerRecheck recheck) {
  final SynchronizationNode syncNode = SynchronizationNode(startSequence: 1);
  final FeedPollTransport transport = FeedPollTransport(
    answer: syncNode.answer,
  );
  final RecordingSynchronizedRepository repository =
      RecordingSynchronizedRepository();
  return (
    node: syncNode,
    transport: transport,
    repository: repository,
    synchronization: NodeSynchronization(
      channel: NodeCommandChannel(transport: transport),
      repositoriesInLoadOrder: <NodeSynchronized>[repository],
      retryDelay: Duration.zero,
      recheckAppServer: recheck,
    ),
  );
}

Future<ChangeBatch> _failThenDeliver(
  Random random,
  _ManualSync manual, {
  required int afterSequence,
}) async {
  final ChangeBatch batch = buildChangeBatch(
    random,
    afterSequence: afterSequence,
    notificationCount: 1 + random.nextInt(_largestBatchLength),
  );
  manual.node.queuedFeedAnswers.add(answerWithFailure);
  manual.node.queuedFeedAnswers.add(() => batch.reply);
  await letFeedTurnsPass(_settlingTurns * 2);
  return batch;
}

Future<void> _runRandomSteps(
  Random random, {
  required List<SynchronizationStep> steps,
  required bool isRefusing,
}) async {
  final SynchronizationRig rig = SynchronizationRig.build(
    random,
    retryDelay: Duration.zero,
  );
  for (final RecordingSynchronizedRepository repository in rig.repositories) {
    repository.isRefusingChanges = isRefusing && random.nextBool();
  }
  await rig.start();
  await performRandomSteps(
    rig,
    steps: steps,
    stepCount: 1 + random.nextInt(_largestStepCount),
    afterEachStep: expectRigMatchesModel,
  );
  await rig.stop();
}

void main() {
  test('test_handle_feed_problem_property_failures_and_changes_match_the_'
      'model', () async {
    final Random random = seededRandom(96304);

    for (int i = 0; i < _iterations; i += 1) {
      await _runRandomSteps(
        random,
        steps: _failureAndChangeSteps,
        isRefusing: false,
      );
    }
  });

  test('test_handle_feed_problem_property_refused_changes_recheck_once_'
      'each', () async {
    final Random random = seededRandom(96305);

    for (int i = 0; i < _iterations; i += 1) {
      await _runRandomSteps(
        random,
        steps: <SynchronizationStep>[SynchronizationStep.deliverBatch],
        isRefusing: true,
      );
    }
  });

  test('test_handle_feed_problem_property_a_failed_poll_applies_no_'
      'topic', () async {
    final Random random = seededRandom(96306);

    for (int i = 0; i < _iterations; i += 1) {
      final AppServerRecheckCounter serverChecks = AppServerRecheckCounter();
      final _ManualSync manual = _buildManualSync(serverChecks.recheck);
      await manual.synchronization.start();

      manual.node.queuedFeedAnswers.add(answerWithFailure);
      await letFeedTurnsPass(_settlingTurns);
      final List<Object?> topicsAfterFailure = List<Object?>.of(
        manual.repository.appliedTopics,
      );
      final ChangeBatch delivered = await _failThenDeliver(
        random,
        manual,
        afterSequence: manual.node.startSequence,
      );
      await manual.synchronization.stop();

      expect(topicsAfterFailure, isEmpty);
      expect(manual.repository.appliedTopics, delivered.topics);
      expect(serverChecks.checks, greaterThanOrEqualTo(2));
    }
  });

  test('test_recheck_app_server_in_background_property_a_slow_recheck_'
      'never_blocks_changes', () async {
    final Random random = seededRandom(96307);

    for (int i = 0; i < _iterations; i += 1) {
      final _HeldRecheck heldRecheck = _HeldRecheck();
      final _ManualSync manual = _buildManualSync(heldRecheck.recheck);
      await manual.synchronization.start();

      final ChangeBatch delivered = await _failThenDeliver(
        random,
        manual,
        afterSequence: manual.node.startSequence,
      );

      expect(heldRecheck.release.isCompleted, isFalse);
      expect(heldRecheck.startedChecks, greaterThan(0));
      expect(manual.repository.appliedTopics, delivered.topics);
      heldRecheck.release.complete();
      await manual.synchronization.stop();
    }
  });

  test('test_recheck_app_server_in_background_property_a_failing_recheck_'
      'is_contained', () async {
    final Random random = seededRandom(96308);

    for (int i = 0; i < _iterations; i += 1) {
      final Object recheckProblem = random.nextBool()
          ? StateError('the app server is away')
          : RecordNotFound(kind: 'workspace', identifier: randomText(random));
      final _FailingRecheck failingRecheck = _FailingRecheck(recheckProblem);
      final _ManualSync manual = _buildManualSync(failingRecheck.recheck);
      await manual.synchronization.start();

      final ChangeBatch first = await _failThenDeliver(
        random,
        manual,
        afterSequence: manual.node.startSequence,
      );
      final ChangeBatch second = await _failThenDeliver(
        random,
        manual,
        afterSequence: first.latestSequence,
      );
      await manual.synchronization.stop();

      expect(failingRecheck.startedChecks, greaterThanOrEqualTo(4));
      expect(manual.repository.appliedTopics, <Object?>[
        ...first.topics,
        ...second.topics,
      ]);
    }
  });

  test('test_recheck_app_server_in_background_property_rechecks_follow_'
      'the_model_with_refusals', () async {
    final Random random = seededRandom(96309);

    for (int i = 0; i < _iterations; i += 1) {
      await _runRandomSteps(
        random,
        steps: _failureAndChangeSteps,
        isRefusing: true,
      );
    }
  });
}
