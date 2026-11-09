import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/screens/files/files_page_parts.dart';
import 'package:agent_orchestration/screens/files/readme_section.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'files_screen_scenarios.dart';
import 'project_files_screen_steps.dart';

Map<FileOperation, Object> _refuseReading(String message) {
  return <FileOperation, Object>{
    FileOperation.read: PeopleFacingRefusal(message),
  };
}

void main() {
  testWidgets('test_project_files_screen_build_browser_property_small_'
      'layouts_never_read_the_readme', (WidgetTester tester) async {
    final Random random = seededRandom(1051401);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilePageScenario(random);
      final ScreenFileRepository files = await pumpProjectFilesScenario(
        tester,
        scenario: scenario,
        size: randomSmallScreenSize(random),
        navigation: navigationToProjectFiles(scenario),
        refusals: random.nextBool()
            ? _refuseReading('no ${randomHostileText(random)}')
            : const <FileOperation, Object>{},
      );

      expect(files.readPaths, isEmpty);
      expect(find.byType(FilesProblem), findsNothing);
      expect(find.byType(ReadmeSection), findsNothing);
      expect(find.byType(FileTreeView), findsOneWidget);
    }
  });

  testWidgets('test_project_files_screen_build_browser_property_readme_'
      'problem_stays_in_the_readme_column', (WidgetTester tester) async {
    final Random random = seededRandom(1051402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilePageScenario(random);
      final String message = 'readme ${randomHostileText(random)}';
      await pumpProjectFilesScenario(
        tester,
        scenario: scenario,
        size: randomLargeScreenSize(random),
        navigation: navigationToProjectFiles(scenario),
        refusals: _refuseReading(message),
      );

      final bool hasReadme = findRootReadmePath(scenario) != null;
      final Finder problemInColumn = find.descendant(
        of: find.byType(SplitLayout),
        matching: find.byType(FilesProblem),
      );
      expect(
        find.byType(FilesProblem),
        hasReadme ? findsOneWidget : findsNothing,
      );
      expect(problemInColumn, hasReadme ? findsOneWidget : findsNothing);
      if (hasReadme) {
        final FilesProblem problem = tester.widget(find.byType(FilesProblem));
        expect(problem.text, message);
      }
    }
  });

  testWidgets('test_project_files_screen_build_browser_property_widening_'
      'reads_the_readme_once', (WidgetTester tester) async {
    final Random random = seededRandom(1051403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilePageScenario(random);
      final ScreenFileRepository files = await pumpProjectFilesAt(
        tester,
        scenario: scenario,
        size: randomSmallScreenSize(random),
      );
      expect(files.readPaths, isEmpty);

      useViewSize(tester, randomLargeScreenSize(random));
      await settleFilesScreen(tester);
      useViewSize(tester, randomLargeScreenSize(random));
      await settleFilesScreen(tester);

      final String? readmePath = findRootReadmePath(scenario);
      expect(
        files.readPaths,
        readmePath == null ? isEmpty : <String>[readmePath],
      );
      expect(
        find.byType(ReadmeSection),
        readmePath == null ? findsNothing : findsOneWidget,
      );
    }
  });

  testWidgets('test_project_files_screen_build_browser_property_narrowing_'
      'hides_the_readme_problem', (WidgetTester tester) async {
    final Random random = seededRandom(1051404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilePageScenario(random);
      await pumpProjectFilesScenario(
        tester,
        scenario: scenario,
        size: randomLargeScreenSize(random),
        navigation: navigationToProjectFiles(scenario),
        refusals: _refuseReading('refused $i'),
      );

      useViewSize(tester, randomSmallScreenSize(random));
      await settleFilesScreen(tester);

      expect(find.byType(FilesProblem), findsNothing);
      expect(find.byType(FileTreeView), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
