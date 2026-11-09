import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/presentation/count_text.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';

import 'project_rows_inputs.dart';

void main() {
  test('test_collect_project_work_property_runs_of_every_project_task', () {
    final Random random = seededRandom(1050811);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RandomProjectWork work = randomProjectWork(random);
      final ProjectId projectId = pickOne(random, sampleProjectIds);
      final ProjectWork collected = collectProjectWork(
        projectId: projectId,
        tasks: work.tasks,
        listRuns: (TaskId taskId) => <Run>[
          for (final Run run in work.runs)
            if (run.taskId == taskId) run,
        ],
      );
      final Set<TaskId> projectTaskIds = <TaskId>{
        for (final Task task in work.tasks)
          if (task.projectId == projectId) task.id,
      };

      expect(collected.tasks.map((Task task) => task.id), projectTaskIds);
      expect(collected.runs, <Run>[
        for (final Task task in collected.tasks)
          for (final Run run in work.runs)
            if (run.taskId == task.id) run,
      ]);
    }
  });

  test('test_collect_project_work_property_asks_runs_only_for_its_tasks', () {
    final Random random = seededRandom(1050812);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RandomProjectWork work = randomProjectWork(random);
      final ProjectId projectId = pickOne(random, sampleProjectIds);
      final List<TaskId> asked = <TaskId>[];

      collectProjectWork(
        projectId: projectId,
        tasks: work.tasks,
        listRuns: (TaskId taskId) {
          asked.add(taskId);
          return const <Run>[];
        },
      );

      expect(asked, <TaskId>[
        for (final Task task in work.tasks)
          if (task.projectId == projectId) task.id,
      ]);
    }
  });

  test('test_describe_project_summary_property_counts_with_grouping', () {
    final Random random = seededRandom(1050813);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = randomRowsProject(
        random,
        sampleProjectIds.first,
      );
      final RandomProjectWork work = randomProjectWork(random);
      final String summary = describeProjectSummary(
        project,
        ProjectWork(tasks: work.tasks, runs: work.runs),
      );

      final String repositories = describeCount(
        project.repositories.length,
        singular: 'repo',
        plural: 'repos',
      );
      final String tasks = describeCount(
        work.tasks.length,
        singular: 'task',
        plural: 'tasks',
      );

      expect(summary, '$repositories · $tasks');
    }
  });

  test('test_describe_project_summary_property_ignores_runs', () {
    final Random random = seededRandom(1050814);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = randomRowsProject(
        random,
        sampleProjectIds.first,
      );
      final RandomProjectWork work = randomProjectWork(random);

      expect(
        describeProjectSummary(
          project,
          ProjectWork(tasks: work.tasks, runs: work.runs),
        ),
        describeProjectSummary(
          project,
          ProjectWork(tasks: work.tasks, runs: const <Run>[]),
        ),
      );
    }
  });

  test('test_build_project_row_property_shows_names_and_paths', () {
    final Random random = seededRandom(1050815);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = randomRowsProject(
        random,
        sampleProjectIds.first,
      );
      final ListRowData row = buildProjectRow(
        project: project,
        work: ProjectWork(tasks: const <Task>[], runs: const <Run>[]),
        now: galleryNow,
        onTap: () {},
      );
      final ListRowMain main = row.main as ListRowMain;

      expect(main.title, project.name);
      expect(main.subtitle.single.text, describeRepositoryPaths(project));
      final List<String?> metaTexts = <String?>[
        for (final Widget meta in row.meta) (meta as Text).data,
      ];
      expect(
        metaTexts.join(' · '),
        describeProjectSummary(
          project,
          ProjectWork(tasks: const <Task>[], runs: const <Run>[]),
        ),
      );
    }
  });

  test('test_build_project_row_property_activity_follows_the_work', () {
    final Random random = seededRandom(1050816);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RandomProjectWork work = randomProjectWork(random);
      final ProjectWork projectWork = ProjectWork(
        tasks: work.tasks,
        runs: work.runs,
      );
      final DateTime now = randomUtcMoment(random);
      final ListRowData row = buildProjectRow(
        project: randomRowsProject(random, sampleProjectIds.first),
        work: projectWork,
        now: now,
        onTap: () {},
      );
      final StatusLabel expected = buildProjectActivityLabel(
        runningTaskCount: projectWork.runningTaskCount,
        lastRunAt: projectWork.latestRun?.startedAt,
        now: now,
      );

      expect((row.end! as StatusLabel).text, expected.text);
    }
  });
}
