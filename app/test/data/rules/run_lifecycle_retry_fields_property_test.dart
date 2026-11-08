import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/task_inputs.dart';

const List<String> _retryableRunStatuses = <String>['failed', 'cancelled'];
const Set<StepStatus> _requeuedStepStatuses = <StepStatus>{
  StepStatus.failed,
  StepStatus.skipped,
};

Run _randomRetryableRun(Random random) {
  return buildSeededRun(
    random,
    runId: 'run-${randomText(random)}',
    taskId: TaskId('task-${randomText(random)}'),
    number: 1 + random.nextInt(500),
    status: pickOne(random, _retryableRunStatuses),
  );
}

List<Object?> _describeStep(RunStep step) {
  return <Object?>[
    step.name,
    step.agentId,
    step.runner,
    step.status,
    step.startedAt,
    step.finishedAt,
    step.result,
    step.outcome,
    step.loopSource,
    ...step.earlierRounds,
  ];
}

void main() {
  test('test_requeue_step_property_reset_steps_keep_'
      'their_results', () {
    final Random random = seededRandom(73301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run stopped = _randomRetryableRun(random);

      final Run reopened = buildRetriedRun(stopped);

      for (int index = 0; index < stopped.steps.length; index += 1) {
        final RunStep before = stopped.steps[index];
        final RunStep after = reopened.steps[index];
        expect(after.result, before.result);
        expect(after.outcome, before.outcome);
        expect(after.loopSource, before.loopSource);
        expect(after.earlierRounds, before.earlierRounds);
      }
    }
  });

  test('test_requeue_stopped_steps_property_done_steps_are_'
      'unchanged', () {
    final Random random = seededRandom(73302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run stopped = _randomRetryableRun(random);

      final Run reopened = buildRetriedRun(stopped);

      for (int index = 0; index < stopped.steps.length; index += 1) {
        final RunStep before = stopped.steps[index];
        if (before.status == StepStatus.done) {
          final RunStep after = reopened.steps[index];
          expect(_describeStep(after), _describeStep(before));
        }
      }
    }
  });

  test('test_requeue_stopped_steps_property_keeps_step_order_'
      'and_names', () {
    final Random random = seededRandom(73303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run stopped = _randomRetryableRun(random);

      final Run reopened = buildRetriedRun(stopped);

      expect(reopened.steps.length, stopped.steps.length);
      for (int index = 0; index < stopped.steps.length; index += 1) {
        final RunStep before = stopped.steps[index];
        final RunStep after = reopened.steps[index];
        expect(after.name, before.name);
        expect(after.agentId, before.agentId);
        expect(after.runner, before.runner);
      }
    }
  });

  test('test_requeue_stopped_steps_property_failed_and_skipped_steps_wait_'
      'unstarted_and_the_rest_stay', () {
    final Random random = seededRandom(73304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run stopped = _randomRetryableRun(random);

      final Run reopened = buildRetriedRun(stopped);

      for (int index = 0; index < stopped.steps.length; index += 1) {
        final RunStep before = stopped.steps[index];
        final RunStep after = reopened.steps[index];
        if (_requeuedStepStatuses.contains(before.status)) {
          expect(after.status, StepStatus.waiting);
          expect(after.startedAt, isNull);
          expect(after.finishedAt, isNull);
        } else {
          expect(_describeStep(after), _describeStep(before));
        }
      }
    }
  });
}
