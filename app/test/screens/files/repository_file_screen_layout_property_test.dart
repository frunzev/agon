import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/files/file_content_view.dart';
import 'package:agent_orchestration/screens/files/file_pickers.dart';
import 'package:agent_orchestration/screens/files/file_source_status.dart';
import 'package:agent_orchestration/screens/files/file_text.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/screens/files/files_page_parts.dart';
import 'package:agent_orchestration/screens/files/path_breadcrumb.dart';
import 'package:agent_orchestration/screens/files/repository_file_paths.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';

import '../../support/random_inputs.dart';
import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'files_screen_scenarios.dart';
import 'repository_file_screen_steps.dart';

List<(String, TextFace)> _describeSegments(List<TextSegment> segments) {
  return <(String, TextFace)>[
    for (final TextSegment segment in segments) (segment.text, segment.face),
  ];
}

List<String> _listOptionValues(List<SelectEntry<String>> entries) {
  return <String>[
    for (final SelectEntry<String> entry in entries)
      if (entry is SelectOption<String>) entry.value,
  ];
}

void main() {
  testWidgets('test_repository_file_screen_build_property_title_is_the_name', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(741007);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      await pumpFilePageAt(tester, page: page, size: randomScreenSize(random));

      final PageHeader header = tester.widget(find.byType(PageHeader));
      expect(header.title, fileNameOf(page.$2.path));
      expect(header.backLink, isNull);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_repository_file_screen_build_property_breadcrumb_path', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(741008);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      await pumpFilePageAt(tester, page: page, size: randomScreenSize(random));

      final PathBreadcrumb crumbs = tester.widget(find.byType(PathBreadcrumb));
      final String repositoryPath = describeRepositoryPath(
        page.$2.filesRoute.repositoryAddress,
      );
      expect(crumbs.labels, describeBreadcrumb(repositoryPath, page.$2.path));
    }
  });

  testWidgets('test_repository_file_screen_build_property_summary_branch', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(741009);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      await pumpFilePageAt(tester, page: page, size: randomScreenSize(random));

      final PageHeader header = tester.widget(find.byType(PageHeader));
      final FakeRepositoryFile? read = predictReadFile(page.$1, page.$2.path);
      final List<TextSegment> expected = read == null
          ? <TextSegment>[TextSegment.monospace(page.$2.branch)]
          : describeFileSummary(
              branch: page.$2.branch,
              file: RepositoryFile(
                path: read.path,
                size: read.size,
                preview: read.preview,
              ),
            );
      expect(_describeSegments(header.summary), _describeSegments(expected));
    }
  });

  testWidgets('test_repository_file_screen_build_body_property_small_alone', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(741010);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpFilePageAt(
        tester,
        page: randomFilePage(random),
        size: randomSmallScreenSize(random),
      );

      expect(find.byType(SplitLayout), findsNothing);
      expect(find.byType(RepositoryPicker), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_repository_file_screen_build_body_property_large_split', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(741011);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      await pumpFilePageAt(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );

      final bool isReadable = predictReadFile(page.$1, page.$2.path) != null;
      final Finder split = find.byType(SplitLayout);
      expect(split, findsOneWidget);
      expect(
        find.descendant(of: split, matching: find.byType(FileTreeView)),
        findsOneWidget,
      );
      expect(
        find.byType(FileContentView).evaluate().length,
        isReadable ? 1 : 0,
      );
    }
  });

  testWidgets('test_repository_file_screen_build_body_property_waits', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(741012);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      final ScreenFileRepository files = page.$1.buildFileRepository();
      files.heldOperations.add(FileOperation.read);
      await pumpFilesScreen(
        tester,
        size: randomScreenSize(random),
        screen: buildRepositoryFileScreen(
          scenario: page.$1,
          route: page.$2,
          fileRepository: files,
          navigation: navigationToFilePage(page.$1, page.$2),
        ),
      );

      final int treeProblemCount = find
          .descendant(
            of: find.byType(FileTreeView),
            matching: find.byType(FilesProblem),
          )
          .evaluate()
          .length;
      expect(find.byType(FileContentView), findsNothing);
      expect(find.byType(FilesProblem).evaluate().length, treeProblemCount);
      files.releaseHeldAnswers();
      await settleFilesScreen(tester);
    }
  });

  testWidgets('test_repository_file_screen_build_tree_section_property_'
      'repositories', (WidgetTester tester) async {
    final Random random = seededRandom(741013);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      await pumpFilePageAt(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );

      final RepositoryPicker picker = tester.widget(
        find.byType(RepositoryPicker),
      );
      expect(picker.repositories, page.$1.project.repositories);
      expect(picker.chosenAddress, page.$2.filesRoute.repositoryAddress);
    }
  });

  testWidgets('test_repository_file_screen_build_tree_section_property_'
      'branches', (WidgetTester tester) async {
    final Random random = seededRandom(741014);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      await pumpFilePageAt(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );

      final BranchPicker picker = tester.widget(find.byType(BranchPicker));
      expect(picker.chosenBranch, page.$2.branch);
      expect(_listOptionValues(picker.entries), listBranchesOf(page.$1));
    }
  });

  testWidgets('test_repository_file_screen_build_tree_section_property_'
      'marks_current', (WidgetTester tester) async {
    final Random random = seededRandom(741015);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilePage page = randomFilePage(random);
      await pumpFilePageAt(
        tester,
        page: page,
        size: randomLargeScreenSize(random),
      );

      final FileTreeView tree = tester.widget(find.byType(FileTreeView));
      final FileSourceStatus status = tester.widget(
        find.byType(FileSourceStatus),
      );
      expect(tree.currentPath, page.$2.path);
      expect(status.runnerName, page.$2.source.runnerName);
    }
  });
}
