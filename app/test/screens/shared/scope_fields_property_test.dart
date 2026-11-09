import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';
import 'package:agent_orchestration/screens/shared/scope_fields.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/random_nowhere_scopes.dart';
import '../../support/sample_scopes.dart';
import '../../support/widget_harness.dart';

const String _workspacesLabel = 'Workspaces';
const String _projectsLabel = 'Projects';
const String _allWorkspacesHint = 'All workspaces unless you add some.';
const String _allProjectsHint =
    'All projects unless you add some, from the workspaces above.';
const String _noWorkspaceLeftHint =
    'Nowhere: its workspaces are gone. It stays off until you add one.';
const String _noProjectLeftHint =
    'Nowhere: its projects are gone. It stays off until you add one.';

final class _ScopeFieldsProbe {
  _ScopeFieldsProbe(this.selection);

  final ScopeSelection selection;
  final List<ScopeSelection> changes = <ScopeSelection>[];

  Widget build() {
    return ScopeFields(
      catalog: galleryCatalog,
      selection: selection,
      onChanged: changes.add,
    );
  }
}

Future<_ScopeFieldsProbe> _pumpFields(
  WidgetTester tester,
  Random random,
  Scope scope,
) async {
  final _ScopeFieldsProbe probe = _ScopeFieldsProbe(
    ScopeSelection.fromScope(scope),
  );
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(tester, width: width, child: probe.build());
  return probe;
}

void _expectHint({
  required String label,
  required bool isNowhere,
  required String nowhereHint,
  required String defaultHint,
}) {
  final String shownHint = isNowhere ? nowhereHint : defaultHint;
  final String hiddenHint = isNowhere ? defaultHint : nowhereHint;

  expect(findFieldText(label, shownHint), findsOneWidget);
  expect(find.text(hiddenHint), findsNothing);
}

List<String> _listFreeWorkspaceNames(ScopeSelection selection) {
  return <String>[
    for (final Workspace workspace in galleryCatalog.workspaces)
      if (!selection.workspaceIds.contains(workspace.id)) workspace.name,
  ];
}

List<String> _listFreeProjectNames(ScopeSelection selection) {
  return <String>[
    for (final Project project in galleryCatalog.listProjectsIn(
      selection.workspaceIds,
    ))
      if (!selection.projectIds.contains(project.id)) project.name,
  ];
}

void main() {
  testWidgets('test_scope_fields_build_property_nowhere_hint_per_empty_list', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(51401);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Scope scope = randomScopeOrNowhere(random);

      await _pumpFields(tester, random, scope);

      expect(tester.takeException(), isNull);
      _expectHint(
        label: _workspacesLabel,
        isNowhere: listsNoWorkspace(scope.workspaces),
        nowhereHint: _noWorkspaceLeftHint,
        defaultHint: _allWorkspacesHint,
      );
      _expectHint(
        label: _projectsLabel,
        isNowhere: listsNoProject(scope.projects),
        nowhereHint: _noProjectLeftHint,
        defaultHint: _allProjectsHint,
      );
    }
  });

  testWidgets('test_scope_fields_build_property_every_listed_place_is_a_tag', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(51402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Scope scope = randomScopeOrNowhere(random);

      final _ScopeFieldsProbe probe = await _pumpFields(tester, random, scope);

      for (final WorkspaceId workspaceId in probe.selection.workspaceIds) {
        final String name = galleryCatalog.nameOfWorkspace(workspaceId);
        expect(findFieldText(_workspacesLabel, name), findsOneWidget);
      }
      for (final ProjectId projectId in probe.selection.projectIds) {
        final String name = galleryCatalog.nameOfProject(projectId);
        expect(findFieldText(_projectsLabel, name), findsOneWidget);
      }
    }
  });

  testWidgets('test_scope_fields_build_property_adding_a_place_ends_nowhere', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(51403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Scope scope = randomScopeListingNoPlace(random);
      final _ScopeFieldsProbe probe = await _pumpFields(tester, random, scope);
      final List<String> freeWorkspaces = _listFreeWorkspaceNames(
        probe.selection,
      );
      final List<String> freeProjects = _listFreeProjectNames(probe.selection);

      if (freeWorkspaces.isNotEmpty) {
        final String added = pickOne(random, freeWorkspaces);
        await addFieldTag(tester, label: _workspacesLabel, tag: added);
      } else {
        final String added = pickOne(random, freeProjects);
        await addFieldTag(tester, label: _projectsLabel, tag: added);
      }

      expect(probe.changes, hasLength(1));
      expect(listsNoPlace(probe.changes.single.toScope()), isFalse);
    }
  });
}
