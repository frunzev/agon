import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/projects.dart';

import '../../support/random_inputs.dart';
import '../../support/random_scope_catalogs.dart';
import '../../support/random_unknown_scope_places.dart';
import '../../support/sample_scopes.dart';

const String _nowhereLabel = 'Nowhere';

Project _pickProjectOrStranger(Random random, ScopeCatalog catalog) {
  if (catalog.projects.isEmpty) {
    return buildNamedProject(
      projectId: randomUnknownProjectId(random),
      workspaceId: catalog.workspaces.first.id,
      name: 'stranger',
    );
  }
  return pickOne(random, catalog.projects);
}

String _describeAllProjectsReach({
  required List<WorkspaceId> workspaceIds,
  required Project project,
  required ScopeCatalog catalog,
}) {
  final Scope scope = Scope(
    workspaces: OnlyWorkspaces(workspaceIds),
    projects: const AllProjects(),
  );
  return describeRuleReach(scope: scope, project: project, catalog: catalog);
}

void main() {
  test('test_describe_rule_reach_property_unknown_workspaces_never_'
      'crash_or_leak_their_ids', () {
    final Random random = seededRandom(1140301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<WorkspaceId> known = pickSome(
        random,
        listCatalogWorkspaceIds(catalog),
      );
      final List<WorkspaceId> mixed = mixInUnknownWorkspaces(random, known);

      final String reach = _describeAllProjectsReach(
        workspaceIds: mixed,
        project: _pickProjectOrStranger(random, catalog),
        catalog: catalog,
      );

      for (final WorkspaceId workspaceId in mixed) {
        if (!known.contains(workspaceId)) {
          expect(reach.contains(workspaceId.value), isFalse);
        }
      }
    }
  });

  test('test_describe_rule_reach_property_unknown_workspaces_change_'
      'nothing', () {
    final Random random = seededRandom(1140302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Project project = _pickProjectOrStranger(random, catalog);
      final List<WorkspaceId> known = <WorkspaceId>[
        pickOne(random, listCatalogWorkspaceIds(catalog)),
        ...pickSome(random, listCatalogWorkspaceIds(catalog)),
      ];

      final String withUnknown = _describeAllProjectsReach(
        workspaceIds: mixInUnknownWorkspaces(random, known),
        project: project,
        catalog: catalog,
      );
      final String knownOnly = _describeAllProjectsReach(
        workspaceIds: known,
        project: project,
        catalog: catalog,
      );

      expect(withUnknown, knownOnly);
      expect(withUnknown, startsWith('All '));
    }
  });

  test('test_describe_rule_reach_property_only_unknown_workspaces_read_'
      'nowhere', () {
    final Random random = seededRandom(1140303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<WorkspaceId> unknown = mixInUnknownWorkspaces(
        random,
        const <WorkspaceId>[],
      );

      final String reach = _describeAllProjectsReach(
        workspaceIds: unknown,
        project: _pickProjectOrStranger(random, catalog),
        catalog: catalog,
      );

      expect(reach, _nowhereLabel);
    }
  });
}
