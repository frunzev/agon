import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';

import 'random_scope_catalogs.dart';
import 'sample_scopes.dart';

const int _mostUnknownPlaces = 3;

List<Place> _mixInUnknown<Place>(
  Random random, {
  required List<Place> known,
  required Place Function(Random random) buildUnknown,
}) {
  final List<Place> mixed = <Place>[...known];
  final int unknownCount = 1 + random.nextInt(_mostUnknownPlaces);
  for (int i = 0; i < unknownCount; i += 1) {
    mixed.insert(random.nextInt(mixed.length + 1), buildUnknown(random));
  }
  return mixed;
}

List<WorkspaceId> mixInUnknownWorkspaces(
  Random random,
  List<WorkspaceId> known,
) {
  return _mixInUnknown(
    random,
    known: known,
    buildUnknown: randomUnknownWorkspaceId,
  );
}

List<ProjectId> mixInUnknownProjects(Random random, List<ProjectId> known) {
  return _mixInUnknown(
    random,
    known: known,
    buildUnknown: randomUnknownProjectId,
  );
}

WorkspaceScope _randomWorkspacesWithUnknown(
  Random random,
  ScopeCatalog catalog,
) {
  if (random.nextBool()) {
    return const AllWorkspaces();
  }
  final List<WorkspaceId> known = pickSome(
    random,
    listCatalogWorkspaceIds(catalog),
  );
  return OnlyWorkspaces(mixInUnknownWorkspaces(random, known));
}

ProjectScope _randomProjectsWithUnknown(Random random, ScopeCatalog catalog) {
  if (random.nextBool()) {
    return const AllProjects();
  }
  final List<ProjectId> known = pickSome(
    random,
    listCatalogProjectIds(catalog),
  );
  return OnlyProjects(mixInUnknownProjects(random, known));
}

Scope randomScopeWithUnknownPlaces(Random random, ScopeCatalog catalog) {
  final Scope scope = Scope(
    workspaces: _randomWorkspacesWithUnknown(random, catalog),
    projects: _randomProjectsWithUnknown(random, catalog),
  );
  final bool listsSomething =
      scope.workspaces is OnlyWorkspaces || scope.projects is OnlyProjects;
  if (listsSomething) {
    return scope;
  }
  return Scope(
    workspaces: scope.workspaces,
    projects: OnlyProjects(mixInUnknownProjects(random, const <ProjectId>[])),
  );
}

Scope pruneUnknownPlacesByHand(Scope scope, ScopeCatalog catalog) {
  final Set<WorkspaceId> knownWorkspaceIds = <WorkspaceId>{
    for (final Workspace workspace in catalog.workspaces) workspace.id,
  };
  final Set<ProjectId> knownProjectIds = <ProjectId>{
    for (final Project project in catalog.projects) project.id,
  };
  final WorkspaceScope workspaces = scope.workspaces;
  final ProjectScope projects = scope.projects;
  final WorkspaceScope keptWorkspaces = workspaces is OnlyWorkspaces
      ? OnlyWorkspaces(<WorkspaceId>[
          for (final WorkspaceId workspaceId in workspaces.workspaces)
            if (knownWorkspaceIds.contains(workspaceId)) workspaceId,
        ])
      : workspaces;
  final ProjectScope keptProjects = projects is OnlyProjects
      ? OnlyProjects(<ProjectId>[
          for (final ProjectId projectId in projects.projects)
            if (knownProjectIds.contains(projectId)) projectId,
        ])
      : projects;
  return Scope(workspaces: keptWorkspaces, projects: keptProjects);
}
