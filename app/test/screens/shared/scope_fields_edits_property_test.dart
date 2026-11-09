import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/shared/scope_fields.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';
import 'package:agent_orchestration/widgets/forms/removable_tag.dart';
import 'package:agent_orchestration/widgets/forms/tag_input_field.dart';

import '../../support/random_inputs.dart';
import '../../support/random_scope_catalogs.dart';
import 'support/random_scope_selections.dart';
import 'support/scope_fields_scenes.dart';

String _pickWorkspaceName(Random random, ScopeCatalog catalog) {
  return pickOne(random, catalog.workspaces).name;
}

void main() {
  test('test_scope_fields_property_keeps_every_field', () {
    final Random random = seededRandom(112601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final ScopeSelection selection = randomSelectionIn(random, catalog);
      final List<ScopeSelection> changes = <ScopeSelection>[];
      final Key key = ValueKey<int>(i);

      final ScopeFields fields = ScopeFields(
        key: key,
        catalog: catalog,
        selection: selection,
        onChanged: changes.add,
      );

      expect(fields.catalog, same(catalog));
      expect(fields.selection, same(selection));
      expect(fields.key, key);
      fields.onChanged(selection);
      expect(changes.single, same(selection));
    }
  });

  testWidgets('test_scope_fields_property_shows_the_chosen_tags', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(112602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FieldsScene scene = await pumpRandomScopeFields(tester, random);

      final List<String> workspaceTags = <String>[
        for (final RemovableTag tag in tester.widgetList<RemovableTag>(
          findInScopeField(scopeWorkspacesLabel, RemovableTag),
        ))
          tag.label,
      ];
      expect(workspaceTags, <String>[
        for (final WorkspaceId workspaceId in scene.selection.workspaceIds)
          scene.catalog.nameOfWorkspace(workspaceId),
      ]);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_scope_fields_property_suggests_projects_of_workspaces', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(112603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FieldsScene scene = await pumpRandomScopeFields(tester, random);

      final TagInputField projects = tester.widget<TagInputField>(
        findInScopeField(scopeProjectsLabel, TagInputField),
      );
      expect(projects.suggestions, <String>[
        for (final Project project in scene.catalog.listProjectsIn(
          scene.selection.workspaceIds,
        ))
          project.name,
      ]);
      expect(scene.changes, isEmpty);
    }
  });

  testWidgets(
    'test_scope_fields_add_workspace_property_reports_the_added_workspace',
    (WidgetTester tester) async {
      final Random random = seededRandom(112604);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final FieldsScene scene = await pumpRandomScopeFields(tester, random);
        final String name = _pickWorkspaceName(random, scene.catalog);

        addFieldsTag(tester, scopeWorkspacesLabel, name);

        final ScopeSelection reported = scene.changes.single;
        final WorkspaceId addedId = scene.catalog.findWorkspaceId(name);
        expect(reported.workspaceIds, contains(addedId));
        expect(reported.workspaceIds.toSet(), <WorkspaceId>{
          ...scene.selection.workspaceIds,
          addedId,
        });
      }
    },
  );

  testWidgets(
    'test_scope_fields_add_workspace_property_keeps_projects_inside',
    (WidgetTester tester) async {
      final Random random = seededRandom(112605);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final FieldsScene scene = await pumpRandomScopeFields(tester, random);

        addFieldsTag(
          tester,
          scopeWorkspacesLabel,
          _pickWorkspaceName(random, scene.catalog),
        );

        final ScopeSelection reported = scene.changes.single;
        expect(areProjectsWithinWorkspaces(reported, scene.catalog), isTrue);
        expect(
          isInOrderWithin(reported.projectIds, scene.selection.projectIds),
          isTrue,
        );
      }
    },
  );

  testWidgets(
    'test_scope_fields_add_workspace_property_leaves_the_given_selection',
    (WidgetTester tester) async {
      final Random random = seededRandom(112606);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final FieldsScene scene = await pumpRandomScopeFields(tester, random);
        final List<WorkspaceId> before = List<WorkspaceId>.of(
          scene.selection.workspaceIds,
        );

        addFieldsTag(
          tester,
          scopeWorkspacesLabel,
          _pickWorkspaceName(random, scene.catalog),
        );

        expect(scene.selection.workspaceIds, orderedEquals(before));
        expect(scene.changes, hasLength(1));
      }
    },
  );

  testWidgets('test_scope_fields_remove_workspace_property_reports_it_gone', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(112607);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final FieldsScene scene = await pumpRandomScopeFields(tester, random);
      if (scene.selection.workspaceIds.isEmpty) {
        continue;
      }
      final WorkspaceId removedId = pickOne(
        random,
        scene.selection.workspaceIds,
      );

      removeFieldsTag(
        tester,
        scopeWorkspacesLabel,
        scene.catalog.nameOfWorkspace(removedId),
      );

      expect(scene.changes.single.workspaceIds, <WorkspaceId>[
        for (final WorkspaceId workspaceId in scene.selection.workspaceIds)
          if (workspaceId != removedId) workspaceId,
      ]);
    }
  });

  testWidgets(
    'test_scope_fields_remove_workspace_property_keeps_projects_inside',
    (WidgetTester tester) async {
      final Random random = seededRandom(112608);

      for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
        final FieldsScene scene = await pumpRandomScopeFields(tester, random);
        if (scene.selection.workspaceIds.isEmpty) {
          continue;
        }
        final WorkspaceId removedId = pickOne(
          random,
          scene.selection.workspaceIds,
        );

        removeFieldsTag(
          tester,
          scopeWorkspacesLabel,
          scene.catalog.nameOfWorkspace(removedId),
        );

        final ScopeSelection reported = scene.changes.single;
        expect(areProjectsWithinWorkspaces(reported, scene.catalog), isTrue);
      }
    },
  );

  testWidgets(
    'test_scope_fields_remove_workspace_property_reports_exactly_once',
    (WidgetTester tester) async {
      final Random random = seededRandom(112609);

      for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
        final FieldsScene scene = await pumpRandomScopeFields(tester, random);
        if (scene.selection.workspaceIds.isEmpty) {
          continue;
        }
        final WorkspaceId removedId = pickOne(
          random,
          scene.selection.workspaceIds,
        );

        removeFieldsTag(
          tester,
          scopeWorkspacesLabel,
          scene.catalog.nameOfWorkspace(removedId),
        );

        expect(scene.changes, hasLength(1));
        expect(scene.selection.workspaceIds, contains(removedId));
      }
    },
  );
}
