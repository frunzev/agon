import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/projects.dart';

import '../../support/random_inputs.dart';

import 'project_rows_inputs.dart';

void main() {
  test('test_project_work_new_property_keeps_tasks_and_runs', () {
    final Random random = seededRandom(1050801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RandomProjectWork work = randomProjectWork(random);
      final ProjectWork projectWork = ProjectWork(
        tasks: work.tasks,
        runs: work.runs,
      );

      expect(projectWork.tasks, orderedEquals(work.tasks));
      expect(projectWork.runs, orderedEquals(work.runs));
    }
  });

  test('test_project_work_new_property_owns_its_lists', () {
    final Random random = seededRandom(1050802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RandomProjectWork work = randomProjectWork(random);
      final List<Task> tasks = List<Task>.of(work.tasks);
      final ProjectWork projectWork = ProjectWork(
        tasks: tasks,
        runs: work.runs,
      );

      tasks.clear();

      expect(projectWork.tasks, hasLength(work.tasks.length));
      expect(() => projectWork.runs.add(galleryRuns.first), throwsA(anything));
    }
  });

  test('test_project_work_new_property_empty_work_has_nothing', () {
    final ProjectWork work = ProjectWork(
      tasks: const <Task>[],
      runs: const <Run>[],
    );

    expect(work.runningTaskCount, 0);
    expect(work.latestRun, isNull);
    expect(work.latestTaskTitle, isNull);
  });

  test('test_running_task_count_property_counts_running_tasks_only', () {
    final Random random = seededRandom(1050803);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RandomProjectWork work = randomProjectWork(random);
      final int running = work.tasks
          .where((Task task) => task.status == TaskStatus.running)
          .length;

      expect(
        ProjectWork(tasks: work.tasks, runs: work.runs).runningTaskCount,
        running,
      );
    }
  });

  test('test_running_task_count_property_ignores_runs', () {
    final Random random = seededRandom(1050804);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RandomProjectWork work = randomProjectWork(random);

      expect(
        ProjectWork(tasks: work.tasks, runs: work.runs).runningTaskCount,
        ProjectWork(tasks: work.tasks, runs: const <Run>[]).runningTaskCount,
      );
    }
  });

  test('test_running_task_count_property_bounded_by_tasks', () {
    final Random random = seededRandom(1050805);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RandomProjectWork work = randomProjectWork(random);
      final List<Task> running = <Task>[
        for (final Task task in work.tasks)
          task.withStatus(TaskStatus.running),
      ];

      expect(
        ProjectWork(tasks: running, runs: work.runs).runningTaskCount,
        work.tasks.length,
      );
    }
  });

  test('test_latest_run_property_order_of_runs_does_not_matter', () {
    final Random random = seededRandom(1050806);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RandomProjectWork work = randomProjectWork(random);
      final List<Run> shuffled = List<Run>.of(work.runs)..shuffle(random);

      expect(
        ProjectWork(tasks: work.tasks, runs: shuffled).latestRun?.startedAt,
        ProjectWork(tasks: work.tasks, runs: work.runs).latestRun?.startedAt,
      );
    }
  });

  test('test_latest_run_property_is_one_of_the_runs', () {
    final Random random = seededRandom(1050807);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RandomProjectWork work = randomProjectWork(random);
      final Run? latest = ProjectWork(
        tasks: work.tasks,
        runs: work.runs,
      ).latestRun;

      expect(latest == null, work.runs.isEmpty);
      if (latest != null) {
        expect(work.runs, contains(latest));
      }
    }
  });

  test('test_latest_task_title_property_names_the_latest_runs_task', () {
    final Random random = seededRandom(1050808);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RandomProjectWork work = randomProjectWork(random);
      final ProjectWork projectWork = ProjectWork(
        tasks: work.tasks,
        runs: work.runs,
      );
      final Run? latest = projectWork.latestRun;

      if (latest == null) {
        expect(projectWork.latestTaskTitle, isNull);
      } else {
        final Task task = work.tasks.firstWhere(
          (Task candidate) => candidate.id == latest.taskId,
        );
        expect(projectWork.latestTaskTitle, task.title);
      }
    }
  });

  test('test_latest_task_title_property_unknown_task_has_no_title', () {
    final Random random = seededRandom(1050809);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RandomProjectWork work = randomProjectWork(random);

      expect(
        ProjectWork(tasks: const <Task>[], runs: work.runs).latestTaskTitle,
        isNull,
      );
    }
  });

  test('test_latest_task_title_property_tasks_without_runs_never_name', () {
    final Random random = seededRandom(1050810);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RandomProjectWork work = randomProjectWork(random);

      expect(
        ProjectWork(tasks: work.tasks, runs: const <Run>[]).latestTaskTitle,
        isNull,
      );
    }
  });
}
