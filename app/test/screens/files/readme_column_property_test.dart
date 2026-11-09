import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/files/files_page_parts.dart';
import 'package:agent_orchestration/screens/files/readme_column.dart';
import 'package:agent_orchestration/screens/files/readme_section.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'project_files_screen_steps.dart';
import 'readme_column_inputs.dart';

void main() {
  test('test_readme_column_new_property_keeps_tree_and_path', () {
    final Random random = seededRandom(1051501);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final ReadmeSetup setup = randomReadmeSetup(random);
      final String path = randomHostileText(random);
      final ReadmeColumn column = ReadmeColumn(
        tree: setup.tree,
        repositoryPath: path,
      );

      expect(column.tree, same(setup.tree));
      expect(column.repositoryPath, path);
      expect(column.key, isNull);
    }
  });

  test('test_readme_column_new_property_keeps_the_key', () {
    final Random random = seededRandom(1051502);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final ReadmeSetup setup = randomReadmeSetup(random);
      final Key key = ObjectKey(setup.tree);

      expect(
        ReadmeColumn(key: key, tree: setup.tree, repositoryPath: '').key,
        key,
      );
    }
  });

  testWidgets('test_readme_column_new_property_hostile_paths_render', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetup(random);
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: ReadmeColumn(
          tree: setup.tree,
          repositoryPath: randomHostileText(random),
        ),
      );
      await revealRootFolder(tester, setup.tree);

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_readme_column_build_property_empty_until_listed', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetup(random);
      await pumpReadmeColumn(tester, setup.tree);

      expect(find.byType(ReadmeSection), findsNothing);
      expect(find.byType(FilesProblem), findsNothing);
      expect(setup.files.readPaths, isEmpty);
    }
  });

  testWidgets('test_readme_column_build_property_shows_the_root_readme', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetup(random);
      await pumpReadmeColumn(tester, setup.tree);
      await revealRootFolder(tester, setup.tree);

      final String? readmePath = findRootReadmePath(setup.scenario);
      final Iterable<ReadmeSection> sections = tester.widgetList(
        find.byType(ReadmeSection),
      );
      expect(sections, hasLength(readmePath == null ? 0 : 1));
      if (readmePath != null) {
        expect(sections.single.readme.path, readmePath);
      }
    }
  });

  testWidgets('test_readme_column_build_property_problem_replaces_readme', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetup(random);
      final String message = 'r${randomHostileText(random)}';
      setup.files.refusals[FileOperation.read] = PeopleFacingRefusal(message);
      await pumpReadmeColumn(tester, setup.tree);
      await revealRootFolder(tester, setup.tree);

      final bool hasReadme = findRootReadmePath(setup.scenario) != null;
      expect(find.byType(ReadmeSection), findsNothing);
      expect(
        find.byType(FilesProblem),
        hasReadme ? findsOneWidget : findsNothing,
      );
      if (hasReadme) {
        expect(
          tester.widget<FilesProblem>(find.byType(FilesProblem)).text,
          message,
        );
      }
    }
  });

  testWidgets('test_readme_column_init_state_property_listed_tree_reads_'
      'at_once', (WidgetTester tester) async {
    final Random random = seededRandom(1051507);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetup(random);
      await revealRootFolder(tester, setup.tree);
      expect(setup.files.readPaths, isEmpty);
      await pumpReadmeColumn(tester, setup.tree);
      await settleFilesScreen(tester);

      final String? readmePath = findRootReadmePath(setup.scenario);
      expect(
        setup.files.readPaths,
        readmePath == null ? isEmpty : <String>[readmePath],
      );
    }
  });
}
