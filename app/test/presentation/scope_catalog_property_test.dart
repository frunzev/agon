import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';

import '../support/random_inputs.dart';
import '../support/random_scope_catalogs.dart';

ScopeCatalog _shuffleCatalog(Random random, ScopeCatalog catalog) {
  final List<Workspace> workspaces = List<Workspace>.of(catalog.workspaces);
  final List<Project> projects = List<Project>.of(catalog.projects);
  workspaces.shuffle(random);
  projects.shuffle(random);

  return ScopeCatalog(workspaces: workspaces, projects: projects);
}

Matcher _isRecordNotFound({required String kind, required String identifier}) {
  return isA<RecordNotFound>()
      .having((RecordNotFound error) => error.kind, 'kind', kind)
      .having(
        (RecordNotFound error) => error.identifier,
        'identifier',
        identifier,
      );
}

void main() {
  test('test_scope_catalog_constructor_property_keeps_every_record', () {
    final Random random = seededRandom(94101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog source = randomScopeCatalog(random);
      final List<Workspace> workspaces = List<Workspace>.of(source.workspaces);
      final List<Project> projects = List<Project>.of(source.projects);

      final ScopeCatalog catalog = ScopeCatalog(
        workspaces: workspaces,
        projects: projects,
      );

      expect(catalog.workspaces, orderedEquals(workspaces));
      expect(catalog.projects, orderedEquals(projects));
    }
  });

  test('test_scope_catalog_constructor_property_later_edits_never_leak', () {
    final Random random = seededRandom(94102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog source = randomScopeCatalog(random);
      final List<Workspace> workspaces = List<Workspace>.of(source.workspaces);
      final List<Project> projects = List<Project>.of(source.projects);
      final ScopeCatalog catalog = ScopeCatalog(
        workspaces: workspaces,
        projects: projects,
      );
      final int workspaceCount = workspaces.length;
      final int projectCount = projects.length;

      workspaces.add(workspaces.first);
      projects.clear();

      expect(catalog.workspaces.length, workspaceCount);
      expect(catalog.projects.length, projectCount);
    }
  });

  test('test_scope_catalog_constructor_property_lists_refuse_changes', () {
    final Random random = seededRandom(94103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Workspace workspace = catalog.workspaces.first;

      expect(() => catalog.workspaces.add(workspace), throwsUnsupportedError);
      expect(catalog.projects.clear, throwsUnsupportedError);
    }
  });

  test('test_name_of_workspace_property_names_every_listed_workspace', () {
    final Random random = seededRandom(94104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);

      for (final Workspace workspace in catalog.workspaces) {
        expect(catalog.nameOfWorkspace(workspace.id), workspace.name);
      }
    }
  });

  test('test_name_of_workspace_property_unknown_id_fails_with_its_id', () {
    final Random random = seededRandom(94105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final WorkspaceId unknownId = randomUnknownWorkspaceId(random);

      expect(
        () => catalog.nameOfWorkspace(unknownId),
        throwsA(
          _isRecordNotFound(kind: 'workspace', identifier: unknownId.value),
        ),
      );
    }
  });

  test('test_name_of_workspace_property_order_of_records_is_irrelevant', () {
    final Random random = seededRandom(94106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final ScopeCatalog shuffled = _shuffleCatalog(random, catalog);
      final Workspace workspace = pickOne(random, catalog.workspaces);

      expect(
        shuffled.nameOfWorkspace(workspace.id),
        catalog.nameOfWorkspace(workspace.id),
      );
    }
  });

  test('test_name_of_project_property_names_every_listed_project', () {
    final Random random = seededRandom(94107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);

      for (final Project project in catalog.projects) {
        expect(catalog.nameOfProject(project.id), project.name);
      }
    }
  });

  test('test_name_of_project_property_unknown_id_fails_with_its_id', () {
    final Random random = seededRandom(94108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final ProjectId unknownId = randomUnknownProjectId(random);

      expect(
        () => catalog.nameOfProject(unknownId),
        throwsA(
          _isRecordNotFound(kind: 'project', identifier: unknownId.value),
        ),
      );
    }
  });

  test('test_name_of_project_property_never_answers_a_workspace_name', () {
    final Random random = seededRandom(94109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Workspace workspace = pickOne(random, catalog.workspaces);

      expect(
        () => catalog.nameOfProject(ProjectId(workspace.id.value)),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('test_find_workspace_id_property_round_trips_name_of_workspace', () {
    final Random random = seededRandom(94110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);

      for (final Workspace workspace in catalog.workspaces) {
        final WorkspaceId foundId = catalog.findWorkspaceId(workspace.name);

        expect(foundId, workspace.id);
        expect(catalog.nameOfWorkspace(foundId), workspace.name);
      }
    }
  });

  test('test_find_workspace_id_property_only_exact_names_match', () {
    final Random random = seededRandom(94111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Workspace workspace = pickOne(random, catalog.workspaces);
      final String nearMiss = pickOne(random, <String>[
        ' ${workspace.name}',
        '${workspace.name} ',
        '${workspace.name}x',
        workspace.id.value,
      ]);

      expect(
        () => catalog.findWorkspaceId(nearMiss),
        throwsA(_isRecordNotFound(kind: 'workspace', identifier: nearMiss)),
      );
    }
  });

  test('test_find_workspace_id_property_order_of_records_is_irrelevant', () {
    final Random random = seededRandom(94112);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final ScopeCatalog shuffled = _shuffleCatalog(random, catalog);
      final Workspace workspace = pickOne(random, catalog.workspaces);

      expect(shuffled.findWorkspaceId(workspace.name), workspace.id);
    }
  });

  test('test_find_project_id_property_round_trips_name_of_project', () {
    final Random random = seededRandom(94113);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);

      for (final Project project in catalog.projects) {
        final ProjectId foundId = catalog.findProjectId(project.name);

        expect(foundId, project.id);
        expect(catalog.nameOfProject(foundId), project.name);
      }
    }
  });

  test('test_find_project_id_property_only_exact_names_match', () {
    final Random random = seededRandom(94114);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Workspace workspace = pickOne(random, catalog.workspaces);
      final String nearMiss = pickOne(random, <String>[
        workspace.name,
        '${randomText(random)}x',
        '',
      ]);

      expect(
        () => catalog.findProjectId(nearMiss),
        throwsA(_isRecordNotFound(kind: 'project', identifier: nearMiss)),
      );
    }
  });

  test('test_find_project_id_property_order_of_records_is_irrelevant', () {
    final Random random = seededRandom(94115);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      if (catalog.projects.isEmpty) {
        continue;
      }
      final ScopeCatalog shuffled = _shuffleCatalog(random, catalog);
      final Project project = pickOne(random, catalog.projects);

      expect(shuffled.findProjectId(project.name), project.id);
    }
  });
}
