import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/tasks/tasks_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/theme/layout_size.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../shared/support/watch_counting_task_repository.dart';
import 'random_listed_tasks.dart';
import 'tasks_screen_scene.dart';

const String _emptyTitle = 'No tasks yet';
const String _emptyMessage =
    'Write what you want done, then pick one agent or a whole workflow to '
    'do it.';
const List<String> _columnLabels = <String>[
  'Task',
  'Runs on',
  'Started',
  'Status',
];
const List<(TaskStatus, String)> _summaryPhrases = <(TaskStatus, String)>[
  (TaskStatus.running, 'running'),
  (TaskStatus.waitingForApproval, 'waiting for approval'),
  (TaskStatus.failed, 'failed'),
  (TaskStatus.toDo, 'to do'),
];

String _modelSummary(List<Task> tasks) {
  final List<String> parts = <String>[];
  for (final (TaskStatus status, String phrase) in _summaryPhrases) {
    int count = 0;
    for (final Task task in tasks) {
      if (task.status == status) {
        count += 1;
      }
    }
    if (count > 0) {
      parts.add('$count $phrase');
    }
  }
  if (parts.isEmpty) {
    return 'All done';
  }
  return parts.join(' · ');
}

TaskDraft _draftInThisWorkspace(Task task) {
  return TaskDraft(
    title: task.title,
    details: task.details,
    projectId: GalleryProjectIds.acmeApp,
    doer: task.doer,
    runsOn: task.runsOn,
    agentPlace: task.agentPlace,
    skills: task.skills,
    usesAutomaticSkills: task.usesAutomaticSkills,
    approvalPolicy: task.approvalPolicy,
  );
}

TasksScreen _buildScreen(AppDependencies dependencies, {required Key? key}) {
  return TasksScreen(
    key: key,
    taskRepository: dependencies.taskRepository,
    workflowRepository: dependencies.workflowRepository,
    projectRepository: dependencies.projectRepository,
    deviceRepository: dependencies.deviceRepository,
    approvalRepository: dependencies.approvalRepository,
    clock: dependencies.clock,
    navigation: AppNavigation(initialRoute: tasksRoute),
  );
}

bool _isCompact(WidgetTester tester) {
  final double width = tester.view.physicalSize.width;
  return LayoutSize.forWidth(width).isCompact;
}

void main() {
  test('test_tasks_screen_property_keeps_every_field', () {
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final TasksScreen screen = _buildScreen(dependencies, key: null);

      expect(
        identical(screen.taskRepository, dependencies.taskRepository),
        isTrue,
      );
      expect(
        identical(screen.workflowRepository, dependencies.workflowRepository),
        isTrue,
      );
      expect(
        identical(screen.projectRepository, dependencies.projectRepository),
        isTrue,
      );
      expect(
        identical(screen.deviceRepository, dependencies.deviceRepository),
        isTrue,
      );
      expect(
        identical(screen.approvalRepository, dependencies.approvalRepository),
        isTrue,
      );
      expect(identical(screen.clock, dependencies.clock), isTrue);
    }
  });

  test('test_tasks_screen_property_keeps_the_given_key', () {
    final Random random = seededRandom(116201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomText(random));

      expect(_buildScreen(buildGalleryDependencies(), key: key).key, key);
    }
  });

  test('test_tasks_screen_property_constructing_reads_no_tasks', () {
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = replaceRepositories(
        buildGalleryDependencies(),
        taskRepository: WatchCountingTaskRepository(),
      );

      expect(() => _buildScreen(dependencies, key: null), returnsNormally);
    }
  });

  testWidgets('test_tasks_screen_build_property_rows_in_server_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(116202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TasksScene scene = buildTasksScene(random, leastTaskCount: 0);
      await openTasksPage(
        tester,
        random: random,
        dependencies: scene.dependencies,
      );

      final List<String> listed = <String>[
        for (final Task task in scene.tasks.listTasks()) task.title,
      ];
      expect(readTaskRowTitles(tester), listed);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_tasks_screen_build_property_lists_this_workspace_only', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(116203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TasksScene scene = buildTasksScene(random, leastTaskCount: 1);
      await openTasksPage(
        tester,
        random: random,
        dependencies: scene.dependencies,
      );

      final Set<String> projectsHere = <String>{
        for (final Project project
            in scene.dependencies.projectRepository.listProjects(
              scene.dependencies.workspaceRepository.currentWorkspace().id,
            ))
          project.id.value,
      };
      for (final Task task in scene.allTasks) {
        final bool isHere = projectsHere.contains(task.projectId.value);
        expect(readTaskRowTitles(tester).contains(task.title), isHere);
      }
    }
  });

  testWidgets('test_tasks_screen_build_property_follows_repository_changes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(116204);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TasksScene scene = buildTasksScene(random, leastTaskCount: 0);
      await openTasksPage(
        tester,
        random: random,
        dependencies: scene.dependencies,
      );

      final Task created = await scene.tasks.createTask(
        _draftInThisWorkspace(randomListedTask(random, 1000 + i)),
      );
      await tester.pump();

      final List<String> listed = <String>[
        for (final Task task in scene.tasks.listTasks()) task.title,
      ];
      expect(readTaskRowTitles(tester), listed);
      expect(readTaskRowTitles(tester).first, created.title);
    }
  });

  testWidgets(
    'test_tasks_screen_build_page_property_empty_list_invites_a_first_task',
    (WidgetTester tester) async {
      final Random random = seededRandom(116205);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TasksScene scene = buildTasksScene(random, leastTaskCount: 0);
        await openTasksPage(
          tester,
          random: random,
          dependencies: scene.dependencies,
        );

        final bool isEmpty = scene.tasks.listTasks().isEmpty;
        expect(find.text(_emptyTitle), findsNWidgets(isEmpty ? 1 : 0));
        expect(find.text(_emptyMessage), findsNWidgets(isEmpty ? 1 : 0));
        expect(readTaskRows(tester).isEmpty, isEmpty);
      }
    },
  );

  testWidgets(
    'test_tasks_screen_build_page_property_summary_counts_open_work',
    (WidgetTester tester) async {
      final Random random = seededRandom(116206);

      for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
        final TasksScene scene = buildTasksScene(random, leastTaskCount: 1);
        await openTasksPage(
          tester,
          random: random,
          dependencies: scene.dependencies,
        );

        final List<Task> listed = scene.tasks.listTasks();
        if (listed.isEmpty) {
          continue;
        }
        expect(
          find.text(_modelSummary(listed), findRichText: true),
          findsOneWidget,
        );
        expect(find.text(_emptyTitle), findsNothing);
      }
    },
  );

  testWidgets(
    'test_tasks_screen_build_page_property_column_labels_on_wide_windows',
    (WidgetTester tester) async {
      final Random random = seededRandom(116207);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TasksScene scene = buildTasksScene(random, leastTaskCount: 1);
        await openTasksPage(
          tester,
          random: random,
          dependencies: scene.dependencies,
        );

        final bool showsList = scene.tasks.listTasks().isNotEmpty;
        final bool showsHeadings = showsList && !_isCompact(tester);
        for (final String label in _columnLabels.skip(1)) {
          final Finder heading = find.descendant(
            of: find.byType(TasksScreen),
            matching: find.text(label),
          );
          expect(heading.evaluate().isNotEmpty, showsHeadings, reason: label);
        }
      }
    },
  );
}
