import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import '../models/support/random_run_records.dart';
import 'run_lifecycle_test.dart' show randomTask;
import 'support/random_progress_runs.dart';
import 'support/schedule_scope_run_tables.dart';

Run _buildRun(
  Random random, {
  required RunStatus status,
  required List<StepStatus> stepStatuses,
}) {
  final List<RunStep> steps = <RunStep>[
    for (int index = 0; index < stepStatuses.length; index += 1)
      buildProgressStep(
        template: randomRunStep(random),
        name: 'step $index',
        runner: null,
        status: stepStatuses[index],
      ),
  ];
  return buildProgressRun(random, status: status, steps: steps);
}

List<StepStatus> _listStatuses(Run run) {
  return <StepStatus>[for (final RunStep step in run.steps) step.status];
}

void main() {
  test('test_is_run_active_property_matches_the_shared_run_statuses', () {
    final Random random = seededRandom(88801);

    for (final SharedRunStatusCase sharedCase in readSharedRunStatusCases()) {
      final Run run = buildProgressRun(
        random,
        status: sharedCase.status,
        steps: randomProgressSteps(random),
      );

      expect(isRunActive(run), !sharedCase.isFinished, reason: '$sharedCase');
    }
  });

  test('test_is_run_active_property_only_active_runs_can_be_cancelled', () {
    final Random random = seededRandom(88802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomProgressRun(random);

      final Matcher expectedOutcome = isRunActive(run)
          ? returnsNormally
          : throwsStateError;

      expect(
        () => buildCancelledRun(run, galleryNow),
        expectedOutcome,
        reason: '${run.status}',
      );
    }
  });

  test('test_build_cancelled_run_property_matches_the_shared_cancels', () {
    final Random random = seededRandom(88803);

    for (final SharedCancelCase sharedCase in readSharedCancelCases()) {
      final Run active = _buildRun(
        random,
        status: pickOne(random, activeRunStatuses),
        stepStatuses: sharedCase.steps,
      );

      final Run cancelled = buildCancelledRun(active, galleryNow);

      expect(_listStatuses(cancelled), sharedCase.afterCancel);
      expect(cancelled.status, RunStatus.cancelled);
      expect(cancelled.finishedAt, galleryNow);
    }
  });

  test('test_build_retried_run_property_matches_the_shared_retries', () {
    final Random random = seededRandom(88804);

    for (final SharedRetryCase sharedCase in readSharedRetryCases()) {
      final Run stopped = _buildRun(
        random,
        status: pickOne(random, <RunStatus>[
          RunStatus.failed,
          RunStatus.cancelled,
        ]),
        stepStatuses: sharedCase.steps,
      );

      final Run retried = buildRetriedRun(stopped);

      expect(_listStatuses(retried), sharedCase.afterRetry);
      expect(retried.status, sharedCase.statusAfterRetry);
      expect(retried.finishedAt, isNull);
      expect(retried.failure, isNull);
    }
  });

  test('test_build_retried_run_property_refuses_exactly_the_shared_'
      'unretryable_statuses', () {
    final Random random = seededRandom(88805);

    for (final SharedRunStatusCase sharedCase in readSharedRunStatusCases()) {
      final Run run = buildProgressRun(
        random,
        status: sharedCase.status,
        steps: randomProgressSteps(random),
      );

      final Matcher expectedOutcome = sharedCase.canRetry
          ? returnsNormally
          : throwsStateError;

      expect(
        () => buildRetriedRun(run),
        expectedOutcome,
        reason: '$sharedCase',
      );
    }
  });

  test('test_describe_run_branch_property_tasks_ignore_the_run_number', () {
    final Random random = seededRandom(88806);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = randomTask(random);
      final int number = 1 + random.nextInt(propertyIterations);
      final int otherNumber = 1 + random.nextInt(propertyIterations);

      final String branch = describeRunBranch(task, number);
      final String otherBranch = describeRunBranch(task, otherNumber);

      if (task.schedule == null) {
        expect(otherBranch, branch);
      } else {
        expect(otherBranch == branch, otherNumber == number);
      }
    }
  });

  test('test_describe_run_branch_property_branches_live_under_task_and_'
      'are_git_safe', () {
    final Random random = seededRandom(88807);
    final RegExp gitSafeBranch = RegExp(r'^task/[a-z0-9]+(-[a-z0-9]+)*$');

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = randomTask(random);

      final String branch = describeRunBranch(
        task,
        1 + random.nextInt(propertyIterations),
      );

      expect(branch, matches(gitSafeBranch));
    }
  });
}
