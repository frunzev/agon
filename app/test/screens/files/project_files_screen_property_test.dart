import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/screens/files/project_files_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'files_screen_scenarios.dart';
import 'project_files_screen_steps.dart';

void main() {
  test('test_project_files_screen_new_property_keeps_every_dependency', () {
    final Random random = seededRandom(735001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final ScreenFileRepository files = scenario.buildFileRepository();
      final FixedProjectRepository projects = FixedProjectRepository(
        scenario.project,
      );
      final Clock clock = FixedClock(scenarioNow);
      final AppNavigation navigation = navigationToProjectFiles(scenario);
      final ProjectFilesScreen screen = ProjectFilesScreen(
        route: scenario.route,
        projectRepository: projects,
        fileRepository: files,
        clock: clock,
        navigation: navigation,
      );

      expect(identical(screen.route, scenario.route), isTrue);
      expect(identical(screen.projectRepository, projects), isTrue);
      expect(identical(screen.fileRepository, files), isTrue);
      expect(identical(screen.clock, clock), isTrue);
      expect(identical(screen.navigation, navigation), isTrue);
    }
  });

  test('test_project_files_screen_new_property_keeps_the_key', () {
    final Random random = seededRandom(735002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final Key key = ValueKey<String>(randomHostileText(random));
      final ProjectFilesScreen screen = ProjectFilesScreen(
        key: key,
        route: scenario.route,
        projectRepository: FixedProjectRepository(scenario.project),
        fileRepository: scenario.buildFileRepository(),
        clock: FixedClock(scenarioNow),
        navigation: navigationToProjectFiles(scenario),
      );

      expect(screen.key, key);
    }
  });

  test('test_project_files_screen_new_property_asks_nothing_yet', () {
    final Random random = seededRandom(735003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final ScreenFileRepository files = scenario.buildFileRepository();
      final AppNavigation navigation = navigationToProjectFiles(scenario);
      buildProjectFilesScreen(
        scenario: scenario,
        fileRepository: files,
        navigation: navigation,
      );

      expect(files.askedOperations, isEmpty);
      expect(navigation.currentRoute, scenario.route);
    }
  });

  test('test_project_files_screen_create_state_property_fresh_and_idle', () {
    final Random random = seededRandom(735004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final ScreenFileRepository files = scenario.buildFileRepository();
      final ProjectFilesScreen screen = buildProjectFilesScreenFor(
        scenario,
        files,
      );
      final State<ProjectFilesScreen> first = screen.createState();
      final State<ProjectFilesScreen> second = screen.createState();

      expect(identical(first, second), isFalse);
      expect(first.mounted, isFalse);
      expect(files.askedOperations, isEmpty);
    }
  });

  testWidgets(
    'test_project_files_screen_create_state_property_serves_widget',
    (WidgetTester tester) async {
      final Random random = seededRandom(735005);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final FilesScreenScenario scenario = randomFilesScreenScenario(random);
        final ProjectFilesScreen screen = buildProjectFilesScreenFor(
          scenario,
          scenario.buildFileRepository(),
        );
        await pumpFilesScreen(
          tester,
          size: randomScreenSize(random),
          screen: screen,
        );

        final State<ProjectFilesScreen> state = tester.state(
          find.byType(ProjectFilesScreen),
        );
        expect(identical(state.widget, screen), isTrue);
        expect(state.mounted, isTrue);
      }
    },
  );

  testWidgets(
    'test_project_files_screen_create_state_property_one_per_mount',
    (WidgetTester tester) async {
      final Random random = seededRandom(735006);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final FilesScreenScenario scenario = randomFilesScreenScenario(random);
        final ScreenFileRepository files = scenario.buildFileRepository();
        await pumpFilesScreen(
          tester,
          size: randomScreenSize(random),
          screen: buildProjectFilesScreenFor(scenario, files),
        );
        await closeFilesScreen(tester);
        await pumpFilesScreen(
          tester,
          size: randomScreenSize(random),
          screen: buildProjectFilesScreenFor(scenario, files),
        );

        expect(files.countAsked(FileOperation.open), 2);
      }
    },
  );
}
