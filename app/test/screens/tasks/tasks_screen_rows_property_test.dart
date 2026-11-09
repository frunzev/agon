import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/kept_branches.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/screens/shared/status_labels.dart';
import 'package:agent_orchestration/screens/tasks/task_row.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/random_inputs.dart';
import 'random_listed_tasks.dart';
import 'tasks_screen_scene.dart';

final DeviceNames _deviceNames = DeviceNames(galleryDevices);

List<KeptBranch> _findExpectedKeptBranches(TasksScene scene, Task task) {
  final Run? latest = findLatestRun(scene, task);
  if (latest == null) {
    return const <KeptBranch>[];
  }
  final List<ApprovalRequest> approvals = scene.dependencies.approvalRepository
      .listApprovals();
  return findKeptBranches(run: latest, approvals: approvals);
}

String _readStatus(ListRowData row) => (row.end! as StatusLabel).text;

Future<List<ListRowData>> _openRows(
  WidgetTester tester,
  Random random,
  TasksScene scene,
) async {
  await openTasksPage(
    tester,
    random: random,
    dependencies: scene.dependencies,
  );
  return readTaskRows(tester);
}

void main() {
  testWidgets(
    'test_tasks_screen_build_row_property_cells_describe_the_latest_run',
    (WidgetTester tester) async {
      final Random random = seededRandom(116301);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TasksScene scene = buildTasksScene(random, leastTaskCount: 1);
        final List<ListRowData> rows = await _openRows(tester, random, scene);
        final List<Task> listed = scene.tasks.listTasks();

        for (int index = 0; index < rows.length; index += 1) {
          final Task task = listed[index];
          final Run? latest = findLatestRun(scene, task);
          final ListRowData expected = buildTaskRow(
            task: task,
            latestRun: latest,
            projectName: '',
            doerLabel: '',
            keptBranches: const <KeptBranch>[],
            deviceNames: _deviceNames,
            now: galleryNow,
            onTap: () {},
          );
          final Text shownStart = rows[index].meta[1] as Text;
          final Text expectedStart = expected.meta[1] as Text;
          expect(shownStart.data, expectedStart.data);
        }
      }
    },
  );

  testWidgets(
    'test_tasks_screen_build_row_property_subtitle_names_project_and_doer',
    (WidgetTester tester) async {
      final Random random = seededRandom(116302);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TasksScene scene = buildTasksScene(random, leastTaskCount: 1);
        final List<ListRowData> rows = await _openRows(tester, random, scene);
        final List<Task> listed = scene.tasks.listTasks();

        for (int index = 0; index < rows.length; index += 1) {
          final Task task = listed[index];
          final String projectName = scene.dependencies.projectRepository
              .findProject(task.projectId)
              .name;
          final String doer = describeDoer(
            task.doer,
            scene.dependencies.workflowRepository.listWorkflows(),
          );
          final ListRowMain main = rows[index].main as ListRowMain;
          expect(
            main.subtitle.single.text,
            startsWith('$projectName · $doer'),
          );
        }
      }
    },
  );

  testWidgets(
    'test_tasks_screen_build_row_property_runs_on_follows_latest_runner',
    (WidgetTester tester) async {
      final Random random = seededRandom(116303);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TasksScene scene = buildTasksScene(random, leastTaskCount: 1);
        await openTasksPage(
          tester,
          random: random,
          dependencies: scene.dependencies,
        );

        for (final Task task in scene.tasks.listTasks()) {
          final List<TextSegment> segments = describeTaskRunsOn(
            task: task,
            latestRun: findLatestRun(scene, task),
            deviceNames: _deviceNames,
          );
          final String expected = <String>[
            for (final TextSegment segment in segments) segment.text,
          ].join();
          expect(find.text(expected, findRichText: true), findsWidgets);
        }
      }
    },
  );

  testWidgets(
    'test_tasks_screen_find_kept_branches_property_denied_not_pushed',
    (WidgetTester tester) async {
      final Random random = seededRandom(116304);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TasksScene scene = buildTasksScene(random, leastTaskCount: 1);
        final List<ListRowData> rows = await _openRows(tester, random, scene);
        final List<Task> listed = scene.tasks.listTasks();

        for (int index = 0; index < rows.length; index += 1) {
          final bool isKept = _findExpectedKeptBranches(
            scene,
            listed[index],
          ).isNotEmpty;
          expect(_readStatus(rows[index]) == 'Not pushed', isKept);
        }
      }
    },
  );

  testWidgets(
    'test_tasks_screen_find_kept_branches_property_otherwise_plain_status',
    (WidgetTester tester) async {
      final Random random = seededRandom(116305);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TasksScene scene = buildTasksScene(random, leastTaskCount: 1);
        final List<ListRowData> rows = await _openRows(tester, random, scene);
        final List<Task> listed = scene.tasks.listTasks();

        for (int index = 0; index < rows.length; index += 1) {
          final Task task = listed[index];
          if (_findExpectedKeptBranches(scene, task).isNotEmpty) {
            continue;
          }
          expect(
            _readStatus(rows[index]),
            buildTaskStatusLabel(task.status).text,
          );
        }
      }
    },
  );

  testWidgets(
    'test_tasks_screen_find_kept_branches_property_only_done_latest',
    (WidgetTester tester) async {
      final Random random = seededRandom(116306);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TasksScene scene = buildTasksScene(random, leastTaskCount: 1);
        final List<ListRowData> rows = await _openRows(tester, random, scene);
        final List<Task> listed = scene.tasks.listTasks();

        for (int index = 0; index < rows.length; index += 1) {
          final Run? latest = findLatestRun(scene, listed[index]);
          final bool isLatestDone = latest?.status == RunStatus.done;
          if (!isLatestDone) {
            expect(_readStatus(rows[index]), isNot('Not pushed'));
          }
        }
      }
    },
  );
}
