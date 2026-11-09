import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/screens/files/repository_file_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../data/repository/support/rust_repository_files_model.dart';
import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'files_screen_scenarios.dart';

typedef FilePage = (FilesScreenScenario, RepositoryFileRoute);

FilePage randomFilePage(Random random) {
  final FilesScreenScenario scenario = randomFilePageScenario(random);
  return (scenario, randomFileRoute(random, scenario));
}

FilePage randomPlainBranchFilePage(Random random) {
  final FilesScreenScenario scenario = replaceWithPlainBranches(
    randomFilePageScenario(random),
  );
  return (scenario, randomFileRoute(random, scenario));
}

RepositoryFileScreen buildFilePageScreenFor(
  FilePage page,
  ScreenFileRepository files,
) {
  final (FilesScreenScenario scenario, RepositoryFileRoute route) = page;
  return buildRepositoryFileScreen(
    scenario: scenario,
    route: route,
    fileRepository: files,
    navigation: navigationToFilePage(scenario, route),
  );
}

FakeRepositoryFile? predictReadFile(
  FilesScreenScenario scenario,
  String path,
) {
  final String normalizedPath;
  try {
    normalizedPath = normalizeRepositoryFolderPath(path);
  } on RustFileRefusal {
    return null;
  }
  for (final FakeRepositoryFile file in scenario.files) {
    if (file.path == normalizedPath) {
      return file;
    }
  }
  return null;
}

Future<ScreenFileRepository> pumpFilePage(
  WidgetTester tester, {
  required FilesScreenScenario scenario,
  required RepositoryFileRoute route,
  required Size size,
  required AppNavigation navigation,
  required Map<FileOperation, Object> refusals,
}) async {
  final ScreenFileRepository files = scenario.buildFileRepository();
  files.refusals.addAll(refusals);
  await pumpFilesScreen(
    tester,
    size: size,
    screen: buildRepositoryFileScreen(
      scenario: scenario,
      route: route,
      fileRepository: files,
      navigation: navigation,
    ),
  );
  return files;
}

Future<ScreenFileRepository> pumpFilePageAt(
  WidgetTester tester, {
  required FilePage page,
  required Size size,
}) {
  final (FilesScreenScenario scenario, RepositoryFileRoute route) = page;
  return pumpFilePage(
    tester,
    scenario: scenario,
    route: route,
    size: size,
    navigation: navigationToFilePage(scenario, route),
    refusals: const <FileOperation, Object>{},
  );
}

Future<AppNavigation> openFilePageThrough(
  WidgetTester tester, {
  required FilePage page,
  required Size size,
  required List<AppRoute> routes,
}) async {
  final AppNavigation navigation = navigationThrough(routes);
  await pumpFilePage(
    tester,
    scenario: page.$1,
    route: page.$2,
    size: size,
    navigation: navigation,
    refusals: const <FileOperation, Object>{},
  );
  return navigation;
}

Future<AppNavigation> openStackedFilePage(
  WidgetTester tester, {
  required FilePage page,
  required Size size,
}) {
  return openFilePageThrough(
    tester,
    page: page,
    size: size,
    routes: <AppRoute>[
      const ProjectRoute(scenarioProjectId),
      page.$1.route,
      page.$2,
    ],
  );
}
