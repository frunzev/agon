import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/screens/files/file_pickers.dart';
import 'package:agent_orchestration/screens/files/file_source_status.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/screens/files/files_page_parts.dart';
import 'package:agent_orchestration/screens/files/no_runner_view.dart';
import 'package:agent_orchestration/screens/files/readme_section.dart';
import 'package:agent_orchestration/theme/layout_size.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'files_screen_scenarios.dart';
import 'project_files_screen_steps.dart';

void main() {
  testWidgets('test_project_files_screen_open_repository_property_branch', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(736001);

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

      final String? expected = predictInitialBranch(scenario);
      final Iterable<BranchPicker> pickers = tester.widgetList(
        find.byType(BranchPicker),
      );
      expect(pickers.length, expected == null ? 0 : 1);
      expect(find.byType(FileTreeView).evaluate().length, pickers.length);
      if (expected != null) {
        expect(pickers.single.chosenBranch, expected);
      }
    }
  });

  testWidgets('test_project_files_screen_open_repository_property_offline', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(736002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomScenarioWithSource(
        random,
        pickOne(random, <FilesSourceKind>[
          FilesSourceKind.offlineHolders,
          FilesSourceKind.unknown,
        ]),
      );
      final ScreenFileRepository files = await pumpProjectFilesAt(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );

      final NoRunnerView view = tester.widget(find.byType(NoRunnerView));
      final RepositoryFileSource? source = scenario.source;
      final List<RepositoryHolder> holders = source is FilesWithoutRunner
          ? source.holders
          : const <RepositoryHolder>[];
      expect(view.holders, holders);
      expect(find.byType(BranchPicker), findsNothing);
      expect(find.byType(FileTreeView), findsNothing);
      expect(files.askedOperations, <FileOperation>[FileOperation.open]);
    }
  });

  testWidgets('test_project_files_screen_open_repository_property_refused', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(736003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final String message = 'no ${randomHostileText(random)}';
      final ScreenFileRepository files = await pumpProjectFilesScenario(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
        navigation: navigationToProjectFiles(scenario),
        refusals: <FileOperation, Object>{
          FileOperation.open: PeopleFacingRefusal(message),
        },
      );

      expect(files.askedOperations, <FileOperation>[FileOperation.open]);
      expect(find.byType(NoRunnerView), findsNothing);
      expect(find.byType(FileTreeView), findsNothing);
      expect(find.byType(RepositoryPicker), findsOneWidget);
    }
  });

  testWidgets('test_project_files_screen_read_readme_property_large_shows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(736004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilePageScenario(random);
      await pumpProjectFilesAt(
        tester,
        scenario: scenario,
        size: randomLargeScreenSize(random),
      );

      final String? readmePath = findRootReadmePath(scenario);
      final Iterable<ReadmeSection> sections = tester.widgetList(
        find.byType(ReadmeSection),
      );
      expect(sections.length, readmePath == null ? 0 : 1);
      if (readmePath != null) {
        expect(sections.single.readme.path, readmePath);
      }
    }
  });

  testWidgets('test_project_files_screen_read_readme_property_reads_one', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(736005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final ScreenFileRepository files = await pumpProjectFilesAt(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );

      expect(files.readPaths.length, lessThan(2));
      for (final String path in files.readPaths) {
        expect(path, findRootReadmePath(scenario));
      }
    }
  });

  testWidgets('test_project_files_screen_read_readme_property_refusal_shown', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(736006);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilePageScenario(random);
      final String message = 'readme ${randomHostileText(random)}';
      final Size size = randomScreenSize(random);
      await pumpProjectFilesScenario(
        tester,
        scenario: scenario,
        size: size,
        navigation: navigationToProjectFiles(scenario),
        refusals: <FileOperation, Object>{
          FileOperation.read: PeopleFacingRefusal(message),
        },
      );

      final bool hasReadme = findRootReadmePath(scenario) != null;
      final bool showsReadme = LayoutSize.forWidth(size.width).isLarge;
      expect(
        find.byType(FilesProblem).evaluate().length,
        hasReadme && showsReadme ? 1 : 0,
      );
      expect(find.byType(FileTreeView), findsOneWidget);
      expect(find.byType(ReadmeSection), findsNothing);
    }
  });

  testWidgets('test_project_files_screen_attempt_property_words_kept', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(736007);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final String message = 'x${randomHostileText(random)}';
      await pumpProjectFilesScenario(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
        navigation: navigationToProjectFiles(scenario),
        refusals: <FileOperation, Object>{
          FileOperation.open: PeopleFacingRefusal(message),
        },
      );

      final FilesProblem problem = tester.widget(find.byType(FilesProblem));
      expect(problem.text, message);
    }
  });

  testWidgets('test_project_files_screen_attempt_property_missing_records', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(736008);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final RecordNotFound missing = RecordNotFound(
        kind: 'repository',
        identifier: randomHostileText(random),
      );
      await pumpProjectFilesScenario(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
        navigation: navigationToProjectFiles(scenario),
        refusals: <FileOperation, Object>{FileOperation.open: missing},
      );

      final FilesProblem problem = tester.widget(find.byType(FilesProblem));
      expect(problem.text, missing.toString());
    }
  });

  testWidgets('test_project_files_screen_attempt_property_answer_untouched', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(736009);

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
      expect(find.byType(FilesProblem), findsNothing);
    }
  });
}
