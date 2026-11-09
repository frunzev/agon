import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'workspace_switcher_inputs.dart';

const SectionRoute _projectsRoute = SectionRoute(AppSection.projects);

String _rowSubtitle(WidgetTester tester, Workspace workspace) {
  final WorkspaceRepository workspaces = tester
      .widget<WorkspaceSwitcherDialog>(find.byType(WorkspaceSwitcherDialog))
      .workspaceRepository;
  final int index = workspaces.listWorkspaces().indexOf(workspace);
  final ListRowMain row = findSwitcherRows(tester)[index];
  return row.subtitle.single.text;
}

void main() {
  testWidgets('test_build_window_overlay_property_scrim_tap_returns_to_'
      'projects', (WidgetTester tester) async {
    final Random random = seededRandom(1062411);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      final Workspace current = page.dependencies.workspaceRepository
          .currentWorkspace();

      await tester.tapAt(const Offset(1, 1));
      await pumpFrames(tester);

      expect(page.navigation.routes, const <AppRoute>[_projectsRoute]);
      expect(
        page.dependencies.workspaceRepository.currentWorkspace().id,
        current.id,
      );
    }
  });

  testWidgets('test_build_window_overlay_property_scrim_is_labelled_close', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062412);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openRandomSwitcher(tester, random);

      final ModalBarrier scrim = tester.widget(findSwitcherScrim());

      expect(scrim.semanticsLabel, 'Close');
      expect(scrim.onDismiss, isNotNull);
    }
  });

  testWidgets('test_build_dialog_property_follows_new_workspaces', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062413);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      final WorkspaceRepository workspaces =
          page.dependencies.workspaceRepository;
      final String name = 'made-${random.nextInt(1 << 20)}';

      await workspaces.createWorkspace(name: name);
      await pumpFrames(tester);

      final List<String> titles = <String>[
        for (final ListRowMain row in findSwitcherRows(tester)) row.title,
      ];
      expect(titles, contains(name));
      expect(titles, hasLength(workspaces.listWorkspaces().length));
    }
  });

  testWidgets('test_build_dialog_property_follows_new_projects', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062414);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      final Workspace current = page.dependencies.workspaceRepository
          .currentWorkspace();
      final int before = page.dependencies.projectRepository
          .listProjects(current.id)
          .length;

      await page.dependencies.projectRepository.createProject(
        ProjectDraft(
          workspaceId: current.id,
          name: 'made-${random.nextInt(1 << 20)}',
          repositories: const <Repository>[],
          approvalPolicy: null,
        ),
      );
      await pumpFrames(tester);

      final String expectedCount = before + 1 == 1
          ? '1 project'
          : '${before + 1} projects';
      expect(_rowSubtitle(tester, current), startsWith(expectedCount));
    }
  });

  testWidgets('test_build_dialog_property_follows_an_outside_switch', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062415);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      final FakeWorkspaceRepository workspaces =
          page.dependencies.workspaceRepository as FakeWorkspaceRepository;
      final Workspace target = pickOne(random, workspaces.listWorkspaces());

      await workspaces.switchWorkspace(target.id);
      await pumpFrames(tester);

      final State<WorkspaceSwitcherDialog> dialog = tester.state(
        find.byType(WorkspaceSwitcherDialog),
      );
      expect(dialog.mounted, isTrue);
      expect(find.text(switchWorkspaceTitle), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);
    }
  });
}
