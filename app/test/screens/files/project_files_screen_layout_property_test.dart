import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/files/file_pickers.dart';
import 'package:agent_orchestration/screens/files/file_source_status.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/screens/files/no_runner_text.dart';
import 'package:agent_orchestration/screens/files/no_runner_view.dart';
import 'package:agent_orchestration/screens/files/readme_section.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';

import '../../support/random_inputs.dart';
import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'files_screen_scenarios.dart';
import 'project_files_screen_steps.dart';

void main() {
  testWidgets('test_project_files_screen_find_project_property_back_label', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(739001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      await pumpProjectFilesAt(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );

      final PageHeader header = tester.widget(find.byType(PageHeader));
      expect(header.backLink!.label, scenario.project.name);
    }
  });

  testWidgets('test_project_files_screen_find_project_property_repositories', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(739002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      await pumpProjectFilesAt(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );

      final RepositoryPicker picker = tester.widget(
        find.byType(RepositoryPicker),
      );
      expect(picker.repositories, scenario.project.repositories);
      expect(picker.chosenAddress, scenario.route.repositoryAddress);
    }
  });

  testWidgets('test_project_files_screen_find_project_property_any_answer', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(739003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final FileOperation refused = pickOne(random, FileOperation.values);
      await pumpProjectFilesScenario(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
        navigation: navigationToProjectFiles(scenario),
        refusals: <FileOperation, Object>{
          refused: PeopleFacingRefusal('refused $refused'),
        },
      );

      final PageHeader header = tester.widget(find.byType(PageHeader));
      final RepositoryPicker picker = tester.widget(
        find.byType(RepositoryPicker),
      );
      expect(header.backLink!.label, scenario.project.name);
      expect(picker.repositories, scenario.project.repositories);
    }
  });

  testWidgets('test_project_files_screen_build_body_property_while_opening', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(739004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final ScreenFileRepository files = scenario.buildFileRepository();
      files.heldOperations.add(FileOperation.open);
      await pumpFilesScreen(
        tester,
        size: randomScreenSize(random),
        screen: buildProjectFilesScreen(
          scenario: scenario,
          fileRepository: files,
          navigation: navigationToProjectFiles(scenario),
        ),
      );

      expect(find.byType(RepositoryPicker), findsOneWidget);
      expect(find.byType(BranchPicker), findsNothing);
      expect(find.byType(NoRunnerView), findsNothing);
      expect(find.byType(FileSourceStatus), findsNothing);
      files.releaseHeldAnswers();
      await settleFilesScreen(tester);
    }
  });

  testWidgets('test_project_files_screen_build_body_property_no_runner_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(739005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomOfflineScenario(random);
      await pumpProjectFilesAt(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );

      final String repositoryPath = describeRepositoryPath(
        scenario.route.repositoryAddress,
      );
      final NoRunnerView view = tester.widget(find.byType(NoRunnerView));
      expect(view.repositoryPath, repositoryPath);
      expect(view.now, scenarioNow);
      expect(find.text(describeNoRunnerTitle(repositoryPath)), findsOneWidget);
    }
  });

  testWidgets('test_project_files_screen_build_body_property_see_runners', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(739006);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomOfflineScenario(random);
      final AppNavigation navigation = navigationToProjectFiles(scenario);
      await pumpProjectFilesScenario(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
        navigation: navigation,
        refusals: const <FileOperation, Object>{},
      );
      tester.widget<NoRunnerView>(find.byType(NoRunnerView)).onSeeRunners();

      expect(navigation.routes, <AppRoute>[
        const ProjectRoute(scenarioProjectId),
        scenario.route,
        const SectionRoute(AppSection.devices),
      ]);
    }
  });

  testWidgets('test_project_files_screen_build_browser_property_split_large', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(739007);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilePageScenario(random);
      final Size size = randomScreenSize(random);
      await pumpProjectFilesAt(tester, scenario: scenario, size: size);

      final bool isLarge = LayoutSize.forWidth(size.width).isLarge;
      expect(find.byType(SplitLayout).evaluate().length, isLarge ? 1 : 0);
      if (!isLarge) {
        expect(find.byType(ReadmeSection), findsNothing);
      }
      expect(find.byType(FileTreeView), findsOneWidget);
    }
  });

  testWidgets(
    'test_project_files_screen_build_browser_property_names_runner',
    (WidgetTester tester) async {
      final Random random = seededRandom(739008);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final FilesScreenScenario scenario = randomScenarioWithSource(
          random,
          FilesSourceKind.runner,
        );
        await pumpProjectFilesAt(
          tester,
          scenario: scenario,
          size: randomScreenSize(random),
        );

        final FilesFromRunner source = scenario.source! as FilesFromRunner;
        final FileSourceStatus status = tester.widget(
          find.byType(FileSourceStatus),
        );
        expect(status.runnerName, source.runnerName);
        expect(find.byType(NoRunnerView), findsNothing);
      }
    },
  );

  testWidgets('test_project_files_screen_build_browser_property_no_branches', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(739009);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario base = randomScenarioWithSource(
        random,
        FilesSourceKind.runner,
      );
      final FilesFromRunner source = base.source! as FilesFromRunner;
      final FilesScreenScenario scenario = replaceScenarioSource(
        base,
        FilesFromRunner(
          runnerId: source.runnerId,
          runnerName: source.runnerName,
          branches: const <String>[],
          taskBranches: const <String>[],
        ),
      );
      final ScreenFileRepository files = await pumpProjectFilesAt(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );

      expect(find.byType(BranchPicker), findsNothing);
      expect(find.byType(FileTreeView), findsNothing);
      expect(find.byType(FileSourceStatus), findsOneWidget);
      expect(files.askedOperations, <FileOperation>[FileOperation.open]);
    }
  });
}
