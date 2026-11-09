import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_tree_controller.dart';

import '../../support/random_inputs.dart';
import 'file_property_inputs.dart';
import 'file_tree_view_inputs.dart';

void main() {
  testWidgets('test_collect_lines_property_rows_follow_open_folders_depth_'
      'first', (WidgetTester tester) async {
    final Random random = seededRandom(100487);

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

      expect(
        readShownTreePaths(tester),
        listVisiblePathsByModel(tree, openFolders),
      );
      controller.dispose();
    }
  });

  testWidgets('test_collect_lines_property_closing_and_reopening_restores_'
      'the_subtree', (WidgetTester tester) async {
    final Random random = seededRandom(100488);

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
      final List<String> shownOpen = <String>[
        for (final String path in readShownTreePaths(tester))
          if (openFolders.contains(path)) path,
      ];
      if (shownOpen.isEmpty) {
        controller.dispose();
        continue;
      }
      final String folder = pickOne(random, shownOpen);
      final List<String> before = readShownTreePaths(tester);

      await tapTreeRow(tester, folder);
      final List<String> closed = readShownTreePaths(tester);
      await tapTreeRow(tester, folder);

      expect(
        closed.where((String path) => path.startsWith('$folder/')),
        isEmpty,
      );
      expect(
        closed,
        listVisiblePathsByModel(tree, openFolders.difference({folder})),
      );
      expect(readShownTreePaths(tester), before);
      controller.dispose();
    }
  });

  testWidgets('test_collect_lines_property_refused_folder_shows_no_'
      'children', (WidgetTester tester) async {
    final Random random = seededRandom(100489);

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

      expect(
        readShownTreePaths(tester),
        listVisiblePathsByModel(tree, <String>{}),
      );
      expect(tester.takeException(), isNull);
      controller.dispose();
    }
  });
}
