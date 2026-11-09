import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';

import '../../support/random_inputs.dart';
import '../../support/random_nowhere_scopes.dart';
import '../../support/sample_records.dart';
import '../../support/sample_scopes.dart';
import '../new_items/draft_record_fields.dart';

Scope _withWorkspaces(Random random, WorkspaceScope workspaces) {
  return Scope(
    workspaces: workspaces,
    projects: randomScopeOrNowhere(random).projects,
  );
}

Scope _withProjects(Random random, ProjectScope projects) {
  return Scope(
    workspaces: randomScopeOrNowhere(random).workspaces,
    projects: projects,
  );
}

void main() {
  test('test_list_workspace_ids_property_all_workspaces_shows_no_tag', () {
    final Random random = seededRandom(51601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = _withWorkspaces(random, const AllWorkspaces());

      final ScopeSelection selection = ScopeSelection.fromScope(scope);

      expect(selection.workspaceIds, isEmpty);
    }
  });

  test('test_list_workspace_ids_property_listed_ids_keep_their_order', () {
    final Random random = seededRandom(51602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkspaceId> listed = pickSome(random, sampleWorkspaceIds);
      listed.shuffle(random);
      final Scope scope = _withWorkspaces(random, OnlyWorkspaces(listed));

      final ScopeSelection selection = ScopeSelection.fromScope(scope);

      expect(selection.workspaceIds, listed);
    }
  });

  test('test_list_workspace_ids_property_tags_cannot_be_changed', () {
    final Random random = seededRandom(51603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeSelection selection = ScopeSelection.fromScope(
        randomScopeOrNowhere(random),
      );

      expect(
        () => selection.workspaceIds.add(pickOne(random, sampleWorkspaceIds)),
        throwsUnsupportedError,
      );
    }
  });

  test('test_list_project_ids_property_all_projects_shows_no_tag', () {
    final Random random = seededRandom(51604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = _withProjects(random, const AllProjects());

      final ScopeSelection selection = ScopeSelection.fromScope(scope);

      expect(selection.projectIds, isEmpty);
    }
  });

  test('test_list_project_ids_property_listed_ids_keep_their_order', () {
    final Random random = seededRandom(51605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<ProjectId> listed = pickSome(random, sampleProjectIds);
      listed.shuffle(random);
      final Scope scope = _withProjects(random, OnlyProjects(listed));

      final ScopeSelection selection = ScopeSelection.fromScope(scope);

      expect(selection.projectIds, listed);
    }
  });

  test('test_list_project_ids_property_tags_cannot_be_changed', () {
    final Random random = seededRandom(51606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeSelection selection = ScopeSelection.fromScope(
        randomScopeOrNowhere(random),
      );

      expect(
        () => selection.projectIds.add(pickOne(random, sampleProjectIds)),
        throwsUnsupportedError,
      );
    }
  });

  test('test_keeping_no_place_property_saves_the_very_same_scope', () {
    final Random random = seededRandom(51607);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = randomScopeListingNoPlace(random);

      final Scope saved = ScopeSelection.fromScope(scope).toScope();

      expect(identical(saved, scope), isTrue);
    }
  });

  test('test_keeping_no_place_property_adding_a_present_tag_keeps_it', () {
    final Random random = seededRandom(51608);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = randomScopeListingNoPlace(random);
      final ScopeSelection kept = ScopeSelection.fromScope(scope);
      if (kept.workspaceIds.isEmpty) {
        continue;
      }
      final WorkspaceId present = pickOne(random, kept.workspaceIds);

      final ScopeSelection again = kept.withWorkspace(present, galleryCatalog);

      expect(describeScopeFields(again.toScope()), describeScopeFields(scope));
    }
  });

  test('test_keeping_no_place_property_a_real_change_saves_the_tags', () {
    final Random random = seededRandom(51609);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeSelection kept = ScopeSelection.fromScope(
        randomScopeListingNoPlace(random),
      );
      final WorkspaceId added = pickOne(random, sampleWorkspaceIds);
      if (kept.workspaceIds.contains(added)) {
        continue;
      }

      final ScopeSelection changed = kept.withWorkspace(added, galleryCatalog);

      final ScopeSelection shownTags = ScopeSelection(
        workspaceIds: changed.workspaceIds,
        projectIds: changed.projectIds,
      );
      expect(
        describeScopeFields(changed.toScope()),
        describeScopeFields(shownTags.toScope()),
      );
    }
  });
}
