import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'project_screen_inputs.dart';

const SectionRoute _projectsRoute = SectionRoute(AppSection.projects);

Future<void> _tapButton(WidgetTester tester, String label) async {
  final Finder button = find.widgetWithText(AppButton, label).last;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await pumpFrames(tester);
}

bool _hasRunningTask(ShownProjectPage page) {
  for (final Task task in page.dependencies.taskRepository.listTasks()) {
    final List<Run> runs = page.dependencies.taskRepository.listRuns(task.id);
    if (task.projectId == page.project.id && runs.any(isRunActive)) {
      return true;
    }
  }
  return false;
}

bool _isStored(ShownProjectPage page) {
  try {
    page.findStoredProject();
  } on RecordNotFound {
    return false;
  }
  return true;
}

ScopeCatalogParts _readCatalog(WidgetTester tester) {
  final ProjectRulesSection section = tester.widget(
    find.byType(ProjectRulesSection),
  );
  return (
    workspaces: section.catalog.workspaces,
    projects: section.catalog.projects,
  );
}

typedef ScopeCatalogParts = ({
  List<Workspace> workspaces,
  List<Project> projects,
});

void main() {
  testWidgets('test_open_files_property_row_tap_opens_that_repository', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );
      if (page.project.repositories.isEmpty) {
        continue;
      }
      final int index = random.nextInt(page.project.repositories.length);
      final Repository repository = page.project.repositories[index];
      final Finder title = find.text(
        describeRepositoryPath(repository.address),
      );

      await tester.ensureVisible(title.first);
      await tester.tap(title.first);
      await pumpFrames(tester);

      final AppRoute route = page.navigation.currentRoute;
      expect(route, isA<ProjectFilesRoute>());
      expect(
        describeRepositoryPath((route as ProjectFilesRoute).repositoryAddress),
        describeRepositoryPath(repository.address),
      );
      expect(route.projectId, page.project.id);
    }
  });

  testWidgets('test_open_files_property_browse_files_opens_the_first', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );
      if (page.project.repositories.isEmpty) {
        continue;
      }

      await _tapButton(tester, 'Browse files');

      expect(
        page.navigation.currentRoute,
        ProjectFilesRoute(
          projectId: page.project.id,
          repositoryAddress: page.project.repositories.first.address,
        ),
      );
    }
  });

  testWidgets('test_open_files_property_keeps_the_project_page_below', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );
      if (page.project.repositories.isEmpty) {
        continue;
      }

      await _tapButton(tester, 'Browse files');

      expect(page.navigation.routes, hasLength(2));
      expect(page.navigation.routes.first, ProjectRoute(page.project.id));
    }
  });

  testWidgets('test_review_deletion_property_keeping_changes_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051104);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );

      await _tapButton(tester, 'Delete');
      expect(find.text('Delete ${page.project.name}?'), findsOneWidget);
      await _tapButton(tester, 'Keep project');

      expect(_isStored(page), isTrue);
      expect(page.navigation.currentRoute, ProjectRoute(page.project.id));
      expect(find.text('Delete ${page.project.name}?'), findsNothing);
    }
  });

  testWidgets('test_review_deletion_property_running_task_refuses', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051105);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );
      final bool isRunning = _hasRunningTask(page);

      await _tapButton(tester, 'Delete');
      await _tapButton(tester, 'Delete project');

      expect(tester.takeException(), isNull);
      expect(_isStored(page), isRunning);
      expect(
        page.navigation.currentRoute,
        isRunning ? ProjectRoute(page.project.id) : _projectsRoute,
      );
      expect(
        find.textContaining('is running; cancel its run first'),
        isRunning ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_review_deletion_property_refusal_closes_on_keep', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051106);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );
      if (!_hasRunningTask(page)) {
        continue;
      }

      await _tapButton(tester, 'Delete');
      await _tapButton(tester, 'Delete project');
      await _tapButton(tester, 'Keep project');

      expect(find.textContaining('cancel its run first'), findsNothing);
      expect(find.text(page.project.name), findsWidgets);
    }
  });

  testWidgets('test_build_catalog_property_lists_every_workspace', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051107);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );

      expect(
        _readCatalog(tester).workspaces,
        page.dependencies.workspaceRepository.listWorkspaces(),
      );
    }
  });

  testWidgets('test_build_catalog_property_lists_every_workspace_project', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051108);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );
      final List<ProjectId> expected = <ProjectId>[
        for (final Workspace workspace
            in page.dependencies.workspaceRepository.listWorkspaces())
          for (final Project project
              in page.dependencies.projectRepository.listProjects(
                workspace.id,
              ))
            project.id,
      ];

      expect(
        _readCatalog(tester).projects.map((Project project) => project.id),
        expected,
      );
    }
  });

  testWidgets('test_build_catalog_property_shown_project_is_listed_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051109);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );
      final List<Project> projects = _readCatalog(tester).projects;

      expect(
        projects.where((Project project) => project.id == page.project.id),
        hasLength(1),
      );
    }
  });
}
