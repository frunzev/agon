import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/file_source_status.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/screens/files/no_runner_view.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'file_property_inputs.dart';
import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'files_screen_scenarios.dart';
import 'project_files_screen_steps.dart';

const int _largestTryCount = 4;

void main() {
  testWidgets('test_project_files_screen_try_again_property_same_question', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(738001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomOfflineScenario(random);
      final (
        AppNavigation _,
        ScreenFileRepository files,
      ) = await openProjectFiles(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );
      await tester.ensureVisible(find.text(tryAgainLabel));
      await tester.tap(find.text(tryAgainLabel));
      await settleFilesScreen(tester);

      final List<Object?> preferred = <Object?>[
        scenario.route.preferredRunnerId,
        scenario.route.preferredRunnerId,
      ];
      expect(files.preferredRunners, preferred);
      expect(find.byType(NoRunnerView), findsOneWidget);
    }
  });

  testWidgets('test_project_files_screen_try_again_property_finds_runner', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(738002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomOfflineScenario(random);
      final FilesFromRunner runner =
          randomFilePageScenario(random).source! as FilesFromRunner;
      final (
        AppNavigation _,
        ScreenFileRepository files,
      ) = await openProjectFiles(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );
      files.answers = FakeFileRepository(
        sources: <String, RepositoryFileSource>{
          scenario.route.repositoryAddress: runner,
        },
        files: scenario.files,
      );
      tester.widget<NoRunnerView>(find.byType(NoRunnerView)).onTryAgain();
      await settleFilesScreen(tester);

      final FileSourceStatus status = tester.widget(
        find.byType(FileSourceStatus),
      );
      expect(status.runnerName, runner.runnerName);
      expect(find.byType(NoRunnerView), findsNothing);
      expect(find.byType(FileTreeView), findsOneWidget);
    }
  });

  testWidgets('test_project_files_screen_try_again_property_each_try_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(738003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomOfflineScenario(random);
      final (
        AppNavigation _,
        ScreenFileRepository files,
      ) = await openProjectFiles(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );
      final int tryCount = 1 + random.nextInt(_largestTryCount);
      for (int attempt = 0; attempt < tryCount; attempt += 1) {
        tester.widget<NoRunnerView>(find.byType(NoRunnerView)).onTryAgain();
        await settleFilesScreen(tester);
      }

      expect(files.preferredRunners.length, tryCount + 1);
      expect(find.byType(NoRunnerView), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_project_files_screen_open_file_property_pushes_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(738010);

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
      final String path = randomFilePath(random);
      tester.widget<FileTreeView>(find.byType(FileTreeView)).onOpenFile(path);

      final RepositoryFileRoute route =
          navigation.currentRoute as RepositoryFileRoute;
      expect(navigation.routes.length, 3);
      expect(route.filesRoute, scenario.route);
      expect(route.branch, predictInitialBranch(scenario));
      expect(route.path, path);
      expect(identical(route.source, scenario.source), isTrue);
    }
  });

  testWidgets('test_project_files_screen_open_file_property_row_tap', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(738011);

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
      final Finder fileRows = find.byWidgetPredicate(
        (Widget widget) =>
            widget is FileTreeRow &&
            widget.folderState == FolderState.notAFolder,
      );
      if (fileRows.evaluate().isEmpty) {
        continue;
      }
      final FileTreeRow row = tester.widget(fileRows.first);
      await tester.ensureVisible(fileRows.first);
      await tester.tap(fileRows.first);
      await settleFilesScreen(tester);

      final RepositoryFileRoute route =
          navigation.currentRoute as RepositoryFileRoute;
      expect(route.path, row.name);
    }
  });

  testWidgets('test_project_files_screen_open_file_property_paths_verbatim', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(738012);

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
      final List<String> paths = <String>[
        randomHostileText(random),
        randomHostileText(random),
      ];
      for (final String path in paths) {
        tester
            .widget<FileTreeView>(find.byType(FileTreeView))
            .onOpenFile(path);
      }

      final List<String> opened = <String>[
        for (final AppRoute route in navigation.routes.skip(2))
          (route as RepositoryFileRoute).path,
      ];
      expect(opened, paths);
    }
  });
}
