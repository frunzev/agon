import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/files/file_pickers.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/random_inputs.dart';
import 'file_screen_steps.dart';
import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'files_screen_scenarios.dart';
import 'project_files_screen_steps.dart';

void main() {
  testWidgets('test_project_files_screen_choose_repository_property_bare', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(738004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final (
        AppNavigation navigation,
        ScreenFileRepository _,
      ) = await openProjectFiles(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );
      final Repository picked = pickOne(random, scenario.project.repositories);
      tester
          .widget<RepositoryPicker>(find.byType(RepositoryPicker))
          .onChosen(picked.address);

      expect(navigation.routes, <AppRoute>[
        const ProjectRoute(scenarioProjectId),
        ProjectFilesRoute(
          projectId: scenarioProjectId,
          repositoryAddress: picked.address,
        ),
      ]);
    }
  });

  testWidgets('test_project_files_screen_choose_repository_property_drops', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(738005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final (
        AppNavigation navigation,
        ScreenFileRepository _,
      ) = await openProjectFiles(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );
      final Repository picked = pickOne(random, scenario.project.repositories);
      tester
          .widget<RepositoryPicker>(find.byType(RepositoryPicker))
          .onChosen(picked.address);

      final ProjectFilesRoute route =
          navigation.currentRoute as ProjectFilesRoute;
      expect(route.branch, isNull);
      expect(route.preferredRunnerId, isNull);
      expect(route.projectId, scenarioProjectId);
    }
  });

  testWidgets('test_project_files_screen_choose_repository_property_menu', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(738006);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final (
        AppNavigation navigation,
        ScreenFileRepository _,
      ) = await openProjectFiles(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );
      final Repository picked = pickOne(random, scenario.project.repositories);
      if (picked.address == scenario.route.repositoryAddress) {
        continue;
      }
      await choosePickerOption(
        tester,
        label: repositoryPickerLabel,
        option: describeRepositoryPath(picked.address),
      );

      final ProjectFilesRoute route =
          navigation.currentRoute as ProjectFilesRoute;
      expect(route.repositoryAddress, picked.address);
      expect(navigation.routes.length, 2);
    }
  });

  testWidgets('test_project_files_screen_choose_branch_property_runner_kept', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(738007);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilePageScenario(random);
      final (
        AppNavigation navigation,
        ScreenFileRepository _,
      ) = await openProjectFiles(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );
      final String branch = pickOne(random, listBranchesOf(scenario));
      tester.widget<BranchPicker>(find.byType(BranchPicker)).onChosen(branch);

      final FilesFromRunner source = scenario.source! as FilesFromRunner;
      expect(
        navigation.currentRoute,
        ProjectFilesRoute(
          projectId: scenarioProjectId,
          repositoryAddress: scenario.route.repositoryAddress,
          branch: branch,
          preferredRunnerId: source.runnerId,
        ),
      );
    }
  });

  testWidgets('test_project_files_screen_choose_branch_property_replaces', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(738008);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilePageScenario(random);
      final (
        AppNavigation navigation,
        ScreenFileRepository _,
      ) = await openProjectFiles(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );
      final String branch = pickOne(random, listBranchesOf(scenario));
      tester.widget<BranchPicker>(find.byType(BranchPicker)).onChosen(branch);

      expect(navigation.routes.length, 2);
      expect(navigation.routes.first, const ProjectRoute(scenarioProjectId));
    }
  });

  testWidgets('test_project_files_screen_choose_branch_property_menu', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(738009);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = replaceWithPlainBranches(
        randomFilePageScenario(random),
      );
      final (
        AppNavigation navigation,
        ScreenFileRepository _,
      ) = await openProjectFiles(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );
      final String chosen = predictInitialBranch(scenario)!;
      final String other = pickOne(random, <String>[
        for (final String branch in plainBranches)
          if (branch != chosen) branch,
      ]);
      await choosePickerOption(
        tester,
        label: branchPickerLabel,
        option: other,
      );

      final ProjectFilesRoute route =
          navigation.currentRoute as ProjectFilesRoute;
      expect(route.branch, other);
    }
  });
}
