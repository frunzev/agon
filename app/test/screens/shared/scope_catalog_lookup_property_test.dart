import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/shared/scope_catalog_lookup.dart';

import '../../bridge/support/node_json_primitives.dart';
import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import '../../support/random_scope_catalogs.dart';

const int _mostProjects = 12;

List<Project> _randomProjects(Random random) {
  final List<WorkspaceId> workspaceIds = <WorkspaceId>[
    for (final Workspace workspace in galleryWorkspaces) workspace.id,
    randomUnknownWorkspaceId(random),
  ];
  final int count = random.nextInt(_mostProjects);
  return <Project>[
    for (int index = 0; index < count; index += 1)
      buildNamedProject(
        projectId: ProjectId(randomUuidText(random)),
        workspaceId: pickOne(random, workspaceIds),
        name: randomUniqueHostileName(random, index),
      ),
  ];
}

ScopeCatalog _collectFrom(List<Project> projects) {
  final AppDependencies dependencies = buildGalleryDependencies();
  return collectScopeCatalog(
    workspaceRepository: buildAcmeWorkspaceRepository(),
    projectRepository: buildProjectRepositoryOver(dependencies, projects),
  );
}

void main() {
  test('test_collect_scope_catalog_property_projects_follow_workspaces', () {
    final Random random = seededRandom(112101);

    for (int i = 0; i < 60; i += 1) {
      final List<Project> projects = _randomProjects(random);

      final ScopeCatalog catalog = _collectFrom(projects);

      final List<Project> expected = <Project>[
        for (final Workspace workspace in galleryWorkspaces)
          for (final Project project in projects)
            if (project.workspaceId == workspace.id) project,
      ];
      expect(catalog.projects, orderedEquals(expected));
    }
  });

  test('test_collect_scope_catalog_property_leaves_out_unlisted_places', () {
    final Random random = seededRandom(112102);

    for (int i = 0; i < 60; i += 1) {
      final ScopeCatalog catalog = _collectFrom(_randomProjects(random));

      final Set<WorkspaceId> listedWorkspaceIds = <WorkspaceId>{
        for (final Workspace workspace in catalog.workspaces) workspace.id,
      };
      for (final Project project in catalog.projects) {
        expect(listedWorkspaceIds, contains(project.workspaceId));
      }
    }
  });

  test('test_collect_scope_catalog_property_lists_every_workspace_once', () {
    final Random random = seededRandom(112103);
    final FakeWorkspaceRepository workspaces = buildAcmeWorkspaceRepository();

    for (int i = 0; i < 60; i += 1) {
      final ScopeCatalog catalog = _collectFrom(_randomProjects(random));

      expect(catalog.workspaces, orderedEquals(workspaces.listWorkspaces()));
      expect(
        () => catalog.workspaces.add(galleryWorkspaces.first),
        throwsUnsupportedError,
      );
    }
  });
}
