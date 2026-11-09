import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';

import '../../../support/random_scope_catalogs.dart';
import '../../../support/sample_scopes.dart';

List<ProjectId> listAllowedProjectIds(
  ScopeCatalog catalog,
  List<WorkspaceId> workspaceIds,
) {
  return <ProjectId>[
    for (final Project project in catalog.listProjectsIn(workspaceIds))
      project.id,
  ];
}

ScopeSelection randomSelectionIn(Random random, ScopeCatalog catalog) {
  final List<WorkspaceId> workspaceIds = pickSome(
    random,
    listCatalogWorkspaceIds(catalog),
  );
  final List<ProjectId> projectIds = pickSome(
    random,
    listAllowedProjectIds(catalog, workspaceIds),
  );
  return ScopeSelection(workspaceIds: workspaceIds, projectIds: projectIds);
}

bool areProjectsWithinWorkspaces(
  ScopeSelection selection,
  ScopeCatalog catalog,
) {
  final List<ProjectId> allowed = listAllowedProjectIds(
    catalog,
    selection.workspaceIds,
  );
  for (final ProjectId projectId in selection.projectIds) {
    if (!allowed.contains(projectId)) {
      return false;
    }
  }
  return true;
}

bool isInOrderWithin<Item>(List<Item> kept, List<Item> original) {
  int position = 0;
  for (final Item item in kept) {
    position = original.indexOf(item, position);
    if (position < 0) {
      return false;
    }
    position += 1;
  }
  return true;
}
