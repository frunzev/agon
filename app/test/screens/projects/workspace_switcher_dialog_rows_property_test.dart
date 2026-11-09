import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'workspace_switcher_inputs.dart';

const SectionRoute _projectsRoute = SectionRoute(AppSection.projects);

String _describeExpectedContents(
  AppDependencies dependencies,
  Workspace workspace,
) {
  return describeWorkspaceContents(
    projectCount: dependencies.projectRepository
        .listProjects(workspace.id)
        .length,
    runnerCount: countWorkspaceRunners(
      workspaceId: workspace.id,
      runners: dependencies.runnerRepository.listRunners(),
      devices: dependencies.deviceRepository.listDevices(),
    ),
  );
}

Finder _findRowMain(WorkspaceRepository workspaces, Workspace workspace) {
  final int index = workspaces.listWorkspaces().indexOf(workspace);
  final Finder rows = find.descendant(
    of: find.byType(WorkspaceSwitcherDialog),
    matching: find.byType(ListRowMain),
  );
  return rows.at(index);
}

int _countNamed(List<String> names, String name) {
  int count = 0;
  for (final String listed in names) {
    if (listed == name) {
      count += 1;
    }
  }
  return count;
}

Workspace? _pickOtherWorkspace(Random random, WorkspaceRepository workspaces) {
  final List<Workspace> others = <Workspace>[
    for (final Workspace workspace in workspaces.listWorkspaces())
      if (workspace.id != workspaces.currentWorkspace().id) workspace,
  ];
  if (others.isEmpty) {
    return null;
  }
  return pickOne(random, others);
}

Future<void> _tapRow(
  WidgetTester tester,
  WorkspaceRepository workspaces,
  Workspace workspace,
) async {
  final Finder row = find.descendant(
    of: _findRowMain(workspaces, workspace),
    matching: find.text(workspace.name),
  );
  await tester.ensureVisible(row);
  await pumpFrames(tester);
  await tester.tap(row);
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_build_row_property_contents_agree_with_the_counts', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      final List<Workspace> workspaces = page.dependencies.workspaceRepository
          .listWorkspaces();

      final List<ListRowMain> rows = findSwitcherRows(tester);

      expect(rows, hasLength(workspaces.length));
      for (int index = 0; index < rows.length; index += 1) {
        final String expected = _describeExpectedContents(
          page.dependencies,
          workspaces[index],
        );
        expect(rows[index].subtitle.single.text, expected);
      }
    }
  });

  testWidgets('test_build_row_property_repeated_names_keep_their_rows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      final List<String> names = <String>[
        for (final Workspace workspace
            in page.dependencies.workspaceRepository.listWorkspaces())
          workspace.name,
      ];

      final List<String> titles = <String>[
        for (final ListRowMain row in findSwitcherRows(tester)) row.title,
      ];

      for (final String name in names) {
        expect(_countNamed(titles, name), _countNamed(names, name));
      }
    }
  });

  testWidgets('test_build_row_property_current_label_sits_on_the_current_'
      'row', (WidgetTester tester) async {
    final Random random = seededRandom(1062103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      final WorkspaceRepository workspaces =
          page.dependencies.workspaceRepository;
      final Workspace current = workspaces.currentWorkspace();
      final Finder label = find.descendant(
        of: find.byType(WorkspaceSwitcherDialog),
        matching: find.byType(StatusLabel),
      );
      await tester.ensureVisible(label);
      await pumpFrames(tester);

      final Rect labelBox = tester.getRect(label);
      final Rect rowMain = tester.getRect(_findRowMain(workspaces, current));

      expect(labelBox.center.dy, greaterThanOrEqualTo(rowMain.top - 0.5));
      expect(labelBox.center.dy, lessThanOrEqualTo(rowMain.bottom + 24));
    }
  });

  testWidgets('test_close_property_close_button_returns_to_projects', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062104);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);

      await tapButtonLabelled(tester, 'Close');

      expect(page.navigation.routes, const <AppRoute>[_projectsRoute]);
      expect(find.byType(WorkspaceSwitcherDialog), findsNothing);
    }
  });

  testWidgets('test_close_property_current_row_returns_without_switching', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062105);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      final WorkspaceRepository workspaces =
          page.dependencies.workspaceRepository;
      final Workspace current = workspaces.currentWorkspace();

      await _tapRow(tester, workspaces, current);

      expect(page.navigation.routes, const <AppRoute>[_projectsRoute]);
      expect(workspaces.currentWorkspace().id, current.id);
    }
  });

  testWidgets('test_close_property_pops_back_to_the_projects_below', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062106);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      page.navigation.openSection(_projectsRoute);
      page.navigation.openRoute(const WorkspaceSwitcherRoute());
      await pumpFrames(tester);

      await tapButtonLabelled(tester, 'Close');

      expect(page.navigation.routes, const <AppRoute>[_projectsRoute]);
    }
  });

  testWidgets('test_open_workspace_property_tapped_row_becomes_current', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062107);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      final WorkspaceRepository workspaces =
          page.dependencies.workspaceRepository;
      final Workspace? other = _pickOtherWorkspace(random, workspaces);
      if (other == null) {
        continue;
      }

      await _tapRow(tester, workspaces, other);

      expect(workspaces.currentWorkspace().id, other.id);
      expect(page.navigation.routes, const <AppRoute>[_projectsRoute]);
    }
  });

  testWidgets('test_open_workspace_property_projects_page_shows_the_'
      'opened_workspace', (WidgetTester tester) async {
    final Random random = seededRandom(1062108);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await openRandomSwitcher(tester, random);
      final WorkspaceRepository workspaces =
          page.dependencies.workspaceRepository;
      final Workspace? other = _pickOtherWorkspace(random, workspaces);
      if (other == null) {
        continue;
      }

      await _tapRow(tester, workspaces, other);

      final List<Project> projects = page.dependencies.projectRepository
          .listProjects(other.id);
      final bool isEmpty = projects.isEmpty;
      final Matcher emptyState = isEmpty ? findsOneWidget : findsNothing;
      expect(find.text('No projects yet'), emptyState);
      for (final Project project in projects) {
        expect(find.text(project.name), findsWidgets);
      }
    }
  });
}
