import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/data/rules/run_step_progress.dart';

import '../../support/random_inputs.dart';
import 'support/task_inputs.dart';
import 'support/task_rigs.dart';

const String _typePrefix = 'test_fake_task_repository';
const Set<StepStatus> _requeuedStepStatuses = <StepStatus>{
  StepStatus.failed,
  StepStatus.skipped,
};

Future<Run?> _startRandomTask(Random random, TaskRig rig) async {
  final List<Task> startable = listStartableTasks(rig);
  if (startable.isEmpty) {
    return null;
  }
  return rig.repository.startTask(pickOne(random, startable).id);
}

Run? _pickRetryableRun(Random random, TaskRig rig) {
  final List<Run> retryable = <Run>[
    for (final Run run in listRunsWithStatus(
      rig.repository,
      stoppedRunStatuses,
    ))
      if (!rig.repository.listRuns(run.taskId).any(isRunActive) &&
          rig.repository.listRuns(run.taskId).first.id == run.id)
        run,
  ];
  if (retryable.isEmpty) {
    return null;
  }
  return pickOne(random, retryable);
}

void main() {
  test('${_typePrefix}_start_task_property_runs_wait_queued_for_a_'
      'runner', () async {
    final Random random = seededRandom(90411);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final Run? started = await _startRandomTask(random, rig);
      if (started == null) {
        continue;
      }

      expect(started.status, RunStatus.queued);
      expect(rig.repository.findRun(started.id).status, RunStatus.queued);
      expect(rig.repository.listRuns(started.taskId).first.id, started.id);
    }
  });

  test('${_typePrefix}_start_task_property_no_step_starts_before_a_runner_'
      'claims_it', () async {
    final Random random = seededRandom(90412);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final Run? started = await _startRandomTask(random, rig);
      if (started == null) {
        continue;
      }

      expect(started.steps, isNotEmpty);
      for (final RunStep step in started.steps) {
        expect(step.status, StepStatus.waiting);
        expect(step.startedAt, isNull);
      }
    }
  });

  test('${_typePrefix}_start_task_property_queued_run_counts_as_running_'
      'work', () async {
    final Random random = seededRandom(90413);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final Run? started = await _startRandomTask(random, rig);
      if (started == null) {
        continue;
      }

      expect(
        rig.repository.findTask(started.taskId).status,
        TaskStatus.running,
      );
      await expectLater(
        rig.repository.startTask(started.taskId),
        throwsA(isA<AppServerRefusal>()),
      );
    }
  });

  test('${_typePrefix}_retry_run_property_status_agrees_with_its_'
      'steps', () async {
    final Random random = seededRandom(90414);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final Run? stopped = _pickRetryableRun(random, rig);
      if (stopped == null) {
        continue;
      }

      final Run retried = await rig.repository.retryRun(stopped.id);

      expect(retried.status, deriveRunStatus(retried.steps));
      expect(rig.repository.findRun(stopped.id).status, retried.status);
    }
  });

  test('${_typePrefix}_retry_run_property_only_failed_and_skipped_steps_'
      'wait_again', () async {
    final Random random = seededRandom(90415);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final Run? stopped = _pickRetryableRun(random, rig);
      if (stopped == null) {
        continue;
      }

      final Run retried = await rig.repository.retryRun(stopped.id);

      for (int index = 0; index < stopped.steps.length; index += 1) {
        final StepStatus before = stopped.steps[index].status;
        final StepStatus after = retried.steps[index].status;
        if (_requeuedStepStatuses.contains(before)) {
          expect(after, StepStatus.waiting);
        } else {
          expect(after, before);
        }
      }
    }
  });

  test('${_typePrefix}_retry_run_property_cancelled_fresh_runs_come_back_'
      'queued', () async {
    final Random random = seededRandom(90416);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final Run? started = await _startRandomTask(random, rig);
      if (started == null) {
        continue;
      }
      await rig.repository.cancelRun(started.id);

      final Run retried = await rig.repository.retryRun(started.id);

      expect(retried.status, RunStatus.queued);
      expect(
        rig.repository.findTask(started.taskId).status,
        TaskStatus.running,
      );
    }
  });
}
