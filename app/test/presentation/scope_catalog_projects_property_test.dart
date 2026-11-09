import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';

import '../support/random_inputs.dart';
import '../support/random_scope_catalogs.dart';
import '../support/sample_scopes.dart';

List<WorkspaceId> _randomNonEmptyWorkspaceIds(
  Random random,
  ScopeCatalog catalog,
) {
  final List<WorkspaceId> allIds = listCatalogWorkspaceIds(catalog);
  final List<WorkspaceId> picked = pickSome(random, allIds);
  if (picked.isEmpty) {
    return <WorkspaceId>[pickOne(random, allIds)];
  }
  return picked;
}

void main() {
  test('test_list_projects_in_property_no_filter_lists_every_project', () {
    final Random random = seededRandom(94121);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);

      expect(
        catalog.listProjectsIn(const <WorkspaceId>[]),
        orderedEquals(catalog.projects),
      );
    }
  });

  test('test_list_projects_in_property_keeps_catalog_order_of_matches', () {
    final Random random = seededRandom(94122);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<WorkspaceId> chosen = _randomNonEmptyWorkspaceIds(
        random,
        catalog,
      );
      final List<Project> expected = <Project>[];
      for (final Project project in catalog.projects) {
        if (chosen.contains(project.workspaceId)) {
          expected.add(project);
        }
      }

      expect(catalog.listProjectsIn(chosen), orderedEquals(expected));
    }
  });

  test('test_list_projects_in_property_union_and_repeats_add_nothing', () {
    final Random random = seededRandom(94123);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<WorkspaceId> first = _randomNonEmptyWorkspaceIds(
        random,
        catalog,
      );
      final List<WorkspaceId> second = _randomNonEmptyWorkspaceIds(
        random,
        catalog,
      );
      final List<WorkspaceId> both = <WorkspaceId>[...first, ...second];
      final List<WorkspaceId> reversed = both.reversed.toList();

      final List<Project> listedForBoth = catalog.listProjectsIn(both);

      expect(listedForBoth.toSet(), <Project>{
        ...catalog.listProjectsIn(first),
        ...catalog.listProjectsIn(second),
      });
      expect(listedForBoth.length, listedForBoth.toSet().length);
      expect(catalog.listProjectsIn(reversed), orderedEquals(listedForBoth));
    }
  });

  test('test_list_projects_in_property_unknown_workspaces_list_nothing', () {
    final Random random = seededRandom(94124);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<WorkspaceId> unknownIds = <WorkspaceId>[
        randomUnknownWorkspaceId(random),
      ];

      expect(catalog.listProjectsIn(unknownIds), isEmpty);
    }
  });
}
