import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/presentation/scope_text.dart';

import '../support/random_inputs.dart';
import '../support/random_scope_catalogs.dart';

const String _everywhereLabel = 'Everywhere';
const String _allProjectsEnding = ' · all projects';

String _expectedLineForListedPlaces(Scope scope, ScopeCatalog catalog) {
  final WorkspaceScope workspaces = scope.workspaces;
  final ProjectScope projects = scope.projects;
  final List<String> workspaceNames = <String>[
    if (workspaces is OnlyWorkspaces)
      for (final WorkspaceId workspaceId in workspaces.workspaces)
        catalog.nameOfWorkspace(workspaceId),
  ];
  final List<String> projectNames = <String>[
    if (projects is OnlyProjects)
      for (final ProjectId projectId in projects.projects)
        catalog.nameOfProject(projectId),
  ];
  final String projectPart = projectNames.isEmpty
      ? 'all projects'
      : projectNames.join(', ');

  if (workspaceNames.isEmpty) {
    return projectPart;
  }
  return '${workspaceNames.join(', ')} · $projectPart';
}

void main() {
  test('test_describe_scope_line_property_everywhere_only_if_it_applies', () {
    final Random random = seededRandom(94211);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = randomScopeInCatalog(random, catalog);

      final String line = describeScopeLine(scope, catalog);

      expect(
        line == _everywhereLabel,
        doesScopeApplyToUnlistedPlaces(random, scope),
        reason: line,
      );
      expect(
        line == _everywhereLabel,
        describeScopeChips(scope, catalog).contains(_everywhereLabel),
      );
    }
  });

  test('test_describe_scope_line_property_empty_scope_names_no_place', () {
    final Random random = seededRandom(94212);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = randomScopeInCatalog(random, catalog);
      if (!doesScopeListNoPlace(scope)) {
        continue;
      }

      final String line = describeScopeLine(scope, catalog);

      expect(line, isNot(_everywhereLabel));
      expect(line, isNot(endsWith(_allProjectsEnding)));
      expect(line.trim(), isNotEmpty);
      expect(line, describeScopeChips(scope, catalog).single);
      for (final String name in listCatalogNames(catalog)) {
        expect(line, isNot(contains(name)));
      }
    }
  });

  test('test_describe_scope_line_property_workspaces_then_projects', () {
    final Random random = seededRandom(94213);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = randomScopeInCatalog(random, catalog);
      final bool isEverywhere =
          scope.workspaces is AllWorkspaces && scope.projects is AllProjects;
      if (isEverywhere || doesScopeListNoPlace(scope)) {
        continue;
      }

      expect(
        describeScopeLine(scope, catalog),
        _expectedLineForListedPlaces(scope, catalog),
      );
    }
  });

  test('test_describe_scope_line_property_stable_and_free_of_ids', () {
    final Random random = seededRandom(94214);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = randomScopeInCatalog(random, catalog);

      final String line = describeScopeLine(scope, catalog);

      expect(describeScopeLine(scope, catalog), line);
      expect(line.trim(), isNotEmpty);
      for (final String identifier in listCatalogIdentifiers(catalog)) {
        expect(line, isNot(contains(identifier)));
      }
    }
  });

  test('test_lists_no_place_property_no_workspace_hides_projects_half', () {
    final Random random = seededRandom(94215);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope first = Scope(
        workspaces: OnlyWorkspaces(const <WorkspaceId>[]),
        projects: randomScopeInCatalog(random, catalog).projects,
      );
      final Scope second = Scope(
        workspaces: OnlyWorkspaces(const <WorkspaceId>[]),
        projects: randomScopeInCatalog(random, catalog).projects,
      );

      expect(
        describeScopeLine(first, catalog),
        describeScopeLine(second, catalog),
      );
      expect(
        describeScopeChips(first, catalog),
        describeScopeChips(second, catalog),
      );
    }
  });

  test('test_lists_no_place_property_no_project_hides_workspaces_half', () {
    final Random random = seededRandom(94216);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope first = Scope(
        workspaces: randomScopeInCatalog(random, catalog).workspaces,
        projects: OnlyProjects(const <ProjectId>[]),
      );
      final Scope second = Scope(
        workspaces: randomScopeInCatalog(random, catalog).workspaces,
        projects: OnlyProjects(const <ProjectId>[]),
      );

      expect(
        describeScopeLine(first, catalog),
        describeScopeLine(second, catalog),
      );
      expect(describeScopeLine(first, catalog), isNot(_everywhereLabel));
    }
  });

  test('test_lists_no_place_property_listed_places_never_read_empty', () {
    final Random random = seededRandom(94217);
    final ScopeCatalog unrelatedCatalog = randomScopeCatalog(random);
    final String noPlaceLine = describeScopeLine(
      Scope(
        workspaces: const AllWorkspaces(),
        projects: OnlyProjects(const <ProjectId>[]),
      ),
      unrelatedCatalog,
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = randomScopeInCatalog(random, catalog);
      if (doesScopeListNoPlace(scope)) {
        continue;
      }

      expect(describeScopeLine(scope, catalog), isNot(noPlaceLine));
      expect(describeScopeChips(scope, catalog), isNot(contains(noPlaceLine)));
    }
  });
}
