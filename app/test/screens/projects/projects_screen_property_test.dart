import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';

import '../../support/app_harness.dart';
import '../../support/list_harness.dart';
import '../../support/random_inputs.dart';
import 'projects_page_inputs.dart';

void main() {
  test('test_projects_screen_new_property_keeps_every_dependency', () {
    final Random random = seededRandom(1062301);

    for (int i = 0; i < propertyIterations ~/ 20; i += 1) {
      final AppDependencies dependencies = buildDependenciesWithProjects(
        randomWorkspaceProjects(random),
      );
      final AppNavigation navigation = AppNavigation(
        initialRoute: projectsSectionRoute,
      );

      final ProjectsScreen screen = ProjectsScreen(
        projectRepository: dependencies.projectRepository,
        workspaceRepository: dependencies.workspaceRepository,
        taskRepository: dependencies.taskRepository,
        clock: dependencies.clock,
        navigation: navigation,
      );

      expect(screen.projectRepository, same(dependencies.projectRepository));
      expect(
        screen.workspaceRepository,
        same(dependencies.workspaceRepository),
      );
      expect(screen.taskRepository, same(dependencies.taskRepository));
      expect(screen.clock, same(dependencies.clock));
      expect(screen.navigation, same(navigation));
    }
  });

  test('test_projects_screen_new_property_keeps_the_key', () {
    final Random random = seededRandom(1062302);
    final AppDependencies dependencies = buildDependenciesWithProjects(
      const <Project>[],
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(1 << 30));
      final ProjectsScreen screen = ProjectsScreen(
        projectRepository: dependencies.projectRepository,
        workspaceRepository: dependencies.workspaceRepository,
        taskRepository: dependencies.taskRepository,
        clock: dependencies.clock,
        navigation: AppNavigation(initialRoute: projectsSectionRoute),
        key: key,
      );

      expect(screen.key, key);
    }
  });

  testWidgets('test_projects_screen_new_property_one_screen_per_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openProjectsPage(tester, random);

      expect(find.byType(ProjectsScreen), findsOneWidget);
    }
  });

  testWidgets('test_projects_screen_build_property_rows_are_the_current_'
      'workspace_projects', (WidgetTester tester) async {
    final Random random = seededRandom(1062304);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ProjectsPage page = await openProjectsPage(tester, random);

      final List<String> expected = listProjectNames(
        listCurrentProjects(page),
      );
      final String reason = 'window ${page.window}';
      expect(readProjectRowTitles(tester), expected, reason: reason);
      expect(tester.takeException(), isNull, reason: reason);
    }
  });

  testWidgets('test_projects_screen_build_property_follows_new_projects', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062305);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ProjectsPage page = await openProjectsPage(tester, random);
      final Workspace workspace = page.dependencies.workspaceRepository
          .currentWorkspace();
      final String name = 'new-${random.nextInt(1 << 20)}';

      await page.dependencies.projectRepository.createProject(
        ProjectDraft(
          workspaceId: workspace.id,
          name: name,
          repositories: const <Repository>[],
          approvalPolicy: null,
        ),
      );
      await pumpFrames(tester);

      final List<String> expected = listProjectNames(
        listCurrentProjects(page),
      );
      expect(readProjectRowTitles(tester), expected);
      expect(readProjectRowTitles(tester), contains(name));
    }
  });

  testWidgets('test_projects_screen_build_property_follows_a_switch', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062306);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ProjectsPage page = await openProjectsPage(tester, random);
      final Workspace other = pickOne(random, galleryWorkspaces);

      await page.dependencies.workspaceRepository.switchWorkspace(other.id);
      await pumpFrames(tester);

      final List<String> expected = listProjectNames(
        listCurrentProjects(page),
      );
      expect(readProjectRowTitles(tester), expected);
    }
  });

  testWidgets('test_projects_screen_build_page_property_empty_state_only_'
      'without_projects', (WidgetTester tester) async {
    final Random random = seededRandom(1062307);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ProjectsPage page = await openProjectsPage(tester, random);
      final bool isEmpty = listCurrentProjects(page).isEmpty;

      final Matcher shown = isEmpty ? findsOneWidget : findsNothing;
      expect(find.text('No projects yet'), shown);
      expect(
        find.text('Add a project with the repos its tasks should work on.'),
        shown,
      );
    }
  });

  testWidgets('test_projects_screen_build_page_property_summary_only_with_'
      'projects', (WidgetTester tester) async {
    final Random random = seededRandom(1062308);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ProjectsPage page = await openProjectsPage(tester, random);
      final bool hasProjects = listCurrentProjects(page).isNotEmpty;

      expect(
        find.text('Each project holds the repos its tasks work on.'),
        hasProjects ? findsOneWidget : findsNothing,
      );
      expect(find.text('Projects'), findsWidgets);
    }
  });

  testWidgets('test_projects_screen_build_page_property_one_new_project_'
      'button', (WidgetTester tester) async {
    final Random random = seededRandom(1062309);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openProjectsPage(tester, random);

      expect(find.text('New project'), findsOneWidget);
    }
  });
}
