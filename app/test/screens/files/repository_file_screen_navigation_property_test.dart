import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/files/path_breadcrumb.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/random_inputs.dart';
import 'files_screen_pumps.dart';
import 'files_screen_scenarios.dart';
import 'repository_file_screen_steps.dart';

void main() {
  testWidgets('test_repository_file_screen_return_to_files_property_pops', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(742001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final AppNavigation navigation = await openStackedFilePage(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );
      tester.widget<PathBreadcrumb>(find.byType(PathBreadcrumb)).onPressed();

      expect(navigation.routes, <AppRoute>[
        const ProjectRoute(scenarioProjectId),
        page.$1.route,
      ]);
    }
  });

  testWidgets('test_repository_file_screen_return_to_files_property_alone', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(742002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final AppNavigation navigation = await openFilePageThrough(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
        routes: <AppRoute>[const ProjectRoute(scenarioProjectId), page.$2],
      );
      tester.widget<PathBreadcrumb>(find.byType(PathBreadcrumb)).onPressed();

      expect(navigation.routes, <AppRoute>[
        const ProjectRoute(scenarioProjectId),
        page.$1.route,
      ]);
    }
  });

  testWidgets('test_repository_file_screen_return_to_files_property_tap', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(742003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final AppNavigation navigation = await openStackedFilePage(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );
      final Finder crumb = find.descendant(
        of: find.byType(PathBreadcrumb),
        matching: find.text(
          describeRepositoryPath(page.$2.filesRoute.repositoryAddress),
        ),
      );
      await tester.tap(crumb);
      await settleFilesScreen(tester);

      expect(navigation.currentRoute, page.$1.route);
      expect(navigation.routes.length, 2);
    }
  });

  testWidgets('test_repository_file_screen_show_other_files_property_leaves', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(742004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final AppNavigation navigation = await openStackedFilePage(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );
      pickBranch(tester, pickOne(random, listBranchesOf(page.$1)));

      expect(navigation.routes.length, 2);
      expect(navigation.routes.whereType<RepositoryFileRoute>(), isEmpty);
      expect(navigation.routes.first, const ProjectRoute(scenarioProjectId));
    }
  });

  testWidgets('test_repository_file_screen_show_other_files_property_alone', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(742005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final AppNavigation navigation = await openFilePageThrough(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
        routes: <AppRoute>[page.$2],
      );
      final Repository picked = pickOne(random, page.$1.project.repositories);
      pickRepository(tester, picked.address);

      expect(navigation.routes, <AppRoute>[
        ProjectFilesRoute(
          projectId: scenarioProjectId,
          repositoryAddress: picked.address,
        ),
      ]);
    }
  });

  testWidgets('test_repository_file_screen_show_other_files_property_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(742006);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final AppNavigation navigation = await openStackedFilePage(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );
      final Repository picked = pickOne(random, page.$1.project.repositories);
      pickRepository(tester, picked.address);

      expect(navigation.routes, <AppRoute>[
        const ProjectRoute(scenarioProjectId),
        ProjectFilesRoute(
          projectId: scenarioProjectId,
          repositoryAddress: picked.address,
        ),
      ]);
    }
  });
}
