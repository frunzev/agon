import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/files/files_page_parts.dart';
import 'package:agent_orchestration/screens/files/readme_column.dart';
import 'package:agent_orchestration/screens/files/readme_section.dart';

import '../../support/random_inputs.dart';
import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'project_files_screen_steps.dart';
import 'readme_column_inputs.dart';

void main() {
  testWidgets('test_readme_column_init_state_property_waits_for_the_root', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetupWithReadme(random);
      setup.files.heldOperations.add(FileOperation.list);
      await pumpReadmeColumn(tester, setup.tree);
      unawaited(setup.tree.revealFolders(const <String>[readmeRootFolder]));
      await settleFilesScreen(tester);
      expect(setup.files.readPaths, isEmpty);

      setup.files.releaseHeldAnswers();
      await settleFilesScreen(tester);

      expect(setup.files.readPaths, hasLength(1));
    }
  });

  testWidgets('test_readme_column_dispose_property_tree_keeps_working', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetupWithReadme(random);
      await pumpReadmeColumn(tester, setup.tree);
      await tester.pumpWidget(const SizedBox.shrink());

      await revealRootFolder(tester, setup.tree);

      expect(setup.tree.entriesOf(readmeRootFolder), isNotNull);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_readme_column_dispose_property_held_refusal_is_dropped', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetupWithReadme(random);
      setup.files.heldOperations.add(FileOperation.read);
      setup.files.refusals[FileOperation.read] = PeopleFacingRefusal('late');
      await pumpReadmeColumn(tester, setup.tree);
      await revealRootFolder(tester, setup.tree);

      await tester.pumpWidget(const SizedBox.shrink());
      setup.files.releaseHeldAnswers();
      await settleFilesScreen(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(FilesProblem), findsNothing);
    }
  });

  test('test_readme_column_create_state_property_fresh_state_each_call', () {
    final Random random = seededRandom(1051704);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final ReadmeSetup setup = randomReadmeSetupWithReadme(random);
      final ReadmeColumn column = ReadmeColumn(
        tree: setup.tree,
        repositoryPath: 'acme/app',
      );

      expect(identical(column.createState(), column.createState()), isFalse);
    }
  });

  testWidgets('test_readme_column_create_state_property_remount_reads_'
      'again', (WidgetTester tester) async {
    final Random random = seededRandom(1051705);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetupWithReadme(random);
      await pumpReadmeColumn(tester, setup.tree);
      await revealRootFolder(tester, setup.tree);

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpReadmeColumn(tester, setup.tree);
      await settleFilesScreen(tester);

      expect(setup.files.readPaths, hasLength(2));
      expect(find.byType(ReadmeSection), findsOneWidget);
    }
  });

  testWidgets('test_is_still_showing_property_closed_column_takes_no_'
      'readme', (WidgetTester tester) async {
    final Random random = seededRandom(1051706);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetupWithReadme(random);
      setup.files.heldOperations.add(FileOperation.read);
      await pumpReadmeColumn(tester, setup.tree);
      await revealRootFolder(tester, setup.tree);

      await tester.pumpWidget(const SizedBox.shrink());
      setup.files.releaseHeldAnswers();
      await settleFilesScreen(tester);

      expect(find.byType(ReadmeSection), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_is_still_showing_property_swapped_tree_takes_no_old_'
      'readme', (WidgetTester tester) async {
    final Random random = seededRandom(1051707);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup first = randomReadmeSetupWithReadme(random);
      final ReadmeSetup second = randomReadmeSetupWithReadme(random);
      first.files.heldOperations.add(FileOperation.read);
      second.files.heldOperations.add(FileOperation.list);
      await pumpReadmeColumn(tester, first.tree);
      await revealRootFolder(tester, first.tree);

      await pumpReadmeColumn(tester, second.tree);
      first.files.releaseHeldAnswers();
      await settleFilesScreen(tester);

      expect(find.byType(ReadmeSection), findsNothing);
    }
  });

  testWidgets('test_is_still_showing_property_current_tree_takes_its_'
      'readme', (WidgetTester tester) async {
    final Random random = seededRandom(1051708);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetupWithReadme(random);
      setup.files.heldOperations.add(FileOperation.read);
      await pumpReadmeColumn(tester, setup.tree);
      await revealRootFolder(tester, setup.tree);
      expect(find.byType(ReadmeSection), findsNothing);

      setup.files.releaseHeldAnswers();
      await settleFilesScreen(tester);

      final ReadmeSection section = tester.widget(find.byType(ReadmeSection));
      expect(section.readme.path, findRootReadmePath(setup.scenario));
    }
  });
}
