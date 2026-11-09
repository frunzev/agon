import 'dart:math';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';

import '../bridge/support/hostile_texts.dart';
import '../bridge/support/node_json_primitives.dart';
import 'sample_scopes.dart';

const int _mostWorkspaces = 4;
const int _mostProjectsPerWorkspace = 3;
const String _sampleServerAddress = 'peer://sample-server';

Workspace buildNamedWorkspace(WorkspaceId workspaceId, String name) {
  return Workspace(
    id: workspaceId,
    name: name,
    appServerAddress: _sampleServerAddress,
    protectedFiles: const <String>[],
    approvalPolicy: ApprovalPolicy.neverAsk,
  );
}

Project buildNamedProject({
  required ProjectId projectId,
  required WorkspaceId workspaceId,
  required String name,
}) {
  return Project(
    id: projectId,
    workspaceId: workspaceId,
    name: name,
    repositories: const <Repository>[],
    approvalPolicy: null,
  );
}

String randomUniqueHostileName(Random random, int index) {
  return '${randomHostileText(random)} $index';
}

WorkspaceId randomUnknownWorkspaceId(Random random) {
  return WorkspaceId('unknown-${randomUuidText(random)}');
}

ProjectId randomUnknownProjectId(Random random) {
  return ProjectId('unknown-${randomUuidText(random)}');
}

ScopeCatalog randomScopeCatalog(Random random) {
  final List<Workspace> workspaces = <Workspace>[];
  final List<Project> projects = <Project>[];
  final int workspaceCount = 1 + random.nextInt(_mostWorkspaces);
  int nameIndex = 0;

  for (int i = 0; i < workspaceCount; i += 1) {
    final WorkspaceId workspaceId = WorkspaceId(randomUuidText(random));
    workspaces.add(
      buildNamedWorkspace(
        workspaceId,
        randomUniqueHostileName(random, nameIndex),
      ),
    );
    nameIndex += 1;

    final int projectCount = random.nextInt(_mostProjectsPerWorkspace + 1);
    for (int j = 0; j < projectCount; j += 1) {
      projects.add(
        buildNamedProject(
          projectId: ProjectId(randomUuidText(random)),
          workspaceId: workspaceId,
          name: randomUniqueHostileName(random, nameIndex),
        ),
      );
      nameIndex += 1;
    }
  }

  return ScopeCatalog(workspaces: workspaces, projects: projects);
}

List<WorkspaceId> listCatalogWorkspaceIds(ScopeCatalog catalog) {
  return <WorkspaceId>[
    for (final Workspace workspace in catalog.workspaces) workspace.id,
  ];
}

List<ProjectId> listCatalogProjectIds(ScopeCatalog catalog) {
  return <ProjectId>[
    for (final Project project in catalog.projects) project.id,
  ];
}

Scope randomScopeInCatalog(Random random, ScopeCatalog catalog) {
  final WorkspaceScope workspaces = random.nextBool()
      ? const AllWorkspaces()
      : OnlyWorkspaces(pickSome(random, listCatalogWorkspaceIds(catalog)));
  final ProjectScope projects = random.nextBool()
      ? const AllProjects()
      : OnlyProjects(pickSome(random, listCatalogProjectIds(catalog)));

  return Scope(workspaces: workspaces, projects: projects);
}

List<String> listCatalogNames(ScopeCatalog catalog) {
  return <String>[
    for (final Workspace workspace in catalog.workspaces) workspace.name,
    for (final Project project in catalog.projects) project.name,
  ];
}

List<String> listCatalogIdentifiers(ScopeCatalog catalog) {
  return <String>[
    for (final WorkspaceId workspaceId in listCatalogWorkspaceIds(catalog))
      workspaceId.value,
    for (final ProjectId projectId in listCatalogProjectIds(catalog))
      projectId.value,
  ];
}

bool doesScopeApplyToUnlistedPlaces(Random random, Scope scope) {
  return doesScopeApply(
    scope: scope,
    workspaceId: randomUnknownWorkspaceId(random),
    projectId: randomUnknownProjectId(random),
  );
}

bool doesScopeListNoPlace(Scope scope) {
  final WorkspaceScope workspaces = scope.workspaces;
  final ProjectScope projects = scope.projects;
  final bool hasNoWorkspace =
      workspaces is OnlyWorkspaces && workspaces.workspaces.isEmpty;
  final bool hasNoProject =
      projects is OnlyProjects && projects.projects.isEmpty;

  return hasNoWorkspace || hasNoProject;
}
