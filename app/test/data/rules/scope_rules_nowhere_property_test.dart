import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/random_nowhere_scopes.dart';

const int _largestListedCount = 4;

List<WorkspaceId> _randomWorkspaceIds(Random random) {
  final int count = random.nextInt(_largestListedCount);
  return <WorkspaceId>[
    for (int i = 0; i < count; i += 1) WorkspaceId(randomHostileText(random)),
  ];
}

List<ProjectId> _randomProjectIds(Random random) {
  final int count = random.nextInt(_largestListedCount);
  return <ProjectId>[
    for (int i = 0; i < count; i += 1) ProjectId(randomHostileText(random)),
  ];
}

WorkspaceId _pickIncludedWorkspace(Random random, WorkspaceScope workspaces) {
  switch (workspaces) {
    case AllWorkspaces():
      return WorkspaceId(randomHostileText(random));
    case OnlyWorkspaces():
      return pickOne(random, workspaces.workspaces);
  }
}

ProjectId _pickIncludedProject(Random random, ProjectScope projects) {
  switch (projects) {
    case AllProjects():
      return ProjectId(randomHostileText(random));
    case OnlyProjects():
      return pickOne(random, projects.projects);
  }
}

void main() {
  test('test_lists_no_workspace_property_all_workspaces_lists_some', () {
    expect(listsNoWorkspace(const AllWorkspaces()), isFalse);
  });

  test('test_lists_no_workspace_property_only_an_empty_list_lists_none', () {
    final Random random = seededRandom(51201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkspaceId> listed = _randomWorkspaceIds(random);

      final bool listsNone = listsNoWorkspace(OnlyWorkspaces(listed));

      expect(listsNone, listed.isEmpty);
    }
  });

  test('test_lists_no_workspace_property_agrees_with_includes_workspace', () {
    final Random random = seededRandom(51202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceScope workspaces = randomScopeOrNowhere(
        random,
      ).workspaces;
      final WorkspaceId queried = WorkspaceId(randomHostileText(random));

      if (listsNoWorkspace(workspaces)) {
        expect(includesWorkspace(workspaces, queried), isFalse);
      } else {
        final WorkspaceId included = _pickIncludedWorkspace(
          random,
          workspaces,
        );
        expect(includesWorkspace(workspaces, included), isTrue);
      }
    }
  });

  test('test_lists_no_project_property_all_projects_lists_some', () {
    expect(listsNoProject(const AllProjects()), isFalse);
  });

  test('test_lists_no_project_property_only_an_empty_list_lists_none', () {
    final Random random = seededRandom(51203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<ProjectId> listed = _randomProjectIds(random);

      final bool listsNone = listsNoProject(OnlyProjects(listed));

      expect(listsNone, listed.isEmpty);
    }
  });

  test('test_lists_no_project_property_agrees_with_includes_project', () {
    final Random random = seededRandom(51204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ProjectScope projects = randomScopeOrNowhere(random).projects;
      final ProjectId queried = ProjectId(randomHostileText(random));

      if (listsNoProject(projects)) {
        expect(includesProject(projects, queried), isFalse);
      } else {
        final ProjectId included = _pickIncludedProject(random, projects);
        expect(includesProject(projects, included), isTrue);
      }
    }
  });

  test('test_lists_no_place_property_either_half_listing_none_is_enough', () {
    final Random random = seededRandom(51205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = randomScopeOrNowhere(random);
      final bool eitherHalfListsNone =
          listsNoWorkspace(scope.workspaces) || listsNoProject(scope.projects);

      expect(listsNoPlace(scope), eitherHalfListsNone);
    }
  });

  test('test_lists_no_place_property_such_a_scope_applies_to_nothing', () {
    final Random random = seededRandom(51206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = randomScopeListingNoPlace(random);
      final bool applies = doesScopeApply(
        scope: scope,
        workspaceId: WorkspaceId(randomHostileText(random)),
        projectId: ProjectId(randomHostileText(random)),
      );

      expect(listsNoPlace(scope), isTrue);
      expect(applies, isFalse);
    }
  });

  test('test_lists_no_place_property_other_scopes_apply_somewhere', () {
    final Random random = seededRandom(51207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = randomScopeOrNowhere(random);
      if (listsNoPlace(scope)) {
        continue;
      }

      final bool applies = doesScopeApply(
        scope: scope,
        workspaceId: _pickIncludedWorkspace(random, scope.workspaces),
        projectId: _pickIncludedProject(random, scope.projects),
      );

      expect(applies, isTrue);
    }
  });
}
