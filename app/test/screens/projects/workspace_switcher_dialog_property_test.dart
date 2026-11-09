import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'workspace_switcher_inputs.dart';

const SectionRoute _projectsRoute = SectionRoute(AppSection.projects);
const String _note =
    'Each workspace has its own projects and picks which of your '
    'devices it uses. Devices are paired once for all of them.';

WorkspaceSwitcherDialog _buildDialog(
  AppDependencies dependencies, {
  Key? key,
}) {
  return WorkspaceSwitcherDialog(
    workspaceRepository: dependencies.workspaceRepository,
    projectRepository: dependencies.projectRepository,
    runnerRepository: dependencies.runnerRepository,
    deviceRepository: dependencies.deviceRepository,
    navigation: AppNavigation(initialRoute: _projectsRoute),
    key: key,
  );
}

List<String> _rowTitles(WidgetTester tester) {
  return <String>[
    for (final ListRowMain row in findSwitcherRows(tester)) row.title,
  ];
}

List<String> _workspaceNames(AppDependencies dependencies) {
  return <String>[
    for (final Workspace workspace
        in dependencies.workspaceRepository.listWorkspaces())
      workspace.name,
  ];
}

void main() {
  test('test_workspace_switcher_dialog_new_property_keeps_repositories', () {
    final Random random = seededRandom(1062001);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final AppDependencies dependencies = buildSwitcherDependencies(random);

      final WorkspaceSwitcherDialog dialog = _buildDialog(dependencies);

      expect(
        dialog.workspaceRepository,
        same(dependencies.workspaceRepository),
      );
      expect(dialog.projectRepository, same(dependencies.projectRepository));
      expect(dialog.runnerRepository, same(dependencies.runnerRepository));
      expect(dialog.deviceRepository, same(dependencies.deviceRepository));
    }
  });

  test('test_workspace_switcher_dialog_new_property_keeps_navigation', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = AppNavigation(
      initialRoute: _projectsRoute,
    );

    final WorkspaceSwitcherDialog dialog = WorkspaceSwitcherDialog(
      workspaceRepository: dependencies.workspaceRepository,
      projectRepository: dependencies.projectRepository,
      runnerRepository: dependencies.runnerRepository,
      deviceRepository: dependencies.deviceRepository,
      navigation: navigation,
    );

    expect(dialog.navigation, same(navigation));
  });

  test('test_workspace_switcher_dialog_new_property_keeps_the_key', () {
    final Random random = seededRandom(1062003);
    final AppDependencies dependencies = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(1 << 30));

      expect(_buildDialog(dependencies, key: key).key, key);
    }
  });

  test('test_workspace_switcher_dialog_create_state_property_fresh', () {
    final WorkspaceSwitcherDialog dialog = _buildDialog(
      buildGalleryDependencies(),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final State<WorkspaceSwitcherDialog> first = dialog.createState();
      final State<WorkspaceSwitcherDialog> second = dialog.createState();

      expect(identical(first, second), isFalse);
      expect(first.mounted, isFalse);
    }
  });

  testWidgets('test_workspace_switcher_dialog_create_state_property_starts_'
      'on_the_list', (WidgetTester tester) async {
    final Random random = seededRandom(1062005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openRandomSwitcher(tester, random);
      final Finder dialog = find.byType(WorkspaceSwitcherDialog);

      final State<WorkspaceSwitcherDialog> state = tester.state(dialog);

      expect(state.widget, same(tester.widget(dialog)));
      expect(find.text(switchWorkspaceTitle), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    }
  });

  testWidgets('test_workspace_switcher_dialog_create_state_property_one_'
      'state_per_dialog', (WidgetTester tester) async {
    final Random random = seededRandom(1062006);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openRandomSwitcher(tester, random);

      expect(find.byType(WorkspaceSwitcherDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_workspace_switcher_dialog_build_property_rows_follow_'
      'the_node_order', (WidgetTester tester) async {
    final Random random = seededRandom(1062007);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);

      expect(_rowTitles(tester), _workspaceNames(page.dependencies));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_workspace_switcher_dialog_build_property_one_current_'
      'row', (WidgetTester tester) async {
    final Random random = seededRandom(1062008);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      final int workspaceCount = _workspaceNames(page.dependencies).length;

      final Finder current = find.descendant(
        of: find.byType(WorkspaceSwitcherDialog),
        matching: find.byType(StatusLabel),
      );
      final Finder open = find.descendant(
        of: find.byType(WorkspaceSwitcherDialog),
        matching: find.byType(RowAction),
      );

      expect(current, findsOneWidget);
      expect(tester.widget<StatusLabel>(current).text, 'Current');
      expect(open, findsNWidgets(workspaceCount - 1));
    }
  });

  testWidgets('test_workspace_switcher_dialog_build_property_matches_the_'
      'design_wording', (WidgetTester tester) async {
    final Random random = seededRandom(1062009);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);

      expect(find.text(_note), findsOneWidget);
      for (final String label in <String>['Close', 'Devices']) {
        final Finder shown = find.descendant(
          of: find.byType(WorkspaceSwitcherDialog),
          matching: find.text(label),
        );
        expect(shown, findsOneWidget);
      }
      await tapButtonLabelled(tester, 'Devices');
      expect(page.navigation.routes, const <AppRoute>[
        SectionRoute(AppSection.devices),
      ]);
    }
  });

  testWidgets('test_workspace_switcher_dialog_dispose_property_close_is_'
      'clean', (WidgetTester tester) async {
    final Random random = seededRandom(1062010);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      if (random.nextBool()) {
        await tapButtonLabelled(tester, createWorkspaceLabel);
        await tester.enterText(find.byType(TextField), 'side');
      }

      page.navigation.returnTo(_projectsRoute);
      await pumpFrames(tester);

      expect(find.byType(WorkspaceSwitcherDialog), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_workspace_switcher_dialog_dispose_property_reopening_'
      'starts_over', (WidgetTester tester) async {
    final Random random = seededRandom(1062011);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      await tapButtonLabelled(tester, createWorkspaceLabel);
      await tester.enterText(find.byType(TextField), 'x${random.nextInt(9)}');
      page.navigation.returnTo(_projectsRoute);
      await pumpFrames(tester);

      page.navigation.openRoute(const WorkspaceSwitcherRoute());
      await pumpFrames(tester);

      expect(find.text(switchWorkspaceTitle), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    }
  });

  testWidgets('test_workspace_switcher_dialog_dispose_property_leaves_'
      'workspaces_alone', (WidgetTester tester) async {
    final Random random = seededRandom(1062012);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      final List<String> before = _workspaceNames(page.dependencies);
      final Workspace current = page.dependencies.workspaceRepository
          .currentWorkspace();

      await tapButtonLabelled(tester, 'Close');

      expect(_workspaceNames(page.dependencies), before);
      expect(
        page.dependencies.workspaceRepository.currentWorkspace().id,
        current.id,
      );
    }
  });
}
