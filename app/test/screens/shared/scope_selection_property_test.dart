import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';

import '../../support/random_inputs.dart';
import '../../support/random_scope_catalogs.dart';
import '../../support/sample_scopes.dart';
import 'support/random_scope_selections.dart';

void main() {
  test('test_scope_selection_property_keeps_ids_in_order', () {
    final Random random = seededRandom(112501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<WorkspaceId> workspaceIds = pickSome(
        random,
        listCatalogWorkspaceIds(catalog),
      );
      final List<ProjectId> projectIds = pickSome(
        random,
        listCatalogProjectIds(catalog),
      );

      final ScopeSelection selection = ScopeSelection(
        workspaceIds: workspaceIds,
        projectIds: projectIds,
      );

      expect(selection.workspaceIds, orderedEquals(workspaceIds));
      expect(selection.projectIds, orderedEquals(projectIds));
    }
  });

  test('test_scope_selection_property_owns_copies_of_the_ids', () {
    final Random random = seededRandom(112502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<WorkspaceId> workspaceIds = listCatalogWorkspaceIds(catalog);
      final List<ProjectId> projectIds = listCatalogProjectIds(catalog);
      final int workspaceCount = workspaceIds.length;
      final int projectCount = projectIds.length;

      final ScopeSelection selection = ScopeSelection(
        workspaceIds: workspaceIds,
        projectIds: projectIds,
      );
      workspaceIds.add(randomUnknownWorkspaceId(random));
      projectIds.add(randomUnknownProjectId(random));

      expect(selection.workspaceIds, hasLength(workspaceCount));
      expect(selection.projectIds, hasLength(projectCount));
      expect(selection.workspaceIds.clear, throwsUnsupportedError);
      expect(selection.projectIds.clear, throwsUnsupportedError);
    }
  });

  test('test_scope_selection_property_never_saves_nowhere', () {
    final Random random = seededRandom(112503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);

      final ScopeSelection selection = randomSelectionIn(random, catalog);

      expect(listsNoPlace(selection.toScope()), isFalse);
    }
  });

  test('test_scope_selection_everywhere_property_'
      'lists_no_place_and_applies_anywhere', () {
    final Random random = seededRandom(112504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = ScopeSelection.everywhere().toScope();

      expect(ScopeSelection.everywhere().workspaceIds, isEmpty);
      expect(ScopeSelection.everywhere().projectIds, isEmpty);
      expect(doesScopeApplyToUnlistedPlaces(random, scope), isTrue);
    }
  });

  test(
    'test_scope_selection_everywhere_property_round_trips_through_its_scope',
    () {
      final Scope scope = ScopeSelection.everywhere().toScope();

      final Scope again = ScopeSelection.fromScope(scope).toScope();

      expect(again.workspaces, isA<AllWorkspaces>());
      expect(again.projects, isA<AllProjects>());
    },
  );

  test('test_scope_selection_everywhere_property_each_call_starts_fresh', () {
    final Random random = seededRandom(112506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final WorkspaceId workspaceId = pickOne(
        random,
        listCatalogWorkspaceIds(catalog),
      );

      final ScopeSelection changed = ScopeSelection.everywhere().withWorkspace(
        workspaceId,
        catalog,
      );

      expect(changed.workspaceIds, <WorkspaceId>[workspaceId]);
      expect(ScopeSelection.everywhere().workspaceIds, isEmpty);
    }
  });

  test('test_scope_selection_with_workspace_property_'
      'a_chosen_workspace_changes_nothing', () {
    final Random random = seededRandom(112507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final ScopeSelection selection = randomSelectionIn(random, catalog);
      if (selection.workspaceIds.isEmpty) {
        continue;
      }

      final ScopeSelection again = selection.withWorkspace(
        pickOne(random, selection.workspaceIds),
        catalog,
      );

      expect(again.workspaceIds, orderedEquals(selection.workspaceIds));
      expect(again.projectIds, orderedEquals(selection.projectIds));
    }
  });

  test('test_scope_selection_with_workspace_property_'
      'appends_and_keeps_projects_inside', () {
    final Random random = seededRandom(112508);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final ScopeSelection selection = randomSelectionIn(random, catalog);
      final WorkspaceId workspaceId = pickOne(
        random,
        listCatalogWorkspaceIds(catalog),
      );

      final ScopeSelection added = selection.withWorkspace(
        workspaceId,
        catalog,
      );

      expect(added.workspaceIds, contains(workspaceId));
      expect(added.workspaceIds.toSet(), hasLength(added.workspaceIds.length));
      expect(areProjectsWithinWorkspaces(added, catalog), isTrue);
    }
  });

  test(
    'test_scope_selection_with_project_property_outside_projects_are_refused',
    () {
      final Random random = seededRandom(112509);

      for (int i = 0; i < propertyIterations; i += 1) {
        final ScopeCatalog catalog = randomScopeCatalog(random);
        final ScopeSelection selection = randomSelectionIn(random, catalog);
        final List<ProjectId> allowed = listAllowedProjectIds(
          catalog,
          selection.workspaceIds,
        );
        final List<ProjectId> outside = <ProjectId>[
          randomUnknownProjectId(random),
          for (final ProjectId projectId in listCatalogProjectIds(catalog))
            if (!allowed.contains(projectId)) projectId,
        ];

        expect(
          () => selection.withProject(pickOne(random, outside), catalog),
          throwsArgumentError,
        );
      }
    },
  );

  test('test_scope_selection_with_project_property_'
      'appends_once_and_keeps_workspaces', () {
    final Random random = seededRandom(112510);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final ScopeSelection selection = randomSelectionIn(random, catalog);
      final List<ProjectId> allowed = listAllowedProjectIds(
        catalog,
        selection.workspaceIds,
      );
      if (allowed.isEmpty) {
        continue;
      }
      final ProjectId projectId = pickOne(random, allowed);

      final ScopeSelection once = selection.withProject(projectId, catalog);
      final ScopeSelection twice = once.withProject(projectId, catalog);

      expect(once.workspaceIds, orderedEquals(selection.workspaceIds));
      expect(
        once.projectIds.where((ProjectId id) => id == projectId),
        hasLength(1),
      );
      expect(twice.projectIds, orderedEquals(once.projectIds));
    }
  });

  test('test_scope_selection_keep_projects_within_property_'
      'removed_workspace_projects_go', () {
    final Random random = seededRandom(112511);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final ScopeSelection selection = randomSelectionIn(random, catalog);
      if (selection.workspaceIds.length < 2) {
        continue;
      }
      final WorkspaceId removed = pickOne(random, selection.workspaceIds);

      final ScopeSelection kept = selection.withoutWorkspace(removed, catalog);

      for (final ProjectId projectId in kept.projectIds) {
        final Project project = catalog.projects.firstWhere(
          (Project candidate) => candidate.id == projectId,
        );
        expect(project.workspaceId, isNot(removed));
      }
    }
  });

  test('test_scope_selection_keep_projects_within_property_'
      'kept_projects_keep_order', () {
    final Random random = seededRandom(112512);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final ScopeSelection selection = randomSelectionIn(random, catalog);
      final WorkspaceId workspaceId = pickOne(
        random,
        listCatalogWorkspaceIds(catalog),
      );

      final ScopeSelection changed = random.nextBool()
          ? selection.withWorkspace(workspaceId, catalog)
          : selection.withoutWorkspace(workspaceId, catalog);

      expect(
        isInOrderWithin(changed.projectIds, selection.projectIds),
        isTrue,
      );
    }
  });

  test('test_scope_selection_keep_projects_within_property_'
      'drops_only_what_must_go', () {
    final Random random = seededRandom(112513);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final ScopeSelection selection = randomSelectionIn(random, catalog);
      final WorkspaceId workspaceId = pickOne(
        random,
        listCatalogWorkspaceIds(catalog),
      );

      final ScopeSelection changed = random.nextBool()
          ? selection.withWorkspace(workspaceId, catalog)
          : selection.withoutWorkspace(workspaceId, catalog);

      final List<ProjectId> allowed = listAllowedProjectIds(
        catalog,
        changed.workspaceIds,
      );
      expect(changed.projectIds, <ProjectId>[
        for (final ProjectId projectId in selection.projectIds)
          if (allowed.contains(projectId)) projectId,
      ]);
    }
  });
}
