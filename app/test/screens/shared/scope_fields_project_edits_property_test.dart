import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';

import '../../support/random_inputs.dart';
import 'support/random_scope_selections.dart';
import 'support/scope_fields_scenes.dart';

List<ProjectId> _listFreeProjectIds(FieldsScene scene) {
  return <ProjectId>[
    for (final ProjectId projectId in listAllowedProjectIds(
      scene.catalog,
      scene.selection.workspaceIds,
    ))
      if (!scene.selection.projectIds.contains(projectId)) projectId,
  ];
}

void main() {
  testWidgets('test_scope_fields_add_project_property_appends_the_project', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(112701);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final FieldsScene scene = await pumpRandomScopeFields(tester, random);
      final List<ProjectId> free = _listFreeProjectIds(scene);
      if (free.isEmpty) {
        continue;
      }
      final ProjectId projectId = pickOne(random, free);

      addFieldsTag(
        tester,
        scopeProjectsLabel,
        scene.catalog.nameOfProject(projectId),
      );

      expect(scene.changes.single.projectIds, <ProjectId>[
        ...scene.selection.projectIds,
        projectId,
      ]);
    }
  });

  testWidgets(
    'test_scope_fields_add_project_property_chosen_project_stays_single',
    (WidgetTester tester) async {
      final Random random = seededRandom(112702);

      for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
        final FieldsScene scene = await pumpRandomScopeFields(tester, random);
        if (scene.selection.projectIds.isEmpty) {
          continue;
        }
        final ProjectId projectId = pickOne(
          random,
          scene.selection.projectIds,
        );

        addFieldsTag(
          tester,
          scopeProjectsLabel,
          scene.catalog.nameOfProject(projectId),
        );

        expect(
          scene.changes.single.projectIds,
          orderedEquals(scene.selection.projectIds),
        );
      }
    },
  );

  testWidgets('test_scope_fields_add_project_property_keeps_the_workspaces', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(112703);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final FieldsScene scene = await pumpRandomScopeFields(tester, random);
      final List<ProjectId> free = _listFreeProjectIds(scene);
      if (free.isEmpty) {
        continue;
      }

      addFieldsTag(
        tester,
        scopeProjectsLabel,
        scene.catalog.nameOfProject(pickOne(random, free)),
      );

      final ScopeSelection reported = scene.changes.single;
      expect(
        reported.workspaceIds,
        orderedEquals(scene.selection.workspaceIds),
      );
      expect(areProjectsWithinWorkspaces(reported, scene.catalog), isTrue);
    }
  });

  testWidgets(
    'test_scope_fields_remove_project_property_removes_only_that_project',
    (WidgetTester tester) async {
      final Random random = seededRandom(112704);

      for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
        final FieldsScene scene = await pumpRandomScopeFields(tester, random);
        if (scene.selection.projectIds.isEmpty) {
          continue;
        }
        final ProjectId removedId = pickOne(
          random,
          scene.selection.projectIds,
        );

        removeFieldsTag(
          tester,
          scopeProjectsLabel,
          scene.catalog.nameOfProject(removedId),
        );

        expect(scene.changes.single.projectIds, <ProjectId>[
          for (final ProjectId projectId in scene.selection.projectIds)
            if (projectId != removedId) projectId,
        ]);
      }
    },
  );

  testWidgets(
    'test_scope_fields_remove_project_property_keeps_the_workspaces',
    (WidgetTester tester) async {
      final Random random = seededRandom(112705);

      for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
        final FieldsScene scene = await pumpRandomScopeFields(tester, random);
        if (scene.selection.projectIds.isEmpty) {
          continue;
        }

        removeFieldsTag(
          tester,
          scopeProjectsLabel,
          scene.catalog.nameOfProject(
            pickOne(random, scene.selection.projectIds),
          ),
        );

        expect(
          scene.changes.single.workspaceIds,
          orderedEquals(scene.selection.workspaceIds),
        );
      }
    },
  );

  testWidgets(
    'test_scope_fields_remove_project_property_reports_exactly_once',
    (WidgetTester tester) async {
      final Random random = seededRandom(112706);

      for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
        final FieldsScene scene = await pumpRandomScopeFields(tester, random);
        if (scene.selection.projectIds.isEmpty) {
          continue;
        }
        final ProjectId removedId = pickOne(
          random,
          scene.selection.projectIds,
        );

        removeFieldsTag(
          tester,
          scopeProjectsLabel,
          scene.catalog.nameOfProject(removedId),
        );

        expect(scene.changes, hasLength(1));
        expect(scene.selection.projectIds, contains(removedId));
        expect(tester.takeException(), isNull);
      }
    },
  );
}
