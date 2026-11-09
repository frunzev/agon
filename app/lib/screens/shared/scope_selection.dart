import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';

List<WorkspaceId> _listWorkspaceIds(WorkspaceScope workspaces) {
  return switch (workspaces) {
    AllWorkspaces() => const <WorkspaceId>[],
    OnlyWorkspaces(:final List<WorkspaceId> workspaces) => workspaces,
  };
}

List<ProjectId> _listProjectIds(ProjectScope projects) {
  return switch (projects) {
    AllProjects() => const <ProjectId>[],
    OnlyProjects(:final List<ProjectId> projects) => projects,
  };
}

final class ScopeSelection {
  ScopeSelection({
    required List<WorkspaceId> workspaceIds,
    required List<ProjectId> projectIds,
  }) : workspaceIds = List<WorkspaceId>.unmodifiable(workspaceIds),
       projectIds = List<ProjectId>.unmodifiable(projectIds),
       _keptScopeListingNoPlace = null;

  ScopeSelection._keepingNoPlace(Scope scope)
    : workspaceIds = _listWorkspaceIds(scope.workspaces),
      projectIds = _listProjectIds(scope.projects),
      _keptScopeListingNoPlace = scope;

  factory ScopeSelection.everywhere() {
    return ScopeSelection(
      workspaceIds: const <WorkspaceId>[],
      projectIds: const <ProjectId>[],
    );
  }

  factory ScopeSelection.fromScope(Scope scope) {
    if (listsNoPlace(scope)) {
      return ScopeSelection._keepingNoPlace(scope);
    }

    return ScopeSelection(
      workspaceIds: _listWorkspaceIds(scope.workspaces),
      projectIds: _listProjectIds(scope.projects),
    );
  }

  final List<WorkspaceId> workspaceIds;
  final List<ProjectId> projectIds;
  final Scope? _keptScopeListingNoPlace;

  Scope toScope() {
    final Scope? keptScope = _keptScopeListingNoPlace;
    if (keptScope != null) {
      return keptScope;
    }

    final WorkspaceScope workspaces = workspaceIds.isEmpty
        ? const AllWorkspaces()
        : OnlyWorkspaces(workspaceIds);
    final ProjectScope projects = projectIds.isEmpty
        ? const AllProjects()
        : OnlyProjects(projectIds);

    return Scope(workspaces: workspaces, projects: projects);
  }

  ScopeSelection withWorkspace(WorkspaceId workspaceId, ScopeCatalog catalog) {
    if (workspaceIds.contains(workspaceId)) {
      return this;
    }

    return _keepProjectsWithin(<WorkspaceId>[
      ...workspaceIds,
      workspaceId,
    ], catalog);
  }

  ScopeSelection withoutWorkspace(
    WorkspaceId workspaceId,
    ScopeCatalog catalog,
  ) {
    if (!workspaceIds.contains(workspaceId)) {
      return this;
    }

    final List<WorkspaceId> remaining = <WorkspaceId>[
      for (final WorkspaceId candidate in workspaceIds)
        if (candidate != workspaceId) candidate,
    ];

    return _keepProjectsWithin(remaining, catalog);
  }

  ScopeSelection withProject(ProjectId projectId, ScopeCatalog catalog) {
    final bool isWithinWorkspaces = catalog
        .listProjectsIn(workspaceIds)
        .any((Project project) => project.id == projectId);
    if (!isWithinWorkspaces) {
      throw ArgumentError.value(
        projectId,
        'projectId',
        'Only projects of the chosen workspaces can be added',
      );
    }
    if (projectIds.contains(projectId)) {
      return this;
    }

    return ScopeSelection(
      workspaceIds: workspaceIds,
      projectIds: <ProjectId>[...projectIds, projectId],
    );
  }

  ScopeSelection withoutProject(ProjectId projectId) {
    if (!projectIds.contains(projectId)) {
      return this;
    }

    final List<ProjectId> remaining = <ProjectId>[
      for (final ProjectId candidate in projectIds)
        if (candidate != projectId) candidate,
    ];

    return ScopeSelection(workspaceIds: workspaceIds, projectIds: remaining);
  }

  ScopeSelection _keepProjectsWithin(
    List<WorkspaceId> nextWorkspaceIds,
    ScopeCatalog catalog,
  ) {
    final Set<ProjectId> allowedProjectIds = <ProjectId>{
      for (final Project project in catalog.listProjectsIn(nextWorkspaceIds))
        project.id,
    };
    final List<ProjectId> keptProjectIds = <ProjectId>[
      for (final ProjectId projectId in projectIds)
        if (allowedProjectIds.contains(projectId)) projectId,
    ];

    return ScopeSelection(
      workspaceIds: nextWorkspaceIds,
      projectIds: keptProjectIds,
    );
  }
}
