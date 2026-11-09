import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/repository/file_repository.dart';
import 'package:agent_orchestration/screens/files/file_pickers.dart';
import 'package:agent_orchestration/screens/files/project_files_screen.dart';
import 'package:agent_orchestration/screens/files/repository_file_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/layout_size.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'files_screen_repositories.dart';
import 'files_screen_scenarios.dart';

const double _shortestHeight = 480;
const double _tallestHeight = 1200;
const int _settlingPumps = 6;
const double _widestSmallWidth = LayoutSize.largeMinimumWidth - 1;
const String _clipboardMethod = 'Clipboard.setData';
const String _clipboardTextField = 'text';

Size randomScreenSize(Random random) {
  return Size(
    randomWidth(random, least: narrowestWidth, most: widestWidth),
    _randomHeight(random),
  );
}

Size randomLargeScreenSize(Random random) {
  return Size(
    randomWidth(
      random,
      least: LayoutSize.largeMinimumWidth,
      most: widestWidth,
    ),
    _randomHeight(random),
  );
}

Size randomSmallScreenSize(Random random) {
  return Size(
    randomWidth(random, least: narrowestWidth, most: _widestSmallWidth),
    _randomHeight(random),
  );
}

double _randomHeight(Random random) {
  return randomWidth(random, least: _shortestHeight, most: _tallestHeight);
}

AppNavigation navigationThrough(List<AppRoute> routes) {
  final AppNavigation navigation = AppNavigation(initialRoute: routes.first);
  navigation.restoreRoutes(routes);
  return navigation;
}

AppNavigation navigationToProjectFiles(FilesScreenScenario scenario) {
  return navigationThrough(<AppRoute>[
    ProjectRoute(scenario.project.id),
    scenario.route,
  ]);
}

AppNavigation navigationToFilePage(
  FilesScreenScenario scenario,
  RepositoryFileRoute fileRoute,
) {
  return navigationThrough(<AppRoute>[
    ProjectRoute(scenario.project.id),
    scenario.route,
    fileRoute,
  ]);
}

ProjectFilesScreen buildProjectFilesScreen({
  required FilesScreenScenario scenario,
  required FileRepository fileRepository,
  required AppNavigation navigation,
}) {
  return ProjectFilesScreen(
    key: UniqueKey(),
    route: scenario.route,
    projectRepository: FixedProjectRepository(scenario.project),
    fileRepository: fileRepository,
    clock: FixedClock(scenarioNow),
    navigation: navigation,
  );
}

RepositoryFileScreen buildRepositoryFileScreen({
  required FilesScreenScenario scenario,
  required RepositoryFileRoute route,
  required FileRepository fileRepository,
  required AppNavigation navigation,
}) {
  return RepositoryFileScreen(
    key: UniqueKey(),
    route: route,
    projectRepository: FixedProjectRepository(scenario.project),
    fileRepository: fileRepository,
    navigation: navigation,
  );
}

Future<void> pumpFilesScreen(
  WidgetTester tester, {
  required Size size,
  required Widget screen,
}) async {
  useViewSize(tester, size);
  await tester.pumpWidget(
    wrapInApp(screen, platform: platformMeantByWidth(size.width)),
  );
  await settleFilesScreen(tester);
}

Future<void> settleFilesScreen(WidgetTester tester) async {
  for (int index = 0; index < _settlingPumps; index += 1) {
    await tester.pump();
  }
}

Future<void> closeFilesScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await settleFilesScreen(tester);
}

List<Object?> recordClipboardTexts(WidgetTester tester) {
  final List<Object?> copiedTexts = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == _clipboardMethod) {
        final Map<Object?, Object?> arguments =
            call.arguments as Map<Object?, Object?>;
        copiedTexts.add(arguments[_clipboardTextField]);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copiedTexts;
}

void pickBranch(WidgetTester tester, String branch) {
  tester.widget<BranchPicker>(find.byType(BranchPicker)).onChosen(branch);
}

void pickRepository(WidgetTester tester, String address) {
  final RepositoryPicker picker = tester.widget(find.byType(RepositoryPicker));
  picker.onChosen(address);
}
