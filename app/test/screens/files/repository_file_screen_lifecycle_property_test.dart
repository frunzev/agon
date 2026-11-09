import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_tree_controller.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'repository_file_screen_steps.dart';

const int _largestClosingDelay = 6;

void _ignoreChange() {}

void main() {
  testWidgets('test_repository_file_screen_init_state_property_reads_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(740009);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final ScreenFileRepository files = page.$1.buildFileRepository();
      await pumpFilesScreen(
        tester,
        size: randomScreenSize(random),
        screen: buildFilePageScreenFor(page, files),
      );

      expect(files.readPaths, <String>[page.$2.path]);
    }
  });

  testWidgets('test_repository_file_screen_init_state_property_asks_at_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(740010);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final ScreenFileRepository files = page.$1.buildFileRepository();
      files.heldOperations.addAll(FileOperation.values);
      final Size size = randomScreenSize(random);
      useViewSize(tester, size);
      await tester.pumpWidget(
        wrapInApp(
          buildFilePageScreenFor(page, files),
          platform: platformMeantByWidth(size.width),
        ),
      );

      expect(files.askedOperations.first, FileOperation.read);
      files.releaseHeldAnswers();
      await settleFilesScreen(tester);
    }
  });

  testWidgets('test_repository_file_screen_init_state_property_no_reread', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(740011);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final ScreenFileRepository files = page.$1.buildFileRepository();
      await pumpFilesScreen(
        tester,
        size: randomScreenSize(random),
        screen: buildFilePageScreenFor(page, files),
      );
      useViewSize(tester, randomScreenSize(random));
      await settleFilesScreen(tester);

      expect(files.countAsked(FileOperation.read), 1);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_repository_file_screen_dispose_property_no_late_asks', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(740012);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final ScreenFileRepository files = page.$1.buildFileRepository();
      files.heldOperations.add(pickOne(random, FileOperation.values));
      await pumpFilesScreen(
        tester,
        size: randomLargeScreenSize(random),
        screen: buildFilePageScreenFor(page, files),
      );
      final int askedBeforeClosing = files.askedOperations.length;
      await closeFilesScreen(tester);
      files.releaseHeldAnswers();
      await settleFilesScreen(tester);

      expect(files.askedOperations.length, askedBeforeClosing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_repository_file_screen_dispose_property_tree_released', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(740013);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      await pumpFilesScreen(
        tester,
        size: randomLargeScreenSize(random),
        screen: buildFilePageScreenFor(page, page.$1.buildFileRepository()),
      );
      final FileTreeController tree = tester
          .widget<FileTreeView>(find.byType(FileTreeView))
          .controller;
      await closeFilesScreen(tester);

      expect(() => tree.addListener(_ignoreChange), throwsFlutterError);
    }
  });

  testWidgets('test_repository_file_screen_dispose_property_any_moment', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(740014);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final Size size = randomScreenSize(random);
      useViewSize(tester, size);
      await tester.pumpWidget(
        wrapInApp(
          buildFilePageScreenFor(page, page.$1.buildFileRepository()),
          platform: platformMeantByWidth(size.width),
        ),
      );
      final int delay = random.nextInt(_largestClosingDelay);
      for (int pump = 0; pump < delay; pump += 1) {
        await tester.pump();
      }
      await closeFilesScreen(tester);

      expect(tester.takeException(), isNull);
    }
  });
}
