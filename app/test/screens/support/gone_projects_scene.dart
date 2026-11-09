import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/fake_task_work_links.dart';
import 'random_page_windows.dart';

List<Project> _listCurrentProjects(AppDependencies dependencies) {
  final WorkspaceId workspaceId = dependencies.workspaceRepository
      .currentWorkspace()
      .id;
  return dependencies.projectRepository.listProjects(workspaceId);
}

AppDependencies buildWithSomeProjectsGone(Random random) {
  final AppDependencies gallery = buildGalleryDependencies();
  final List<Project> kept = <Project>[
    for (final Project project in _listCurrentProjects(gallery))
      if (random.nextBool()) project,
  ];
  return replaceRepositories(
    gallery,
    projectRepository: buildProjectRepositoryOver(gallery, kept),
  );
}

Future<void> pumpSectionAtRandomSize(
  WidgetTester tester, {
  required Random random,
  required AppDependencies dependencies,
  required AppSection section,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: randomPageWindowSize(random),
    route: SectionRoute(section),
    dependencies: dependencies,
  );
}

String? findGoneProjectShortName(AppDependencies dependencies, Task task) {
  final bool isKnown = _listCurrentProjects(dependencies)
      .any((Project project) => project.id == task.projectId);
  if (isKnown) {
    return null;
  }
  return shortenIdentifier(task.projectId.value);
}

String? findKeptProjectName(AppDependencies dependencies, Task task) {
  for (final Project project in _listCurrentProjects(dependencies)) {
    if (project.id == task.projectId) {
      return project.name;
    }
  }
  return null;
}
