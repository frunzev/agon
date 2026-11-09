import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/files/file_content_view.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/screens/files/files_page_parts.dart';
import 'package:agent_orchestration/screens/files/repository_file_paths.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'repository_file_screen_steps.dart';

void main() {
  testWidgets('test_repository_file_screen_did_change_dependencies_property_'
      'large_lists_ancestors', (WidgetTester tester) async {
    final Random random = seededRandom(741001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final ScreenFileRepository files = await pumpFilePageAt(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );

      final List<String> ancestors = listAncestorFolders(page.$2.path);
      expect(files.listedFolders.toSet().length, files.listedFolders.length);
      expect(files.listedFolders.first, '');
      for (final String folder in files.listedFolders) {
        expect(ancestors, contains(folder));
      }
      if (predictReadFile(page.$1, page.$2.path) != null) {
        expect(files.listedFolders, ancestors);
      }
    }
  });

  testWidgets('test_repository_file_screen_did_change_dependencies_property_'
      'small_lists_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(741002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScreenFileRepository files = await pumpFilePageAt(
        tester,
        page: randomFilePage(random),
        size: randomSmallScreenSize(random),
      );

      expect(files.listedFolders, isEmpty);
      expect(find.byType(FileTreeView), findsNothing);
    }
  });

  testWidgets('test_repository_file_screen_did_change_dependencies_property_'
      'growing_lists_once', (WidgetTester tester) async {
    final Random random = seededRandom(741003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final ScreenFileRepository files = await pumpFilePageAt(
        tester,
        page: page,
        size: randomSmallScreenSize(random),
      );
      for (int step = 0; step < 3; step += 1) {
        useViewSize(tester, randomLargeScreenSize(random));
        await settleFilesScreen(tester);
        useViewSize(tester, randomSmallScreenSize(random));
        await settleFilesScreen(tester);
      }

      expect(files.listedFolders, isNotEmpty);
      expect(files.listedFolders.toSet().length, files.listedFolders.length);
    }
  });

  testWidgets('test_repository_file_screen_read_file_property_shows_answer', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(741004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      await pumpFilePageAt(tester, page: page, size: randomScreenSize(random));

      final FakeRepositoryFile? expected = predictReadFile(
        page.$1,
        page.$2.path,
      );
      final Iterable<FileContentView> views = tester.widgetList(
        find.byType(FileContentView),
      );
      expect(views.length, expected == null ? 0 : 1);
      if (expected != null) {
        expect(views.single.file.path, expected.path);
        expect(identical(views.single.file.preview, expected.preview), isTrue);
      }
    }
  });

  testWidgets('test_repository_file_screen_read_file_property_refusal_words', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(741005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final String message = 'cannot ${randomHostileText(random)}';
      await pumpFilePage(
        tester,
        scenario: page.$1,
        route: page.$2,
        size: randomSmallScreenSize(random),
        navigation: navigationToFilePage(page.$1, page.$2),
        refusals: <FileOperation, Object>{
          FileOperation.read: PeopleFacingRefusal(message),
        },
      );

      final FilesProblem problem = tester.widget(find.byType(FilesProblem));
      expect(problem.text, message);
      expect(find.byType(FileContentView), findsNothing);
    }
  });

  testWidgets('test_repository_file_screen_read_file_property_unreadable', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(741006);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      await pumpFilePageAt(
        tester,
        page: page,
        size: randomSmallScreenSize(random),
      );

      final bool isReadable = predictReadFile(page.$1, page.$2.path) != null;
      expect(find.byType(FilesProblem).evaluate().length, isReadable ? 0 : 1);
    }
  });
}
