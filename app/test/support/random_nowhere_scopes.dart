import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';

import 'sample_scopes.dart';

Scope randomScopeListingNoPlace(Random random) {
  final Scope listedScope = randomScope(random);

  if (random.nextBool()) {
    return Scope(
      workspaces: OnlyWorkspaces(const <WorkspaceId>[]),
      projects: listedScope.projects,
    );
  }
  return Scope(
    workspaces: listedScope.workspaces,
    projects: OnlyProjects(const <ProjectId>[]),
  );
}

Scope randomScopeOrNowhere(Random random) {
  if (random.nextBool()) {
    return randomScopeListingNoPlace(random);
  }
  return randomScope(random);
}
