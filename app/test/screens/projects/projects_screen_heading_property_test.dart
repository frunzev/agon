import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';

import '../../support/app_harness.dart';
import '../../support/list_harness.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'projects_page_inputs.dart';

Finder _findLinkButton() {
  return find.descendant(
    of: find.byType(WorkspaceLinkButton),
    matching: find.byType(TextButton),
  );
}

bool _isCompact(ProjectsPage page) {
  return LayoutSize.forWidth(page.window.width).isCompact;
}

Future<ProjectsPage> _openWithGalleryProjects(
  WidgetTester tester,
  Random random,
) async {
  final AppDependencies dependencies = buildDependenciesWithProjects(<Project>[
    ...galleryProjects,
    ...randomWorkspaceProjects(random),
  ]);
  final Size window = randomPageWindowSize(random);
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: window,
    route: projectsSectionRoute,
    dependencies: dependencies,
  );
  return (dependencies: dependencies, navigation: navigation, window: window);
}

int _countProjectTasks(ProjectsPage page, Project project) {
  int count = 0;
  for (final Task task in page.dependencies.taskRepository.listTasks()) {
    if (task.projectId == project.id) {
      count += 1;
    }
  }
  return count;
}

String _describeTaskCount(int count) {
  return count == 1 ? '1 task' : '$count tasks';
}

void main() {
  testWidgets('test_projects_screen_build_heading_property_link_only_when_'
      'compact', (WidgetTester tester) async {
    final Random random = seededRandom(1062310);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ProjectsPage page = await openProjectsPage(tester, random);
      final Workspace workspace = page.dependencies.workspaceRepository
          .currentWorkspace();

      expect(
        find.text('${workspace.name} workspace'),
        _isCompact(page) ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_projects_screen_build_heading_property_link_opens_the_'
      'switcher', (WidgetTester tester) async {
    final Random random = seededRandom(1062311);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ProjectsPage page = await openProjectsPage(tester, random);
      if (!_isCompact(page)) {
        continue;
      }

      await tester.tap(_findLinkButton());
      await pumpFrames(tester);

      expect(page.navigation.routes, const <AppRoute>[
        projectsSectionRoute,
        WorkspaceSwitcherRoute(),
      ]);
    }
  });

  testWidgets('test_projects_screen_build_heading_property_link_follows_'
      'the_current_workspace', (WidgetTester tester) async {
    final Random random = seededRandom(1062312);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ProjectsPage page = await openProjectsPage(tester, random);
      if (!_isCompact(page)) {
        continue;
      }
      final Workspace other = pickOne(random, galleryWorkspaces);

      await page.dependencies.workspaceRepository.switchWorkspace(other.id);
      await pumpFrames(tester);

      final Rect link = tester.getRect(_findLinkButton());
      final Rect title = tester.getRect(find.text('Projects').last);
      expect(find.text('${other.name} workspace'), findsOneWidget);
      expect(link.bottom, lessThanOrEqualTo(title.top + 0.5));
    }
  });

  testWidgets('test_projects_screen_build_new_project_button_property_'
      'opens_the_new_project_page', (WidgetTester tester) async {
    final Random random = seededRandom(1062313);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ProjectsPage page = await openProjectsPage(tester, random);

      await tapShownText(tester, 'New project');
      await pumpFrames(tester);

      expect(page.navigation.routes, const <AppRoute>[
        projectsSectionRoute,
        NewProjectRoute(),
      ]);
    }
  });

  testWidgets('test_projects_screen_build_new_project_button_property_is_'
      'a_primary_plus_button', (WidgetTester tester) async {
    final Random random = seededRandom(1062314);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openProjectsPage(tester, random);

      final AppButton button = tester.widget(
        find.widgetWithText(AppButton, 'New project'),
      );

      expect(button.tone, ButtonTone.primary);
      expect(button.icon, AppIconKind.plus);
      expect(button.onPressed, isNotNull);
    }
  });

  testWidgets('test_projects_screen_build_new_project_button_property_'
      'changes_no_data', (WidgetTester tester) async {
    final Random random = seededRandom(1062315);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ProjectsPage page = await openProjectsPage(tester, random);
      final List<String> before = listProjectNames(listCurrentProjects(page));

      await tapShownText(tester, 'New project');
      await pumpFrames(tester);

      expect(listProjectNames(listCurrentProjects(page)), before);
    }
  });

  testWidgets('test_projects_screen_build_row_property_tap_opens_that_'
      'project', (WidgetTester tester) async {
    final Random random = seededRandom(1062316);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ProjectsPage page = await _openWithGalleryProjects(tester, random);
      final List<Project> projects = listCurrentProjects(page);
      if (projects.isEmpty) {
        continue;
      }
      final int index = random.nextInt(projects.length);
      final Finder row = find.descendant(
        of: findProjectRowMains().at(index),
        matching: find.text(projects[index].name),
      );
      await tester.ensureVisible(row);
      await pumpFrames(tester);

      await tester.tap(row);
      await pumpFrames(tester);

      expect(page.navigation.routes, <AppRoute>[
        projectsSectionRoute,
        ProjectRoute(projects[index].id),
      ]);
    }
  });

  testWidgets('test_projects_screen_build_row_property_lists_repo_paths', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062317);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ProjectsPage page = await _openWithGalleryProjects(tester, random);
      final List<Project> projects = listCurrentProjects(page);

      final List<ListRowMain> rows = tester
          .widgetList<ListRowMain>(findProjectRowMains())
          .toList();

      expect(rows, hasLength(projects.length));
      for (int index = 0; index < rows.length; index += 1) {
        final String paths = <String>[
          for (final Repository repository in projects[index].repositories)
            describeRepositoryPath(repository.address),
        ].join(', ');
        expect(rows[index].subtitle.single.text, paths);
      }
    }
  });

  testWidgets('test_projects_screen_build_row_property_counts_each_'
      'project_tasks', (WidgetTester tester) async {
    final Random random = seededRandom(1062318);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ProjectsPage page = await _openWithGalleryProjects(tester, random);
      final Map<String, int> expectedCounts = <String, int>{};
      for (final Project project in listCurrentProjects(page)) {
        final String text = _describeTaskCount(
          _countProjectTasks(page, project),
        );
        expectedCounts[text] = (expectedCounts[text] ?? 0) + 1;
      }

      for (final MapEntry<String, int> entry in expectedCounts.entries) {
        final Finder shown = find.descendant(
          of: find.byType(ProjectsScreen),
          matching: find.text(entry.key),
        );
        expect(shown, findsNWidgets(entry.value), reason: entry.key);
      }
    }
  });
}
