import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/presentation/scope_text.dart';

import '../support/random_inputs.dart';
import '../support/random_scope_catalogs.dart';
import '../support/sample_scopes.dart';

const String _everywhereLabel = 'Everywhere';
const String _nowhereLabel = 'Nowhere';

List<WorkspaceId> _someWorkspaceIds(Random random, ScopeCatalog catalog) {
  final List<WorkspaceId> allIds = listCatalogWorkspaceIds(catalog);
  final List<WorkspaceId> picked = pickSome(random, allIds);
  return picked.isEmpty ? <WorkspaceId>[allIds.first] : picked;
}

void main() {
  test('test_name_workspaces_property_one_chip_per_listed_workspace', () {
    final Random random = seededRandom(94201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<WorkspaceId> chosen = _someWorkspaceIds(random, catalog);
      final Scope scope = Scope(
        workspaces: OnlyWorkspaces(chosen),
        projects: const AllProjects(),
      );

      expect(describeScopeChips(scope, catalog), <String>[
        for (final WorkspaceId workspaceId in chosen)
          catalog.nameOfWorkspace(workspaceId),
      ]);
    }
  });

  test('test_name_workspaces_property_all_workspaces_adds_no_name', () {
    final Random random = seededRandom(94202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      if (catalog.projects.isEmpty) {
        continue;
      }
      final ProjectId projectId = pickOne(random, catalog.projects).id;
      final Scope scope = Scope(
        workspaces: const AllWorkspaces(),
        projects: OnlyProjects(<ProjectId>[projectId]),
      );

      expect(describeScopeChips(scope, catalog), <String>[
        catalog.nameOfProject(projectId),
      ]);
    }
  });

  test('test_name_workspaces_property_unknown_workspace_reads_nowhere', () {
    final Random random = seededRandom(94203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = Scope(
        workspaces: OnlyWorkspaces(<WorkspaceId>[
          randomUnknownWorkspaceId(random),
        ]),
        projects: const AllProjects(),
      );

      expect(describeScopeChips(scope, catalog), <String>[_nowhereLabel]);
    }
  });

  test('test_name_projects_property_one_chip_per_listed_project', () {
    final Random random = seededRandom(94204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<ProjectId> chosen = pickSome(
        random,
        listCatalogProjectIds(catalog),
      );
      if (chosen.isEmpty) {
        continue;
      }
      final Scope scope = Scope(
        workspaces: const AllWorkspaces(),
        projects: OnlyProjects(chosen),
      );

      expect(describeScopeChips(scope, catalog), <String>[
        for (final ProjectId projectId in chosen)
          catalog.nameOfProject(projectId),
      ]);
    }
  });

  test('test_name_projects_property_projects_follow_workspaces', () {
    final Random random = seededRandom(94205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<WorkspaceId> workspaceIds = _someWorkspaceIds(
        random,
        catalog,
      );
      final List<Project> projects = catalog.listProjectsIn(workspaceIds);
      if (projects.isEmpty) {
        continue;
      }
      final Scope scope = Scope(
        workspaces: OnlyWorkspaces(workspaceIds),
        projects: OnlyProjects(<ProjectId>[
          for (final Project project in projects) project.id,
        ]),
      );

      expect(describeScopeChips(scope, catalog), <String>[
        for (final WorkspaceId workspaceId in workspaceIds)
          catalog.nameOfWorkspace(workspaceId),
        for (final Project project in projects) project.name,
      ]);
    }
  });

  test('test_name_projects_property_unknown_project_reads_nowhere', () {
    final Random random = seededRandom(94206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = Scope(
        workspaces: const AllWorkspaces(),
        projects: OnlyProjects(<ProjectId>[randomUnknownProjectId(random)]),
      );

      expect(describeScopeLine(scope, catalog), _nowhereLabel);
    }
  });

  test('test_describe_scope_chips_property_everywhere_only_if_it_applies', () {
    final Random random = seededRandom(94207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = randomScopeInCatalog(random, catalog);

      final List<String> chips = describeScopeChips(scope, catalog);

      expect(
        chips.contains(_everywhereLabel),
        doesScopeApplyToUnlistedPlaces(random, scope),
        reason: chips.join('|'),
      );
    }
  });

  test('test_describe_scope_chips_property_empty_scope_names_no_place', () {
    final Random random = seededRandom(94208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = randomScopeInCatalog(random, catalog);
      if (!doesScopeListNoPlace(scope)) {
        continue;
      }

      final List<String> chips = describeScopeChips(scope, catalog);

      expect(chips, hasLength(1));
      expect(chips.single, isNot(_everywhereLabel));
      expect(chips.single.trim(), isNotEmpty);
      for (final String name in listCatalogNames(catalog)) {
        expect(chips.single, isNot(contains(name)));
      }
    }
  });

  test('test_describe_scope_chips_property_never_empty_and_stable', () {
    final Random random = seededRandom(94209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = randomScopeInCatalog(random, catalog);

      final List<String> chips = describeScopeChips(scope, catalog);

      expect(chips, isNotEmpty);
      expect(describeScopeChips(scope, catalog), chips);
      for (final String chip in chips) {
        for (final String identifier in listCatalogIdentifiers(catalog)) {
          expect(chip, isNot(contains(identifier)));
        }
      }
    }
  });
}
