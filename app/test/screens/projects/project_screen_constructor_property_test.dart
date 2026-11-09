import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/fixed_folder_picker.dart';
import '../../support/random_inputs.dart';

ProjectScreen _buildScreen(
  AppDependencies dependencies,
  ProjectId projectId, {
  required Key? key,
}) {
  return ProjectScreen(
    key: key,
    projectId: projectId,
    projectRepository: dependencies.projectRepository,
    workspaceRepository: dependencies.workspaceRepository,
    taskRepository: dependencies.taskRepository,
    ruleRepository: dependencies.ruleRepository,
    deviceRepository: dependencies.deviceRepository,
    folderPicker: FixedFolderPicker(null),
    navigation: AppNavigation(initialRoute: ProjectRoute(projectId)),
  );
}

void main() {
  test('test_project_screen_new_property_keeps_every_field', () {
    final Random random = seededRandom(1051001);
    final AppDependencies dependencies = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final ProjectId projectId = ProjectId('p-${random.nextInt(1 << 20)}');
      final ProjectScreen screen = _buildScreen(
        dependencies,
        projectId,
        key: null,
      );

      expect(screen.projectId, projectId);
      expect(screen.projectRepository, same(dependencies.projectRepository));
      expect(screen.taskRepository, same(dependencies.taskRepository));
      expect(screen.ruleRepository, same(dependencies.ruleRepository));
      expect(screen.deviceRepository, same(dependencies.deviceRepository));
    }
  });

  test('test_project_screen_new_property_folder_picker_may_be_missing', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final ProjectScreen screen = ProjectScreen(
      projectId: GalleryProjectIds.docs,
      projectRepository: dependencies.projectRepository,
      workspaceRepository: dependencies.workspaceRepository,
      taskRepository: dependencies.taskRepository,
      ruleRepository: dependencies.ruleRepository,
      deviceRepository: dependencies.deviceRepository,
      folderPicker: null,
      navigation: AppNavigation(
        initialRoute: const ProjectRoute(GalleryProjectIds.docs),
      ),
    );

    expect(screen.folderPicker, isNull);
    expect(screen.workspaceRepository, same(dependencies.workspaceRepository));
  });

  test('test_project_screen_new_property_keeps_the_key', () {
    final Random random = seededRandom(1051002);
    final AppDependencies dependencies = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(1 << 20));

      expect(
        _buildScreen(dependencies, GalleryProjectIds.docs, key: key).key,
        key,
      );
    }
  });
}
