import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/repository_file_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'files_screen_scenarios.dart';
import 'repository_file_screen_steps.dart';

const String _designCopyPathLabel = 'Copy path';
void main() {
  test('test_copy_path_label_property_matches_the_design', () {
    expect(copyPathLabel, _designCopyPathLabel);
    expect(copyPathLabel.trim(), copyPathLabel);
  });

  testWidgets('test_copy_path_label_property_is_the_only_page_action', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(740001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final (FilesScreenScenario scenario, RepositoryFileRoute route) =
          randomFilePage(random);
      await pumpFilePageAt(
        tester,
        page: (scenario, route),
        size: randomScreenSize(random),
      );

      final PageHeader header = tester.widget(find.byType(PageHeader));
      expect(header.actions.length, 1);
      expect((header.actions.single as AppButton).label, copyPathLabel);
    }
  });

  testWidgets('test_copy_path_label_property_copies_the_exact_path', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(740002);
    final List<Object?> copied = recordClipboardTexts(tester);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final (FilesScreenScenario scenario, RepositoryFileRoute route) =
          randomFilePage(random);
      await pumpFilePageAt(
        tester,
        page: (scenario, route),
        size: randomScreenSize(random),
      );
      await tester.tap(find.text(copyPathLabel));
      await settleFilesScreen(tester);

      expect(copied.last, route.path);
      expect(copied.length, i + 1);
    }
  });

  test('test_repository_file_screen_new_property_keeps_dependencies', () {
    final Random random = seededRandom(740003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final (FilesScreenScenario scenario, RepositoryFileRoute route) =
          randomFilePage(random);
      final FixedProjectRepository projects = FixedProjectRepository(
        scenario.project,
      );
      final ScreenFileRepository files = scenario.buildFileRepository();
      final AppNavigation navigation = navigationToFilePage(scenario, route);
      final RepositoryFileScreen screen = RepositoryFileScreen(
        route: route,
        projectRepository: projects,
        fileRepository: files,
        navigation: navigation,
      );

      expect(identical(screen.route, route), isTrue);
      expect(identical(screen.projectRepository, projects), isTrue);
      expect(identical(screen.fileRepository, files), isTrue);
      expect(identical(screen.navigation, navigation), isTrue);
    }
  });

  test('test_repository_file_screen_new_property_keeps_the_key', () {
    final Random random = seededRandom(740004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final (FilesScreenScenario scenario, RepositoryFileRoute route) =
          randomFilePage(random);
      final Key key = ValueKey<String>(randomHostileText(random));
      final RepositoryFileScreen screen = RepositoryFileScreen(
        key: key,
        route: route,
        projectRepository: FixedProjectRepository(scenario.project),
        fileRepository: scenario.buildFileRepository(),
        navigation: navigationToFilePage(scenario, route),
      );

      expect(screen.key, key);
    }
  });

  test('test_repository_file_screen_new_property_asks_nothing_yet', () {
    final Random random = seededRandom(740005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final ScreenFileRepository files = page.$1.buildFileRepository();
      final RepositoryFileScreen screen = buildFilePageScreenFor(page, files);

      expect(files.askedOperations, isEmpty);
      expect(screen.navigation.currentRoute, page.$2);
    }
  });

  test('test_repository_file_screen_create_state_property_fresh_and_idle', () {
    final Random random = seededRandom(740006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final ScreenFileRepository files = page.$1.buildFileRepository();
      final RepositoryFileScreen screen = buildFilePageScreenFor(page, files);
      final State<RepositoryFileScreen> first = screen.createState();
      final State<RepositoryFileScreen> second = screen.createState();

      expect(identical(first, second), isFalse);
      expect(first.mounted, isFalse);
      expect(files.askedOperations, isEmpty);
    }
  });

  testWidgets('test_repository_file_screen_create_state_property_serves_it', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(740007);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final RepositoryFileScreen screen = buildFilePageScreenFor(
        page,
        page.$1.buildFileRepository(),
      );
      await pumpFilesScreen(
        tester,
        size: randomScreenSize(random),
        screen: screen,
      );

      final State<RepositoryFileScreen> state = tester.state(
        find.byType(RepositoryFileScreen),
      );
      expect(identical(state.widget, screen), isTrue);
    }
  });

  testWidgets('test_repository_file_screen_create_state_property_per_mount', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(740008);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final ScreenFileRepository files = page.$1.buildFileRepository();
      await pumpFilesScreen(
        tester,
        size: randomScreenSize(random),
        screen: buildFilePageScreenFor(page, files),
      );
      await closeFilesScreen(tester);
      await pumpFilesScreen(
        tester,
        size: randomScreenSize(random),
        screen: buildFilePageScreenFor(page, files),
      );

      expect(files.countAsked(FileOperation.read), 2);
    }
  });
}
