import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
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

const List<String> _foldersToOpen = <String>['', 'docs', 'src', 'f'];

void main() {
  testWidgets('test_read_readme_once_listed_property_reads_at_most_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetup(random);
      await pumpReadmeColumn(tester, setup.tree);
      await revealRootFolder(tester, setup.tree);

      for (int step = 0; step < random.nextInt(6); step += 1) {
        unawaited(setup.tree.toggleFolder(pickOne(random, _foldersToOpen)));
        await settleFilesScreen(tester);
      }

      expect(setup.files.readPaths, listExpectedReadmeReads(setup.scenario));
    }
  });

  testWidgets('test_read_readme_once_listed_property_failed_listing_reads_'
      'nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1051602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetup(random);
      setup.files.refusals[FileOperation.list] = PeopleFacingRefusal('x$i');
      await pumpReadmeColumn(tester, setup.tree);
      await revealRootFolder(tester, setup.tree);

      expect(setup.files.readPaths, isEmpty);
      expect(find.byType(FilesProblem), findsNothing);
    }
  });

  testWidgets('test_read_readme_once_listed_property_only_the_root_readme', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetup(random);
      await pumpReadmeColumn(tester, setup.tree);
      await revealRootFolder(tester, setup.tree);

      for (final String path in setup.files.readPaths) {
        expect(path, isNot(contains('/')));
        expect(path.toLowerCase(), 'readme.md');
      }
    }
  });

  testWidgets('test_read_readme_property_asks_the_tree_location', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetup(random);
      await pumpReadmeColumn(tester, setup.tree);
      await revealRootFolder(tester, setup.tree);

      for (final RepositoryBranchLocation location
          in setup.files.askedLocations) {
        expect(location, same(setup.tree.location));
      }
    }
  });

  testWidgets('test_read_readme_property_refusal_words_kept_verbatim', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetup(random);
      if (findRootReadmePath(setup.scenario) == null) {
        continue;
      }
      final String message = 'r${randomHostileText(random)}';
      setup.files.refusals[FileOperation.read] = PeopleFacingRefusal(message);
      await pumpReadmeColumn(tester, setup.tree);
      await revealRootFolder(tester, setup.tree);

      final FilesProblem problem = tester.widget(find.byType(FilesProblem));
      expect(problem.text, message);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_read_readme_property_late_answer_after_closing_is_'
      'dropped', (WidgetTester tester) async {
    final Random random = seededRandom(1051606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetup(random);
      setup.files.heldOperations.add(FileOperation.read);
      await pumpReadmeColumn(tester, setup.tree);
      await revealRootFolder(tester, setup.tree);

      await tester.pumpWidget(const SizedBox.shrink());
      setup.files.releaseHeldAnswers();
      await settleFilesScreen(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(ReadmeSection), findsNothing);
    }
  });

  testWidgets('test_readme_column_did_update_widget_property_new_tree_new_'
      'readme', (WidgetTester tester) async {
    final Random random = seededRandom(1051607);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup first = randomReadmeSetup(random);
      final ReadmeSetup second = randomReadmeSetup(random);
      await pumpReadmeColumn(tester, first.tree);
      await pumpReadmeColumn(tester, second.tree);
      await revealRootFolder(tester, first.tree);
      await revealRootFolder(tester, second.tree);

      final String? readmePath = findRootReadmePath(second.scenario);
      final Iterable<ReadmeSection> sections = tester.widgetList(
        find.byType(ReadmeSection),
      );
      expect(
        sections.map((ReadmeSection shown) => shown.readme.path),
        <String>[?readmePath],
      );
      expect(first.files.readPaths, isEmpty);
      expect(second.files.readPaths, listExpectedReadmeReads(second.scenario));
    }
  });

  testWidgets('test_readme_column_did_update_widget_property_old_answer_'
      'is_ignored', (WidgetTester tester) async {
    final Random random = seededRandom(1051608);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup first = randomReadmeSetup(random);
      final ReadmeSetup second = randomReadmeSetup(random);
      first.files.heldOperations.add(FileOperation.read);
      first.files.refusals[FileOperation.read] = PeopleFacingRefusal('old');
      await pumpReadmeColumn(tester, first.tree);
      await revealRootFolder(tester, first.tree);

      await pumpReadmeColumn(tester, second.tree);
      first.files.releaseHeldAnswers();
      await settleFilesScreen(tester);

      expect(find.byType(FilesProblem), findsNothing);
      expect(find.byType(ReadmeSection), findsNothing);
    }
  });

  testWidgets('test_readme_column_did_update_widget_property_same_tree_'
      'keeps_the_readme', (WidgetTester tester) async {
    final Random random = seededRandom(1051609);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetup(random);
      await pumpReadmeColumn(tester, setup.tree);
      await revealRootFolder(tester, setup.tree);

      await pumpScrollableAtWidth(
        tester,
        width: desktopWidth,
        child: ReadmeColumn(
          tree: setup.tree,
          repositoryPath: randomHostileText(random),
        ),
      );
      await settleFilesScreen(tester);

      expect(setup.files.readPaths, listExpectedReadmeReads(setup.scenario));
      expect(
        find.byType(ReadmeSection),
        setup.files.readPaths.isEmpty ? findsNothing : findsOneWidget,
      );
    }
  });

  testWidgets('test_readme_column_dispose_property_stops_listening', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051610);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetup(random);
      await pumpReadmeColumn(tester, setup.tree);

      await tester.pumpWidget(const SizedBox.shrink());
      await revealRootFolder(tester, setup.tree);

      expect(setup.files.readPaths, isEmpty);
      expect(setup.tree.entriesOf(readmeRootFolder), isNotNull);
    }
  });

  testWidgets('test_readme_column_create_state_property_each_column_reads_'
      'its_own_tree', (WidgetTester tester) async {
    final Random random = seededRandom(1051611);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup first = randomReadmeSetup(random);
      final ReadmeSetup second = randomReadmeSetup(random);
      await pumpScrollableAtWidth(
        tester,
        width: desktopWidth,
        child: Column(
          children: <Widget>[
            ReadmeColumn(tree: first.tree, repositoryPath: 'a'),
            ReadmeColumn(tree: second.tree, repositoryPath: 'b'),
          ],
        ),
      );
      await revealRootFolder(tester, first.tree);
      await revealRootFolder(tester, second.tree);

      expect(first.files.readPaths, listExpectedReadmeReads(first.scenario));
      expect(second.files.readPaths, listExpectedReadmeReads(second.scenario));
    }
  });

  testWidgets('test_readme_column_init_state_property_starts_listening', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051612);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReadmeSetup setup = randomReadmeSetup(random);

      await pumpReadmeColumn(tester, setup.tree);
      expect(setup.files.askedOperations, isEmpty);
      await revealRootFolder(tester, setup.tree);

      expect(setup.files.readPaths, listExpectedReadmeReads(setup.scenario));
    }
  });
}
