import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'workspace_switcher_inputs.dart';

const SectionRoute _projectsRoute = SectionRoute(AppSection.projects);

WorkspaceSwitcherScreen _buildScreen(
  AppDependencies dependencies, {
  Key? key,
}) {
  return WorkspaceSwitcherScreen(
    dependencies: dependencies,
    navigation: AppNavigation(initialRoute: const WorkspaceSwitcherRoute()),
    key: key,
  );
}

void main() {
  test('test_workspace_switcher_screen_new_property_keeps_dependencies', () {
    final Random random = seededRandom(1062401);

    for (int i = 0; i < propertyIterations ~/ 20; i += 1) {
      final AppDependencies dependencies = buildSwitcherDependencies(random);

      expect(_buildScreen(dependencies).dependencies, same(dependencies));
    }
  });

  test('test_workspace_switcher_screen_new_property_keeps_navigation', () {
    final AppNavigation navigation = AppNavigation(
      initialRoute: const WorkspaceSwitcherRoute(),
    );

    final WorkspaceSwitcherScreen screen = WorkspaceSwitcherScreen(
      dependencies: buildGalleryDependencies(),
      navigation: navigation,
    );

    expect(screen.navigation, same(navigation));
  });

  test('test_workspace_switcher_screen_new_property_keeps_the_key', () {
    final Random random = seededRandom(1062403);
    final AppDependencies dependencies = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(1 << 30));

      expect(_buildScreen(dependencies, key: key).key, key);
    }
  });

  test('test_workspace_switcher_screen_create_state_property_fresh', () {
    final WorkspaceSwitcherScreen screen = _buildScreen(
      buildGalleryDependencies(),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final State<WorkspaceSwitcherScreen> first = screen.createState();

      expect(identical(first, screen.createState()), isFalse);
      expect(first.mounted, isFalse);
    }
  });

  testWidgets('test_workspace_switcher_screen_create_state_property_serves_'
      'its_widget', (WidgetTester tester) async {
    final Random random = seededRandom(1062405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openRandomSwitcher(tester, random);
      final Finder screen = find.byType(WorkspaceSwitcherScreen);

      final State<WorkspaceSwitcherScreen> state = tester.state(screen);

      expect(state.widget, same(tester.widget(screen)));
      expect(screen, findsOneWidget);
    }
  });

  testWidgets('test_workspace_switcher_screen_init_state_property_dialog_'
      'shows_at_once', (WidgetTester tester) async {
    final Random random = seededRandom(1062406);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openRandomSwitcher(tester, random);

      expect(find.byType(WorkspaceSwitcherDialog), findsOneWidget);
      expect(find.text(switchWorkspaceTitle), findsOneWidget);
      expect(findSwitcherScrim(), findsOneWidget);
    }
  });

  testWidgets('test_workspace_switcher_screen_init_state_property_resizing_'
      'keeps_one_dialog', (WidgetTester tester) async {
    final Random random = seededRandom(1062407);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openRandomSwitcher(tester, random);

      tester.view.physicalSize = randomPageWindowSize(random);
      await pumpFrames(tester);

      expect(find.byType(WorkspaceSwitcherDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_workspace_switcher_screen_build_property_projects_lie_'
      'beneath', (WidgetTester tester) async {
    final Random random = seededRandom(1062408);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      final Workspace current = page.dependencies.workspaceRepository
          .currentWorkspace();
      final List<Project> projects = page.dependencies.projectRepository
          .listProjects(current.id);

      expect(find.byType(ProjectsScreen), findsOneWidget);
      final Matcher emptyState = projects.isEmpty
          ? findsOneWidget
          : findsNothing;
      expect(find.text('No projects yet'), emptyState);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_workspace_switcher_screen_build_property_scrim_covers_'
      'the_projects', (WidgetTester tester) async {
    final Random random = seededRandom(1062409);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openRandomSwitcher(tester, random);

      final Rect scrim = tester.getRect(findSwitcherScrim());
      final Rect projects = tester.getRect(find.byType(ProjectsScreen));

      expect(scrim.contains(projects.center), isTrue);
      expect(scrim.width, greaterThanOrEqualTo(projects.width));
    }
  });

  testWidgets('test_workspace_switcher_screen_build_property_switching_'
      'shows_the_new_projects', (WidgetTester tester) async {
    final Random random = seededRandom(1062410);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      final WorkspaceRepository workspaces =
          page.dependencies.workspaceRepository;
      final Workspace target = pickOne(random, workspaces.listWorkspaces());

      await workspaces.switchWorkspace(target.id);
      await pumpFrames(tester);

      final int currentLabels = find.text('Current').evaluate().length;
      expect(currentLabels, 1);
      expect(find.byType(ProjectsScreen), findsOneWidget);
    }
  });

  testWidgets('test_workspace_switcher_screen_create_state_property_new_'
      'state_per_opening', (WidgetTester tester) async {
    final Random random = seededRandom(1062416);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      final State<WorkspaceSwitcherScreen> first = tester.state(
        find.byType(WorkspaceSwitcherScreen),
      );
      page.navigation.returnTo(_projectsRoute);
      await pumpFrames(tester);

      page.navigation.openRoute(const WorkspaceSwitcherRoute());
      await pumpFrames(tester);

      final State<WorkspaceSwitcherScreen> second = tester.state(
        find.byType(WorkspaceSwitcherScreen),
      );
      expect(identical(first, second), isFalse);
      expect(first.mounted, isFalse);
    }
  });

  testWidgets('test_workspace_switcher_screen_init_state_property_first_'
      'frame_has_the_dialog', (WidgetTester tester) async {
    final Random random = seededRandom(1062417);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      page.navigation.returnTo(_projectsRoute);
      await pumpFrames(tester);

      page.navigation.openRoute(const WorkspaceSwitcherRoute());
      await tester.pump();

      expect(find.byType(WorkspaceSwitcherDialog), findsOneWidget);
      expect(findSwitcherScrim(), findsOneWidget);
    }
  });
}
