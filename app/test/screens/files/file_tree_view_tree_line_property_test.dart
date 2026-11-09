import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_tree_controller.dart';
import 'package:agent_orchestration/screens/files/repository_file_paths.dart';

import '../../support/random_inputs.dart';
import 'file_property_inputs.dart';
import 'file_tree_view_inputs.dart';

const String _pathSeparator = '/';

void main() {
  testWidgets('test_tree_line_property_rows_keep_the_entry_name_and_size', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100497);

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

      final List<VisibleTreeLine> lines = listVisibleLinesByModel(
        tree,
        openFolders,
      );
      final List<ShownTreeRow> rows = readShownTreeRows(tester);
      expect(rows, hasLength(lines.length));
      for (int index = 0; index < lines.length; index += 1) {
        expect(rows[index].name, lines[index].entry.name);
        expect(rows[index].size, lines[index].entry.size);
      }
      controller.dispose();
    }
  });

  testWidgets('test_tree_line_property_row_paths_join_folder_and_name', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100498);

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
      final Set<String> openFolders = await openRandomFolders(tester, random);

      for (final ShownTreeRow row in readShownTreeRows(tester)) {
        final String parent = parentFolderOf(row.path);
        expect(fileNameOf(row.path), row.name);
        expect(joinRepositoryPath(parent, row.name), row.path);
        final bool isRoot = parent == treeRootFolder;
        expect(isRoot || openFolders.contains(parent), isTrue);
      }
      controller.dispose();
    }
  });

  testWidgets('test_tree_line_property_depth_counts_the_folders_above', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100499);

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

      for (final ShownTreeRow row in readShownTreeRows(tester)) {
        final int foldersAbove = row.path.split(_pathSeparator).length - 1;
        expect(row.depth, foldersAbove, reason: row.path);
      }
      controller.dispose();
    }
  });
}
