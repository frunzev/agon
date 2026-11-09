import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_tree_controller.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/theme/app_colors.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_property_inputs.dart';
import 'file_tree_view_inputs.dart';

void main() {
  testWidgets('test_file_tree_view_build_property_follows_the_controller', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100481);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final FileTreeController controller = await pumpRevealedFileTree(
        tester,
        random,
        repository: ScriptedFolderRepository(folders: tree),
        currentPath: null,
        onOpenFile: ignoreOpenedFile,
      );
      final List<String> folders = listVisibleFolderPaths(tree, <String>{});
      if (folders.isEmpty) {
        controller.dispose();
        continue;
      }
      final String folder = pickOne(random, folders);

      await controller.toggleFolder(folder);
      await tester.pump();

      expect(
        readShownTreePaths(tester),
        listVisiblePathsByModel(tree, <String>{folder}),
      );
      controller.dispose();
    }
  });

  testWidgets('test_file_tree_view_build_property_rows_fit_every_width', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100482);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FileTreeController controller = await pumpRevealedFileTree(
        tester,
        random,
        repository: ScriptedFolderRepository(
          folders: randomFolderTree(random),
        ),
        currentPath: null,
        onOpenFile: ignoreOpenedFile,
      );
      await openRandomFolders(tester, random);

      expect(tester.takeException(), isNull);
      final double width = tester.view.physicalSize.width;
      for (final Element row in find.byType(FileTreeRow).evaluate()) {
        final Rect area = tester.getRect(find.byWidget(row.widget));
        expect(area.left, greaterThanOrEqualTo(0));
        expect(area.right, lessThanOrEqualTo(width + 0.5));
      }
      controller.dispose();
    }
  });

  testWidgets('test_file_tree_view_build_property_unloaded_root_shows_no_'
      'rows', (WidgetTester tester) async {
    final Random random = seededRandom(100483);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final FileTreeController controller = FileTreeController(
        fileRepository: ScriptedFolderRepository(folders: tree),
        location: sampleBranchLocation,
      );
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: FileTreeView(
          controller: controller,
          currentPath: null,
          onOpenFile: ignoreOpenedFile,
        ),
      );
      final int rowsBefore = find.byType(FileTreeRow).evaluate().length;

      await controller.revealFolders(const <String>[treeRootFolder]);
      await tester.pump();

      expect(rowsBefore, 0);
      expect(tester.takeException(), isNull);
      expect(
        readShownTreePaths(tester),
        listVisiblePathsByModel(tree, <String>{}),
      );
      controller.dispose();
    }
  });

  testWidgets('test_build_tree_property_one_row_per_visible_line', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100484);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final FileTreeController controller = await pumpRevealedFileTree(
        tester,
        random,
        repository: ScriptedFolderRepository(folders: tree),
        currentPath: null,
        onOpenFile: ignoreOpenedFile,
      );
      final Set<String> openFolders = await openRandomFolders(tester, random);

      final List<String> shown = readShownTreePaths(tester);

      expect(shown.length, listVisiblePathsByModel(tree, openFolders).length);
      expect(shown.toSet(), hasLength(shown.length));
      controller.dispose();
    }
  });

  testWidgets('test_build_tree_property_a_problem_sits_above_the_rows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100485);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final List<String> folders = listVisibleFolderPaths(tree, <String>{});
      if (folders.isEmpty) {
        continue;
      }
      final ScriptedFolderRepository repository = ScriptedFolderRepository(
        folders: tree,
      );
      final FileTreeController controller = await pumpRevealedFileTree(
        tester,
        random,
        repository: repository,
        currentPath: null,
        onOpenFile: ignoreOpenedFile,
      );
      final String folder = pickOne(random, folders);
      repository.refusedFolders.add(folder);

      await tapTreeRow(tester, folder);
      await tester.ensureVisible(find.text(describeListingRefusal(folder)));
      await tester.pump();

      final Rect problem = tester.getRect(
        find.text(describeListingRefusal(folder)),
      );
      final Rect firstRow = tester.getRect(find.byType(FileTreeRow).first);
      expect(problem.bottom, lessThanOrEqualTo(firstRow.top));
      controller.dispose();
    }
  });

  testWidgets('test_build_tree_property_tree_starts_with_a_top_line', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100486);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FileTreeController controller = await pumpRevealedFileTree(
        tester,
        random,
        repository: ScriptedFolderRepository(
          folders: randomFolderTree(random),
        ),
        currentPath: null,
        onOpenFile: ignoreOpenedFile,
      );

      final Container outer = tester.widget(
        find
            .descendant(
              of: find.byType(FileTreeView),
              matching: find.byType(Container),
            )
            .first,
      );
      final BoxDecoration decoration = outer.decoration! as BoxDecoration;
      final Border border = decoration.border! as Border;
      expect(border.top.color, AppColors.line);
      expect(border.top.width, greaterThan(0));
      expect(border.bottom, BorderSide.none);
      controller.dispose();
    }
  });
}
