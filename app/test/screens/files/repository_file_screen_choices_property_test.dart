import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/files/file_pickers.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'file_screen_steps.dart';
import 'files_screen_pumps.dart';
import 'files_screen_scenarios.dart';
import 'repository_file_screen_steps.dart';

void main() {
  testWidgets('test_repository_file_screen_choose_repository_property_bare', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(742007);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final AppNavigation navigation = await openStackedFilePage(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );
      final Repository picked = pickOne(random, page.$1.project.repositories);
      pickRepository(tester, picked.address);

      final ProjectFilesRoute route =
          navigation.currentRoute as ProjectFilesRoute;
      expect(route.repositoryAddress, picked.address);
      expect(route.branch, isNull);
      expect(route.preferredRunnerId, isNull);
    }
  });

  testWidgets(
    'test_repository_file_screen_choose_repository_property_project',
    (WidgetTester tester) async {
      final Random random = seededRandom(742008);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final FilePage page = randomFilePage(random);
        final AppNavigation navigation = await openStackedFilePage(
          tester,
          page: page,
          size: randomLargeScreenSize(random),
        );
        pickRepository(tester, page.$2.filesRoute.repositoryAddress);

        final ProjectFilesRoute route =
            navigation.currentRoute as ProjectFilesRoute;
        expect(route.projectId, page.$2.filesRoute.projectId);
        expect(route.repositoryAddress, page.$2.filesRoute.repositoryAddress);
      }
    },
  );

  testWidgets('test_repository_file_screen_choose_repository_property_menu', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(742009);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final Repository picked = pickOne(random, page.$1.project.repositories);
      if (picked.address == page.$2.filesRoute.repositoryAddress) {
        continue;
      }
      final AppNavigation navigation = await openStackedFilePage(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );
      await choosePickerOption(
        tester,
        label: repositoryPickerLabel,
        option: describeRepositoryPath(picked.address),
      );

      final ProjectFilesRoute route =
          navigation.currentRoute as ProjectFilesRoute;
      expect(route.repositoryAddress, picked.address);
    }
  });

  testWidgets('test_repository_file_screen_choose_branch_property_runner', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(742010);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final AppNavigation navigation = await openStackedFilePage(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );
      final String branch = pickOne(random, listBranchesOf(page.$1));
      pickBranch(tester, branch);

      expect(
        navigation.currentRoute,
        ProjectFilesRoute(
          projectId: scenarioProjectId,
          repositoryAddress: page.$2.filesRoute.repositoryAddress,
          branch: branch,
          preferredRunnerId: page.$2.source.runnerId,
        ),
      );
    }
  });

  testWidgets('test_repository_file_screen_choose_branch_property_wins', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(742011);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final AppNavigation navigation = await openStackedFilePage(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );
      final String branch = pickOne(random, listBranchesOf(page.$1));
      pickBranch(tester, branch);

      final ProjectFilesRoute route =
          navigation.currentRoute as ProjectFilesRoute;
      expect(route.branch, branch);
      expect(navigation.routes.length, 2);
    }
  });

  testWidgets('test_repository_file_screen_choose_branch_property_menu', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(742012);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomPlainBranchFilePage(random);
      final AppNavigation navigation = await openStackedFilePage(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );
      final String other = pickOne(random, <String>[
        for (final String branch in plainBranches)
          if (branch != page.$2.branch) branch,
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

  testWidgets('test_repository_file_screen_open_file_property_replaces', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(742013);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final AppNavigation navigation = await openStackedFilePage(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );
      final String path = randomHostileText(random);
      tester.widget<FileTreeView>(find.byType(FileTreeView)).onOpenFile(path);

      final RepositoryFileRoute route =
          navigation.currentRoute as RepositoryFileRoute;
      expect(navigation.routes.length, 3);
      expect(route.path, path);
      expect(route.branch, page.$2.branch);
      expect(route.filesRoute, page.$2.filesRoute);
      expect(identical(route.source, page.$2.source), isTrue);
    }
  });

  testWidgets('test_repository_file_screen_open_file_property_row_tap', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(742014);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final AppNavigation navigation = await openStackedFilePage(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );
      final Finder rootFiles = find.byWidgetPredicate(
        (Widget widget) =>
            widget is FileTreeRow &&
            widget.depth == 0 &&
            widget.folderState == FolderState.notAFolder,
      );
      if (rootFiles.evaluate().isEmpty) {
        continue;
      }
      final FileTreeRow row = tester.widget(rootFiles.last);
      await tester.ensureVisible(rootFiles.last);
      await tester.tap(rootFiles.last);
      await settleFilesScreen(tester);

      final RepositoryFileRoute route =
          navigation.currentRoute as RepositoryFileRoute;
      expect(route.path, row.name);
      expect(navigation.routes.length, 3);
    }
  });

  testWidgets('test_repository_file_screen_open_file_property_last_wins', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(742015);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final AppNavigation navigation = await openStackedFilePage(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );
      final List<String> paths = <String>[
        randomHostileText(random),
        randomHostileText(random),
        randomHostileText(random),
      ];
      for (final String path in paths) {
        tester
            .widget<FileTreeView>(find.byType(FileTreeView))
            .onOpenFile(path);
      }

      final RepositoryFileRoute route =
          navigation.currentRoute as RepositoryFileRoute;
      expect(route.path, paths.last);
      expect(navigation.routes.length, 3);
    }
  });
}
