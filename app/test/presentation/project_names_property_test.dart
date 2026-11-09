import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/presentation/project_names.dart';

import '../support/fake_task_work_links.dart';
import '../support/random_inputs.dart';

const String _gonePrefix = 'gone-';

List<Project> _listCurrentProjects(AppDependencies dependencies) {
  final WorkspaceId workspaceId = dependencies.workspaceRepository
      .currentWorkspace()
      .id;
  return dependencies.projectRepository.listProjects(workspaceId);
}

void main() {
  test('test_describe_project_name_property_known_projects_show_their_'
      'name', () {
    final Random random = seededRandom(5312201);
    final AppDependencies dependencies = buildGalleryDependencies();
    final List<Project> projects = _listCurrentProjects(dependencies);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = pickOne(random, projects);

      final String name = describeProjectName(
        projectRepository: dependencies.projectRepository,
        projectId: project.id,
      );

      expect(name, project.name);
    }
  });

  test('test_describe_project_name_property_unknown_projects_read_as_their_'
      'short_identifier', () {
    final Random random = seededRandom(5312202);
    final AppDependencies dependencies = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final ProjectId unknown = ProjectId('$_gonePrefix${randomText(random)}');

      final String name = describeProjectName(
        projectRepository: dependencies.projectRepository,
        projectId: unknown,
      );

      expect(name, shortenIdentifier(unknown.value));
    }
  });

  test('test_describe_project_name_property_deleting_one_project_renames_'
      'only_it', () async {
    final Random random = seededRandom(5312203);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final AppDependencies gallery = buildGalleryDependencies();
      final List<Project> projects = _listCurrentProjects(gallery);
      final FakeProjectRepository projectRepository = FakeProjectRepository(
        projects: projects,
        taskWork: buildEmptyTaskWork(),
      );
      final Project deleted = pickOne(random, projects);

      await projectRepository.deleteProject(deleted.id);

      for (final Project project in projects) {
        final String expected = project.id == deleted.id
            ? shortenIdentifier(project.id.value)
            : project.name;
        expect(
          describeProjectName(
            projectRepository: projectRepository,
            projectId: project.id,
          ),
          expected,
        );
      }
    }
  });
}
