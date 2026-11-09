import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/project_files_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';

import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'files_screen_scenarios.dart';

const String _readmeName = 'readme.md';
const String _pathSeparator = '/';

typedef LocationFields = (String, String, String, String);

String? predictInitialBranch(FilesScreenScenario scenario) {
  final List<String> listed = listBranchesOf(scenario);
  final String? requested = scenario.route.branch;
  final String defaultBranch = scenario.chosenRepository.defaultBranch;
  if (requested != null && listed.contains(requested)) {
    return requested;
  }
  if (listed.contains(defaultBranch)) {
    return defaultBranch;
  }
  if (listed.isEmpty) {
    return null;
  }
  return listed.first;
}

String? findRootReadmePath(FilesScreenScenario scenario) {
  for (final FakeRepositoryFile file in scenario.files) {
    final bool isRootReadme =
        !file.path.contains(_pathSeparator) &&
        file.path.toLowerCase() == _readmeName;
    if (isRootReadme) {
      return file.path;
    }
  }
  return null;
}

LocationFields describeLocation(RepositoryBranchLocation location) {
  return (
    location.projectId.value,
    location.repositoryAddress,
    location.runnerId.value,
    location.branch,
  );
}

Future<ScreenFileRepository> pumpProjectFilesScenario(
  WidgetTester tester, {
  required FilesScreenScenario scenario,
  required Size size,
  required AppNavigation navigation,
  required Map<FileOperation, Object> refusals,
}) async {
  final ScreenFileRepository files = scenario.buildFileRepository();
  files.refusals.addAll(refusals);
  await pumpFilesScreen(
    tester,
    size: size,
    screen: buildProjectFilesScreen(
      scenario: scenario,
      fileRepository: files,
      navigation: navigation,
    ),
  );
  return files;
}

Future<ScreenFileRepository> pumpProjectFilesAt(
  WidgetTester tester, {
  required FilesScreenScenario scenario,
  required Size size,
}) {
  return pumpProjectFilesScenario(
    tester,
    scenario: scenario,
    size: size,
    navigation: navigationToProjectFiles(scenario),
    refusals: const <FileOperation, Object>{},
  );
}

ProjectFilesScreen buildProjectFilesScreenFor(
  FilesScreenScenario scenario,
  ScreenFileRepository files,
) {
  return buildProjectFilesScreen(
    scenario: scenario,
    fileRepository: files,
    navigation: navigationToProjectFiles(scenario),
  );
}

Future<(AppNavigation, ScreenFileRepository)> openProjectFiles(
  WidgetTester tester, {
  required FilesScreenScenario scenario,
  required Size size,
}) async {
  final AppNavigation navigation = navigationToProjectFiles(scenario);
  final ScreenFileRepository files = await pumpProjectFilesScenario(
    tester,
    scenario: scenario,
    size: size,
    navigation: navigation,
    refusals: const <FileOperation, Object>{},
  );
  return (navigation, files);
}
