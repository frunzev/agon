import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';

import '../screens/new_items/draft_record_fields.dart';
import '../support/random_inputs.dart';
import '../support/random_scope_catalogs.dart';
import '../support/random_unknown_scope_places.dart';
import '../support/sample_scopes.dart';

List<WorkspaceId> _keptWorkspaces(ScopeCatalog catalog, Scope scope) {
  final WorkspaceScope kept = catalog.keepKnownPlaces(scope).workspaces;
  if (kept is! OnlyWorkspaces) {
    throw StateError('the workspaces were listed but came back as all');
  }
  return kept.workspaces;
}

List<ProjectId> _keptProjects(ScopeCatalog catalog, Scope scope) {
  final ProjectScope kept = catalog.keepKnownPlaces(scope).projects;
  if (kept is! OnlyProjects) {
    throw StateError('the projects were listed but came back as all');
  }
  return kept.projects;
}

Scope _listingWorkspaces(List<WorkspaceId> workspaceIds) {
  return Scope(
    workspaces: OnlyWorkspaces(workspaceIds),
    projects: const AllProjects(),
  );
}

Scope _listingProjects(List<ProjectId> projectIds) {
  return Scope(
    workspaces: const AllWorkspaces(),
    projects: OnlyProjects(projectIds),
  );
}

void main() {
  test('test_keep_known_workspaces_property_all_workspaces_stay_all', () {
    final Random random = seededRandom(112201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = Scope(
        workspaces: const AllWorkspaces(),
        projects: randomScopeWithUnknownPlaces(random, catalog).projects,
      );

      expect(catalog.keepKnownPlaces(scope).workspaces, isA<AllWorkspaces>());
    }
  });

  test('test_keep_known_workspaces_property_known_ones_keep_their_order', () {
    final Random random = seededRandom(112202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<WorkspaceId> known = pickSome(
        random,
        listCatalogWorkspaceIds(catalog),
      ).reversed.toList();
      final Scope scope = _listingWorkspaces(
        mixInUnknownWorkspaces(random, known),
      );

      expect(_keptWorkspaces(catalog, scope), known);
    }
  });

  test('test_keep_known_workspaces_property_unknown_ones_leave_an_empty_'
      'list', () {
    final Random random = seededRandom(112203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = _listingWorkspaces(
        mixInUnknownWorkspaces(random, const <WorkspaceId>[]),
      );

      expect(_keptWorkspaces(catalog, scope), isEmpty);
    }
  });

  test('test_keep_known_projects_property_all_projects_stay_all', () {
    final Random random = seededRandom(112204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = Scope(
        workspaces: randomScopeWithUnknownPlaces(random, catalog).workspaces,
        projects: const AllProjects(),
      );

      expect(catalog.keepKnownPlaces(scope).projects, isA<AllProjects>());
    }
  });

  test('test_keep_known_projects_property_known_ones_keep_their_order', () {
    final Random random = seededRandom(112205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<ProjectId> known = pickSome(
        random,
        listCatalogProjectIds(catalog),
      ).reversed.toList();
      final Scope scope = _listingProjects(
        mixInUnknownProjects(random, known),
      );

      expect(_keptProjects(catalog, scope), known);
    }
  });

  test('test_keep_known_projects_property_unknown_ones_leave_an_empty_'
      'list', () {
    final Random random = seededRandom(112206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = _listingProjects(
        mixInUnknownProjects(random, const <ProjectId>[]),
      );

      expect(_keptProjects(catalog, scope), isEmpty);
    }
  });

  test('test_knows_workspace_property_every_catalog_workspace_is_known', () {
    final Random random = seededRandom(112207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<WorkspaceId> all = listCatalogWorkspaceIds(catalog);

      expect(_keptWorkspaces(catalog, _listingWorkspaces(all)), all);
    }
  });

  test('test_knows_workspace_property_only_exact_ids_match', () {
    final Random random = seededRandom(112208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final WorkspaceId known = pickOne(
        random,
        listCatalogWorkspaceIds(catalog),
      );
      final List<WorkspaceId> nearMisses = <WorkspaceId>[
        WorkspaceId(known.value.toUpperCase()),
        WorkspaceId(' ${known.value}'),
        WorkspaceId('${known.value}-'),
      ];

      expect(
        _keptWorkspaces(catalog, _listingWorkspaces(nearMisses)),
        isEmpty,
      );
    }
  });

  test('test_knows_workspace_property_project_ids_are_not_workspaces', () {
    final Random random = seededRandom(112209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<WorkspaceId> projectIdsAsWorkspaces = <WorkspaceId>[
        for (final ProjectId projectId in listCatalogProjectIds(catalog))
          WorkspaceId(projectId.value),
      ];
      final Scope scope = _listingWorkspaces(projectIdsAsWorkspaces);

      expect(_keptWorkspaces(catalog, scope), isEmpty);
    }
  });

  test('test_knows_project_property_every_catalog_project_is_known', () {
    final Random random = seededRandom(112210);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<ProjectId> all = listCatalogProjectIds(catalog);

      expect(_keptProjects(catalog, _listingProjects(all)), all);
    }
  });

  test('test_knows_project_property_only_exact_ids_match', () {
    final Random random = seededRandom(112211);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<ProjectId> projectIds = listCatalogProjectIds(catalog);
      if (projectIds.isEmpty) {
        continue;
      }
      final ProjectId known = pickOne(random, projectIds);
      final List<ProjectId> nearMisses = <ProjectId>[
        ProjectId(known.value.toUpperCase()),
        ProjectId('${known.value} '),
        ProjectId('x${known.value}'),
      ];

      expect(_keptProjects(catalog, _listingProjects(nearMisses)), isEmpty);
    }
  });

  test('test_knows_project_property_workspace_ids_are_not_projects', () {
    final Random random = seededRandom(112212);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = _listingProjects(<ProjectId>[
        for (final WorkspaceId workspaceId in listCatalogWorkspaceIds(catalog))
          ProjectId(workspaceId.value),
      ]);

      expect(describeScopeFields(catalog.keepKnownPlaces(scope)), <Object?>[
        'all workspaces',
        'only projects',
      ]);
    }
  });
}
