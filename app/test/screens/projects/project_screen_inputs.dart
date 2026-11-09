import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/list_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'project_repositories_editor_inputs.dart';

const int _largestRepositoryCount = 7;
const double _shortestHeight = 560;
const double _tallestHeight = 1200;
const List<String> _branches = <String>['main', 'trunk', 'release/2.4'];

final class ShownProjectPage {
  const ShownProjectPage({
    required this.navigation,
    required this.dependencies,
    required this.project,
  });

  final AppNavigation navigation;
  final AppDependencies dependencies;
  final Project project;

  Project findStoredProject() {
    return dependencies.projectRepository.findProject(project.id);
  }
}

List<Repository> randomScreenRepositories(Random random) {
  final int count = random.nextInt(_largestRepositoryCount);
  final List<Repository> repositories = <Repository>[];
  for (int index = 0; index < count; index += 1) {
    final Device device = pickOne(random, galleryDevices);
    final String address = random.nextBool()
        ? '${randomCanonicalHostedAddress(random)}-$index'
        : renderLocalFolderAddress(
            deviceId: device.id,
            path: randomFolderPath(random, index),
          );
    repositories.add(
      Repository(
        address: address,
        defaultBranch: pickOne(random, _branches),
        agentAccess: pickOne(random, AgentAccess.values),
      ),
    );
  }
  return repositories;
}

Size randomProjectPageSize(Random random) {
  return Size(
    randomWidth(random, least: narrowestWidth, most: widestWidth),
    randomWidth(random, least: _shortestHeight, most: _tallestHeight),
  );
}

Future<ShownProjectPage> pumpRandomProjectPage(
  WidgetTester tester,
  Random random,
) async {
  final Project galleryProject = pickOne(random, galleryProjects);
  final List<Repository> repositories = randomScreenRepositories(random);
  final AppDependencies dependencies = buildDependenciesWithRepositories(
    projectId: galleryProject.id,
    repositories: repositories,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: randomProjectPageSize(random),
    route: ProjectRoute(galleryProject.id),
    dependencies: dependencies,
  );
  return ShownProjectPage(
    navigation: navigation,
    dependencies: dependencies,
    project: galleryProject.withRepositories(repositories),
  );
}

final class RefusingRepositoryChanges implements ProjectRepository {
  RefusingRepositoryChanges({required this.stored, required this.message});

  final ProjectRepository stored;
  final String message;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Project> listProjects(WorkspaceId workspaceId) {
    return stored.listProjects(workspaceId);
  }

  @override
  Project findProject(ProjectId projectId) => stored.findProject(projectId);

  @override
  Future<Project> createProject(ProjectDraft draft) {
    return stored.createProject(draft);
  }

  @override
  Future<Project> addRepository(ProjectId projectId, Repository repository) {
    return Future<Project>.error(PeopleFacingRefusal(message));
  }

  @override
  Future<Project> removeRepository(ProjectId projectId, String address) {
    return Future<Project>.error(PeopleFacingRefusal(message));
  }

  @override
  Future<void> deleteProject(ProjectId projectId) {
    return stored.deleteProject(projectId);
  }
}
