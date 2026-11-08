import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'support/schedule_scope_run_tables.dart';

const int _largestListedCount = 5;

List<String> _randomIdentifiers(Random random) {
  final int count = random.nextInt(_largestListedCount);
  return <String>[
    for (int i = 0; i < count; i += 1) randomHostileText(random),
  ];
}

List<String> _shuffleWithDuplicates(Random random, List<String> identifiers) {
  final List<String> reordered = <String>[...identifiers, ...identifiers];
  reordered.shuffle(random);
  return reordered;
}

String _pickQueried(Random random, List<String> identifiers) {
  if (identifiers.isEmpty || random.nextBool()) {
    return randomHostileText(random);
  }
  return pickOne(random, identifiers);
}

OnlyWorkspaces _onlyWorkspaces(List<String> identifiers) {
  return OnlyWorkspaces(<WorkspaceId>[
    for (final String identifier in identifiers) WorkspaceId(identifier),
  ]);
}

OnlyProjects _onlyProjects(List<String> identifiers) {
  return OnlyProjects(<ProjectId>[
    for (final String identifier in identifiers) ProjectId(identifier),
  ]);
}

void main() {
  test('test_includes_workspace_property_matches_the_shared_scope_table', () {
    for (final SharedScopeCase sharedCase in readSharedScopeCases()) {
      final bool includes = includesWorkspace(
        sharedCase.scope.workspaces,
        sharedCase.workspaceId,
      );

      expect(includes, sharedCase.includesWorkspace, reason: '$sharedCase');
    }
  });

  test('test_includes_workspace_property_order_and_repeats_do_not_'
      'matter', () {
    final Random random = seededRandom(88601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> listed = _randomIdentifiers(random);
      final WorkspaceId queried = WorkspaceId(_pickQueried(random, listed));

      final bool original = includesWorkspace(
        _onlyWorkspaces(listed),
        queried,
      );
      final bool reordered = includesWorkspace(
        _onlyWorkspaces(_shuffleWithDuplicates(random, listed)),
        queried,
      );

      expect(reordered, original);
      expect(original, listed.contains(queried.value));
    }
  });

  test('test_includes_project_property_matches_the_shared_scope_table', () {
    for (final SharedScopeCase sharedCase in readSharedScopeCases()) {
      final bool includes = includesProject(
        sharedCase.scope.projects,
        sharedCase.projectId,
      );

      expect(includes, sharedCase.includesProject, reason: '$sharedCase');
    }
  });

  test('test_includes_project_property_order_and_repeats_do_not_matter', () {
    final Random random = seededRandom(88602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> listed = _randomIdentifiers(random);
      final ProjectId queried = ProjectId(_pickQueried(random, listed));

      final bool original = includesProject(_onlyProjects(listed), queried);
      final bool reordered = includesProject(
        _onlyProjects(_shuffleWithDuplicates(random, listed)),
        queried,
      );

      expect(reordered, original);
      expect(original, listed.contains(queried.value));
    }
  });

  test('test_does_scope_apply_property_matches_the_shared_scope_table', () {
    for (final SharedScopeCase sharedCase in readSharedScopeCases()) {
      final bool applies = doesScopeApply(
        scope: sharedCase.scope,
        workspaceId: sharedCase.workspaceId,
        projectId: sharedCase.projectId,
      );

      expect(applies, sharedCase.applies, reason: '$sharedCase');
    }
  });

  test('test_does_scope_apply_property_everywhere_covers_every_place', () {
    final Random random = seededRandom(88603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool applies = doesScopeApply(
        scope: const Scope.everywhere(),
        workspaceId: WorkspaceId(randomHostileText(random)),
        projectId: ProjectId(randomHostileText(random)),
      );

      expect(applies, isTrue);
    }
  });

  test('test_does_scope_apply_property_listing_more_places_never_drops_'
      'one', () {
    final Random random = seededRandom(88604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> workspaces = _randomIdentifiers(random);
      final List<String> projects = _randomIdentifiers(random);
      final WorkspaceId workspaceId = WorkspaceId(
        _pickQueried(random, workspaces),
      );
      final ProjectId projectId = ProjectId(_pickQueried(random, projects));
      final Scope narrow = Scope(
        workspaces: _onlyWorkspaces(workspaces),
        projects: _onlyProjects(projects),
      );
      final Scope wider = Scope(
        workspaces: _onlyWorkspaces(<String>[
          ...workspaces,
          ..._randomIdentifiers(random),
        ]),
        projects: _onlyProjects(<String>[
          ...projects,
          ..._randomIdentifiers(random),
        ]),
      );

      final bool appliesNarrowly = doesScopeApply(
        scope: narrow,
        workspaceId: workspaceId,
        projectId: projectId,
      );
      final bool appliesWidely = doesScopeApply(
        scope: wider,
        workspaceId: workspaceId,
        projectId: projectId,
      );

      if (appliesNarrowly) {
        expect(appliesWidely, isTrue);
      }
    }
  });
}
