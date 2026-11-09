import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/files/file_tree_controller.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/screens/files/files_page_parts.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'files_screen_scenarios.dart';
import 'project_files_screen_steps.dart';

const String _readOnlySummary = 'Read only';
const int _largestClosingDelay = 6;

void _ignoreChange() {}

void main() {
  testWidgets('test_project_files_screen_init_state_property_opens_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(735007);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final ScreenFileRepository files = scenario.buildFileRepository();
      await pumpFilesScreen(
        tester,
        size: randomScreenSize(random),
        screen: buildProjectFilesScreenFor(scenario, files),
      );

      expect(files.countAsked(FileOperation.open), 1);
      expect(files.preferredRunners, <Object?>[
        scenario.route.preferredRunnerId,
      ]);
    }
  });

  testWidgets('test_project_files_screen_init_state_property_asks_at_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(735008);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final ScreenFileRepository files = scenario.buildFileRepository();
      files.heldOperations.add(FileOperation.open);
      final Size size = randomScreenSize(random);
      useViewSize(tester, size);
      await tester.pumpWidget(
        wrapInApp(
          buildProjectFilesScreenFor(scenario, files),
          platform: platformMeantByWidth(size.width),
        ),
      );

      expect(files.askedOperations, <FileOperation>[FileOperation.open]);
      files.releaseHeldAnswers();
      await settleFilesScreen(tester);
    }
  });

  testWidgets(
    'test_project_files_screen_init_state_property_resize_no_reopen',
    (WidgetTester tester) async {
      final Random random = seededRandom(735009);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final FilesScreenScenario scenario = randomFilesScreenScenario(random);
        final ScreenFileRepository files = scenario.buildFileRepository();
        await pumpFilesScreen(
          tester,
          size: randomScreenSize(random),
          screen: buildProjectFilesScreenFor(scenario, files),
        );
        useViewSize(tester, randomScreenSize(random));
        await settleFilesScreen(tester);

        expect(files.countAsked(FileOperation.open), 1);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('test_project_files_screen_dispose_property_no_late_requests', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(735010);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final ScreenFileRepository files = scenario.buildFileRepository();
      final FileOperation held = pickOne(random, FileOperation.values);
      files.heldOperations.add(held);
      await pumpFilesScreen(
        tester,
        size: randomScreenSize(random),
        screen: buildProjectFilesScreenFor(scenario, files),
      );
      final int askedBeforeClosing = files.askedOperations.length;
      await closeFilesScreen(tester);
      files.releaseHeldAnswers();
      await settleFilesScreen(tester);

      expect(
        files.askedOperations.length,
        askedBeforeClosing,
        reason: '$held',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_project_files_screen_dispose_property_releases_the_tree', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(735011);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilePageScenario(random);
      await pumpFilesScreen(
        tester,
        size: randomScreenSize(random),
        screen: buildProjectFilesScreenFor(
          scenario,
          scenario.buildFileRepository(),
        ),
      );
      final FileTreeController tree = tester
          .widget<FileTreeView>(find.byType(FileTreeView))
          .controller;
      await closeFilesScreen(tester);

      expect(() => tree.addListener(_ignoreChange), throwsFlutterError);
    }
  });

  testWidgets('test_project_files_screen_dispose_property_any_moment_quiet', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(735012);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final Size size = randomScreenSize(random);
      useViewSize(tester, size);
      await tester.pumpWidget(
        wrapInApp(
          buildProjectFilesScreenFor(scenario, scenario.buildFileRepository()),
          platform: platformMeantByWidth(size.width),
        ),
      );
      for (int pump = random.nextInt(_largestClosingDelay); pump > 0; pump--) {
        await tester.pump();
      }
      await closeFilesScreen(tester);

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_project_files_screen_build_property_fits_every_size', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(735013);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final Size size = randomScreenSize(random);
      await pumpFilesScreen(
        tester,
        size: size,
        screen: buildProjectFilesScreenFor(
          scenario,
          scenario.buildFileRepository(),
        ),
      );

      expect(tester.takeException(), isNull, reason: '$size');
      expect(find.text(filesPageTitle), findsOneWidget);
      expect(find.text(_readOnlySummary), findsOneWidget);
    }
  });

  testWidgets('test_project_files_screen_build_property_back_names_project', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(735014);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final AppNavigation navigation = navigationToProjectFiles(scenario);
      await pumpFilesScreen(
        tester,
        size: randomScreenSize(random),
        screen: buildProjectFilesScreen(
          scenario: scenario,
          fileRepository: scenario.buildFileRepository(),
          navigation: navigation,
        ),
      );
      final PageHeader header = tester.widget(find.byType(PageHeader));
      header.backLink!.onPressed();

      expect(header.backLink!.label, scenario.project.name);
      expect(navigation.routes, <AppRoute>[
        const ProjectRoute(scenarioProjectId),
      ]);
    }
  });

  testWidgets('test_project_files_screen_build_property_problem_iff_refused', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(735015);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilesScreenScenario(random);
      final ScreenFileRepository files = scenario.buildFileRepository();
      final bool isRefused = random.nextBool();
      final String message = 'refused ${randomHostileText(random)}';
      if (isRefused) {
        files.refusals[FileOperation.open] = PeopleFacingRefusal(message);
      }
      await pumpFilesScreen(
        tester,
        size: randomScreenSize(random),
        screen: buildProjectFilesScreenFor(scenario, files),
      );

      final Iterable<FilesProblem> problems = tester.widgetList(
        find.byType(FilesProblem),
      );
      expect(problems.length, isRefused ? 1 : 0);
      if (isRefused) {
        expect(problems.single.text, message);
      }
    }
  });
}
