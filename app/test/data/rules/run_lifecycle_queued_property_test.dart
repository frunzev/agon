import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/data/rules/run_step_progress.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../fakes/support/startable_drafts.dart';
import '../fakes/support/task_inputs.dart';

const int _largestRunNumber = 500;
const List<String> _stoppedStatuses = <String>['failed', 'cancelled'];
const Set<StepStatus> _requeuedStepStatuses = <StepStatus>{
  StepStatus.failed,
  StepStatus.skipped,
};

Run _createRandomRun(Random random) {
  final bool runsWorkflow = random.nextBool();
  final Workflow workflow = pickOne(random, galleryWorkflows);
  final TaskDoer doer = runsWorkflow
      ? WorkflowDoer(workflow.id)
      : OneAgentDoer(pickOne(random, AgentKind.values));
  final Task task = Task.fromDraft(
    id: TaskId('task-${randomText(random)}'),
    draft: replaceDraftDoer(randomTaskDraft(random), doer),
    schedule: random.nextBool() ? randomJobSchedule(random) : null,
    status: TaskStatus.toDo,
    createdAt: randomUtcMoment(random),
  );
  return createRun(
    runId: RunId('run-${randomText(random)}'),
    task: task,
    workflow: runsWorkflow ? workflow : null,
    number: 1 + random.nextInt(_largestRunNumber),
    startedBy: GalleryDeviceIds.airLaptop,
    at: randomUtcMoment(random),
  );
}

Run _randomStoppedRun(Random random) {
  final int choice = random.nextInt(3);
  if (choice == 0) {
    return galleryFailedRun;
  }
  if (choice == 1) {
    return buildCancelledRun(
      _createRandomRun(random),
      randomUtcMoment(random),
    );
  }
  return buildSeededRun(
    random,
    runId: 'run-${randomText(random)}',
    taskId: TaskId('task-${randomText(random)}'),
    number: 1 + random.nextInt(_largestRunNumber),
    status: pickOne(random, _stoppedStatuses),
  );
}

void main() {
  test('test_create_run_property_new_runs_wait_queued_for_a_runner', () {
    final Random random = seededRandom(90401);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _createRandomRun(random);

      expect(run.status, RunStatus.queued);
      expect(isRunActive(run), isTrue);
      expect(run.finishedAt, isNull);
    }
  });

  test('test_create_run_property_no_step_starts_before_a_runner_claims_'
      'it', () {
    final Random random = seededRandom(90402);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _createRandomRun(random);

      expect(run.steps, isNotEmpty);
      for (final RunStep step in run.steps) {
        expect(step.status, StepStatus.waiting);
        expect(step.startedAt, isNull);
        expect(step.finishedAt, isNull);
      }
    }
  });

  test('test_create_run_property_status_agrees_with_its_steps', () {
    final Random random = seededRandom(90403);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _createRandomRun(random);

      expect(run.status, deriveRunStatus(run.steps));
    }
  });

  test('test_build_retried_run_property_status_agrees_with_its_steps', () {
    final Random random = seededRandom(90404);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Run stopped = _randomStoppedRun(random);

      final Run retried = buildRetriedRun(stopped);

      expect(retried.status, deriveRunStatus(retried.steps));
      expect(retried.finishedAt, isNull);
    }
  });

  test('test_build_retried_run_property_only_failed_and_skipped_steps_'
      'wait_again', () {
    final Random random = seededRandom(90405);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Run stopped = _randomStoppedRun(random);

      final Run retried = buildRetriedRun(stopped);

      expect(retried.steps.length, stopped.steps.length);
      for (int index = 0; index < stopped.steps.length; index += 1) {
        final RunStep before = stopped.steps[index];
        final RunStep after = retried.steps[index];
        expect(after.name, before.name);
        if (_requeuedStepStatuses.contains(before.status)) {
          expect(after.status, StepStatus.waiting);
          expect(after.startedAt, isNull);
          expect(after.finishedAt, isNull);
        } else {
          expect(after.status, before.status);
          expect(after.startedAt, before.startedAt);
          expect(after.finishedAt, before.finishedAt);
        }
      }
    }
  });

  test('test_build_retried_run_property_cancelled_fresh_runs_come_back_'
      'queued', () {
    final Random random = seededRandom(90406);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Run fresh = _createRandomRun(random);
      final Run cancelled = buildCancelledRun(fresh, randomUtcMoment(random));

      final Run retried = buildRetriedRun(cancelled);

      expect(retried.status, RunStatus.queued);
      for (int index = 0; index < fresh.steps.length; index += 1) {
        expect(retried.steps[index].status, fresh.steps[index].status);
        expect(retried.steps[index].runner, fresh.steps[index].runner);
      }
    }
  });

  test('test_requeue_step_property_requeued_steps_wait_without_times', () {
    final Random random = seededRandom(90407);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Run stopped = _randomStoppedRun(random);

      final Run retried = buildRetriedRun(stopped);

      for (int index = 0; index < stopped.steps.length; index += 1) {
        if (!_requeuedStepStatuses.contains(stopped.steps[index].status)) {
          continue;
        }
        final RunStep requeued = retried.steps[index];
        expect(requeued.status, StepStatus.waiting);
        expect(requeued.startedAt, isNull);
        expect(requeued.finishedAt, isNull);
      }
    }
  });

  test('test_requeue_step_property_keeps_what_the_step_is_and_found', () {
    final Random random = seededRandom(90408);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Run stopped = _randomStoppedRun(random);

      final Run retried = buildRetriedRun(stopped);

      for (int index = 0; index < stopped.steps.length; index += 1) {
        final RunStep before = stopped.steps[index];
        final RunStep after = retried.steps[index];
        expect(after.name, before.name);
        expect(after.agentId, before.agentId);
        expect(after.runner, before.runner);
        expect(after.result, before.result);
        expect(after.outcome, before.outcome);
        expect(after.loopSource, before.loopSource);
        expect(after.earlierRounds, before.earlierRounds);
      }
    }
  });
}
