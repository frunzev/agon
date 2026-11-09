import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../data/rules/support/mirrored_rule_tables.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'workspace_switcher_inputs.dart';

const SectionRoute _projectsRoute = SectionRoute(AppSection.projects);
const String _nameHint = 'It uses the same app server as this workspace.';
const List<String> _validNames = <String>['side', 'x-2', 'a', 'billing-ui'];

Future<SwitcherPage> _openCreateForm(
  WidgetTester tester,
  Random random,
) async {
  final SwitcherPage page = await openRandomSwitcher(tester, random);
  await tapButtonLabelled(tester, createWorkspaceLabel);
  return page;
}

Future<String> _typeName(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextField), name);
  await tester.pump();
  final TextField field = tester.widget(find.byType(TextField));
  return field.controller!.text;
}

String? _shownProblem(WidgetTester tester) {
  final TextField field = tester.widget(find.byType(TextField));
  return field.decoration!.errorText;
}

List<String> _names(WorkspaceRepository workspaces) {
  return <String>[
    for (final Workspace workspace in workspaces.listWorkspaces())
      workspace.name,
  ];
}

String _uniqueValidName(Random random) {
  return '${pickOne(random, _validNames)}-${random.nextInt(1 << 20)}';
}

void main() {
  final List<SharedNamingCase> namingCases = readSharedNamingCases();

  testWidgets('test_build_create_form_property_shows_name_hint_and_'
      'actions', (WidgetTester tester) async {
    final Random random = seededRandom(1062201);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openCreateForm(tester, random);

      expect(find.text('Name'), findsOneWidget);
      expect(find.text(_nameHint), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Back'), findsOneWidget);
      expect(find.widgetWithText(AppButton, createWorkspaceLabel), findsOne);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_build_create_form_property_back_returns_unchanged', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await _openCreateForm(tester, random);
      final WorkspaceRepository workspaces =
          page.dependencies.workspaceRepository;
      final List<String> before = _names(workspaces);
      await _typeName(tester, _uniqueValidName(random));

      await tapButtonLabelled(tester, 'Back');

      expect(find.text(switchWorkspaceTitle), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(_names(workspaces), before);
    }
  });

  testWidgets('test_build_create_form_property_typing_clears_the_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openCreateForm(tester, random);
      await _typeName(tester, 'Not Valid ${random.nextInt(9)}');
      await tapButtonLabelled(tester, createWorkspaceLabel);
      expect(_shownProblem(tester), isNotNull);

      await _typeName(tester, _uniqueValidName(random));

      expect(_shownProblem(tester), isNull);
    }
  });

  testWidgets('test_create_workspace_property_dialog_agrees_with_the_'
      'naming_table', (WidgetTester tester) async {
    final Random random = seededRandom(1062204);

    for (final SharedNamingCase namingCase in namingCases) {
      final SwitcherPage page = await _openCreateForm(tester, random);
      final WorkspaceRepository workspaces =
          page.dependencies.workspaceRepository;
      final int before = workspaces.listWorkspaces().length;
      final String held = await _typeName(tester, namingCase.name);
      final String? problem = describeNameProblem(held.trim());

      await tapButtonLabelled(tester, createWorkspaceLabel);

      final String reason = 'name ${namingCase.name}';
      final int expectedCount = problem == null ? before + 1 : before;
      expect(workspaces.listWorkspaces(), hasLength(expectedCount));
      if (problem == null) {
        expect(workspaces.currentWorkspace().name, held.trim());
        expect(page.navigation.routes, const <AppRoute>[_projectsRoute]);
      } else {
        expect(_shownProblem(tester), problem, reason: reason);
      }
    }
  });

  testWidgets('test_create_workspace_property_double_tap_creates_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await _openCreateForm(tester, random);
      final WorkspaceRepository workspaces =
          page.dependencies.workspaceRepository;
      final int before = workspaces.listWorkspaces().length;
      final String name = _uniqueValidName(random);
      await _typeName(tester, name);
      final Finder button = find.widgetWithText(
        AppButton,
        createWorkspaceLabel,
      );

      await tester.tap(button.last);
      await tester.tap(button.last);
      await pumpFrames(tester);

      expect(workspaces.listWorkspaces(), hasLength(before + 1));
      expect(workspaces.currentWorkspace().name, name);
    }
  });

  testWidgets('test_create_workspace_property_padded_names_are_trimmed', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062206);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await _openCreateForm(tester, random);
      final String name = _uniqueValidName(random);
      await _typeName(tester, '  $name\t');

      await tapButtonLabelled(tester, createWorkspaceLabel);

      final Workspace current = page.dependencies.workspaceRepository
          .currentWorkspace();
      expect(current.name, name);
    }
  });

  testWidgets('test_create_then_switch_property_created_joins_in_id_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062207);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await _openCreateForm(tester, random);
      final String name = _uniqueValidName(random);
      await _typeName(tester, name);
      await tapButtonLabelled(tester, createWorkspaceLabel);

      page.navigation.openRoute(const WorkspaceSwitcherRoute());
      await pumpFrames(tester);

      final List<String> titles = <String>[
        for (final row in findSwitcherRows(tester)) row.title,
      ];
      expect(titles, _names(page.dependencies.workspaceRepository));
      expect(titles, contains(name));
    }
  });

  testWidgets('test_create_then_switch_property_keeps_every_other_'
      'workspace', (WidgetTester tester) async {
    final Random random = seededRandom(1062208);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await _openCreateForm(tester, random);
      final WorkspaceRepository workspaces =
          page.dependencies.workspaceRepository;
      final List<String> before = _names(workspaces);
      final String name = _uniqueValidName(random);
      await _typeName(tester, name);

      await tapButtonLabelled(tester, createWorkspaceLabel);

      final List<String> after = _names(workspaces);
      expect(after, hasLength(before.length + 1));
      for (final String previous in before) {
        expect(after, contains(previous));
      }
    }
  });

  testWidgets('test_create_then_switch_property_new_workspace_is_current', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1062209);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SwitcherPage page = await _openCreateForm(tester, random);
      final String name = _uniqueValidName(random);
      await _typeName(tester, name);

      await tapButtonLabelled(tester, createWorkspaceLabel);

      final Workspace current = page.dependencies.workspaceRepository
          .currentWorkspace();
      expect(current.name, name);
      expect(find.text('No projects yet'), findsOneWidget);
    }
  });
}
