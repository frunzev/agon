import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';

import '../../support/random_inputs.dart';
import '../../support/random_nowhere_scopes.dart';
import '../../support/sample_records.dart';
import '../../support/sample_scopes.dart';
import '../new_items/draft_record_fields.dart';

List<WorkspaceId> _listWorkspaceIds(WorkspaceScope workspaces) {
  switch (workspaces) {
    case AllWorkspaces():
      return const <WorkspaceId>[];
    case OnlyWorkspaces():
      return workspaces.workspaces;
  }
}

List<ProjectId> _listProjectIds(ProjectScope projects) {
  switch (projects) {
    case AllProjects():
      return const <ProjectId>[];
    case OnlyProjects():
      return projects.projects;
  }
}

List<Object?> _describeShownTags(ScopeSelection selection) {
  final ScopeSelection shownTags = ScopeSelection(
    workspaceIds: selection.workspaceIds,
    projectIds: selection.projectIds,
  );
  return describeScopeFields(shownTags.toScope());
}

bool _appliesToAnyGalleryPlace(Scope scope) {
  for (final WorkspaceId workspaceId in sampleWorkspaceIds) {
    for (final ProjectId projectId in sampleProjectIds) {
      final bool applies = doesScopeApply(
        scope: scope,
        workspaceId: workspaceId,
        projectId: projectId,
      );
      if (applies) {
        return true;
      }
    }
  }
  return false;
}

void main() {
  test('test_from_scope_property_keeps_a_scope_that_lists_no_place', () {
    final Random random = seededRandom(51301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = randomScopeListingNoPlace(random);

      final Scope saved = ScopeSelection.fromScope(scope).toScope();

      expect(listsNoPlace(saved), isTrue);
      expect(describeScopeFields(saved), describeScopeFields(scope));
    }
  });

  test('test_from_scope_property_round_trips_every_scope', () {
    final Random random = seededRandom(51302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = randomScopeOrNowhere(random);

      final Scope saved = ScopeSelection.fromScope(scope).toScope();

      expect(describeScopeFields(saved), describeScopeFields(scope));
    }
  });

  test('test_from_scope_property_listed_ids_become_the_tags', () {
    final Random random = seededRandom(51303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = randomScopeOrNowhere(random);

      final ScopeSelection selection = ScopeSelection.fromScope(scope);

      expect(selection.workspaceIds, _listWorkspaceIds(scope.workspaces));
      expect(selection.projectIds, _listProjectIds(scope.projects));
    }
  });

  test('test_to_scope_property_never_widens_a_scope_that_lists_no_place', () {
    final Random random = seededRandom(51304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = randomScopeListingNoPlace(random);

      final Scope saved = ScopeSelection.fromScope(scope).toScope();

      expect(_appliesToAnyGalleryPlace(saved), isFalse);
    }
  });

  test('test_to_scope_property_is_idempotent_through_from_scope', () {
    final Random random = seededRandom(51305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope firstSave = ScopeSelection.fromScope(
        randomScopeOrNowhere(random),
      ).toScope();

      final Scope secondSave = ScopeSelection.fromScope(firstSave).toScope();

      expect(describeScopeFields(secondSave), describeScopeFields(firstSave));
    }
  });

  test('test_to_scope_property_chosen_tags_always_name_some_place', () {
    final Random random = seededRandom(51306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeSelection chosen = ScopeSelection(
        workspaceIds: pickSome(random, sampleWorkspaceIds),
        projectIds: pickSome(random, sampleProjectIds),
      );

      final Scope saved = chosen.toScope();

      expect(listsNoPlace(saved), isFalse);
    }
  });

  test(
    'test_without_workspace_property_unlisted_workspace_changes_nothing',
    () {
      final Random random = seededRandom(51307);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Scope scope = randomScopeOrNowhere(random);
        final ScopeSelection before = ScopeSelection.fromScope(scope);
        final WorkspaceId unlisted = WorkspaceId(randomText(random));
        if (before.workspaceIds.contains(unlisted)) {
          continue;
        }

        final ScopeSelection after = before.withoutWorkspace(
          unlisted,
          galleryCatalog,
        );

        expect(
          describeScopeFields(after.toScope()),
          describeScopeFields(scope),
        );
      }
    },
  );

  test('test_without_workspace_property_saves_what_the_tags_show', () {
    final Random random = seededRandom(51308);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeSelection before = ScopeSelection.fromScope(
        randomScopeOrNowhere(random),
      );
      if (before.workspaceIds.isEmpty) {
        continue;
      }
      final WorkspaceId removed = pickOne(random, before.workspaceIds);

      final ScopeSelection after = before.withoutWorkspace(
        removed,
        galleryCatalog,
      );

      expect(after.workspaceIds, isNot(contains(removed)));
      expect(describeScopeFields(after.toScope()), _describeShownTags(after));
    }
  });

  test(
    'test_without_workspace_property_keeps_projects_of_kept_workspaces',
    () {
      final Random random = seededRandom(51309);

      for (int i = 0; i < propertyIterations; i += 1) {
        final ScopeSelection before = ScopeSelection.fromScope(
          randomScopeOrNowhere(random),
        );
        if (before.workspaceIds.isEmpty) {
          continue;
        }
        final WorkspaceId removed = pickOne(random, before.workspaceIds);

        final ScopeSelection after = before.withoutWorkspace(
          removed,
          galleryCatalog,
        );
        final List<Project> allowedProjects = galleryCatalog.listProjectsIn(
          after.workspaceIds,
        );
        final Set<ProjectId> allowed = <ProjectId>{
          for (final Project project in allowedProjects) project.id,
        };

        for (final ProjectId projectId in after.projectIds) {
          expect(allowed, contains(projectId));
          expect(before.projectIds, contains(projectId));
        }
      }
    },
  );

  test('test_without_project_property_unlisted_project_changes_nothing', () {
    final Random random = seededRandom(51310);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = randomScopeOrNowhere(random);
      final ScopeSelection before = ScopeSelection.fromScope(scope);
      final ProjectId unlisted = ProjectId(randomText(random));
      if (before.projectIds.contains(unlisted)) {
        continue;
      }

      final ScopeSelection after = before.withoutProject(unlisted);

      expect(describeScopeFields(after.toScope()), describeScopeFields(scope));
    }
  });

  test('test_without_project_property_saves_what_the_tags_show', () {
    final Random random = seededRandom(51311);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeSelection before = ScopeSelection.fromScope(
        randomScopeOrNowhere(random),
      );
      if (before.projectIds.isEmpty) {
        continue;
      }
      final ProjectId removed = pickOne(random, before.projectIds);

      final ScopeSelection after = before.withoutProject(removed);

      expect(after.projectIds, isNot(contains(removed)));
      expect(describeScopeFields(after.toScope()), _describeShownTags(after));
    }
  });

  test('test_without_project_property_leaves_the_workspaces_alone', () {
    final Random random = seededRandom(51312);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeSelection before = ScopeSelection.fromScope(
        randomScopeOrNowhere(random),
      );
      final ProjectId removed = pickOne(random, sampleProjectIds);

      final ScopeSelection after = before.withoutProject(removed);

      expect(after.workspaceIds, before.workspaceIds);
    }
  });

  test(
    'test_with_workspace_property_a_new_workspace_saves_the_tags_shown',
    () {
      final Random random = seededRandom(51313);

      for (int i = 0; i < propertyIterations; i += 1) {
        final ScopeSelection before = ScopeSelection.fromScope(
          randomScopeListingNoPlace(random),
        );
        final WorkspaceId added = pickOne(random, sampleWorkspaceIds);

        final ScopeSelection after = before.withWorkspace(
          added,
          galleryCatalog,
        );

        if (before.workspaceIds.contains(added)) {
          expect(
            describeScopeFields(after.toScope()),
            describeScopeFields(before.toScope()),
          );
        } else {
          expect(
            describeScopeFields(after.toScope()),
            _describeShownTags(after),
          );
        }
      }
    },
  );
}
