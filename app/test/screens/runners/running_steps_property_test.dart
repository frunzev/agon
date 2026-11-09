import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/runners/running_steps.dart';

import '../../support/random_inputs.dart';
import '../support/random_running_steps.dart';

int _countRunningSteps(List<Run> runs, DeviceId? deviceId) {
  int count = 0;
  for (final Run run in runs) {
    for (final RunStep step in run.steps) {
      final bool isOnDevice = deviceId == null || step.runner == deviceId;
      if (step.status == StepStatus.running && isOnDevice) {
        count += 1;
      }
    }
  }
  return count;
}

List<RunningStep> _findOn(FakeTaskRepository tasks, DeviceId deviceId) {
  return findStepsRunningOn(
    deviceId: deviceId,
    taskRepository: tasks,
    jobRepository: buildJobRepositoryOver(tasks),
  );
}

void main() {
  test('test_running_step_constructor_property_keeps_task_run_and_step', () {
    final Random random = seededRandom(108401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = pickOne(random, galleryTasks);
      final Run run = pickOne(random, galleryRuns);
      final RunStep step = pickOne(random, run.steps);

      final RunningStep running = RunningStep(
        task: task,
        run: run,
        step: step,
      );

      expect(running.task, same(task));
      expect(running.run, same(run));
      expect(running.step, same(step));
    }
  });

  test('test_running_step_constructor_property_keeps_any_step_status', () {
    final Random random = seededRandom(108402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = pickOne(random, scatterGalleryRunSteps(random));
      final RunStep step = pickOne(random, run.steps);

      final RunningStep running = RunningStep(
        task: pickOne(random, galleryTasks),
        run: run,
        step: step,
      );

      expect(running.step.status, step.status);
      expect(running.step.runner, step.runner);
    }
  });

  test('test_running_step_constructor_property_two_alike_share_records', () {
    final Task task = galleryTasks.first;
    final Run run = galleryRuns.first;
    final RunStep step = run.steps.first;

    final RunningStep first = RunningStep(task: task, run: run, step: step);
    final RunningStep second = RunningStep(task: task, run: run, step: step);

    expect(first.task, same(second.task));
    expect(first.step, same(second.step));
  });

  test('test_find_steps_running_on_property_sound_and_complete', () {
    final Random random = seededRandom(108403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Run> runs = scatterGalleryRunSteps(random);
      final FakeTaskRepository tasks = buildTaskRepositoryWithRuns(runs);
      final DeviceId deviceId = pickOne(random, stepRunnerIds);

      final List<RunningStep> found = _findOn(tasks, deviceId);

      for (final RunningStep running in found) {
        expect(running.step.runner, deviceId);
        expect(running.step.status, StepStatus.running);
      }
      expect(found, hasLength(_countRunningSteps(runs, deviceId)));
    }
  });

  test('test_find_steps_running_on_property_runners_split_the_steps', () {
    final Random random = seededRandom(108404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Run> runs = scatterGalleryRunSteps(random);
      final FakeTaskRepository tasks = buildTaskRepositoryWithRuns(runs);
      final Set<RunStep> seenSteps = <RunStep>{};
      int foundCount = 0;

      for (final DeviceId deviceId in stepRunnerIds) {
        for (final RunningStep running in _findOn(tasks, deviceId)) {
          expect(seenSteps.add(running.step), isTrue);
          foundCount += 1;
        }
      }

      int runningWithRunner = 0;
      for (final DeviceId deviceId in stepRunnerIds) {
        runningWithRunner += _countRunningSteps(runs, deviceId);
      }
      expect(foundCount, runningWithRunner);
      expect(foundCount, lessThanOrEqualTo(_countRunningSteps(runs, null)));
    }
  });

  test('test_find_steps_running_on_property_each_step_sits_in_its_run', () {
    final Random random = seededRandom(108405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository tasks = buildTaskRepositoryWithRuns(
        scatterGalleryRunSteps(random),
      );
      final List<TaskId> taskOrder = <TaskId>[
        for (final Task task in tasks.listTasks()) task.id,
        for (final Task job in buildJobRepositoryOver(tasks).listJobs())
          job.id,
      ];

      final List<RunningStep> found = _findOn(
        tasks,
        pickOne(random, stepRunnerIds),
      );

      int previousTaskPosition = 0;
      for (final RunningStep running in found) {
        expect(running.run.taskId, running.task.id);
        expect(running.run.steps, contains(same(running.step)));
        final int taskPosition = taskOrder.indexOf(running.task.id);
        expect(taskPosition, greaterThanOrEqualTo(previousTaskPosition));
        previousTaskPosition = taskPosition;
      }
    }
  });
}
