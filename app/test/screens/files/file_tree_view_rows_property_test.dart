import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/file_tree_controller.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'file_property_inputs.dart';
import 'file_tree_view_inputs.dart';

Future<FileTreeController> _pumpTree(
  WidgetTester tester,
  Random random,
  FolderTree tree, {
  required String? currentPath,
  required ValueChanged<String> onOpenFile,
}) {
  return pumpRevealedFileTree(
    tester,
    random,
    repository: ScriptedFolderRepository(folders: tree),
    currentPath: currentPath,
    onOpenFile: onOpenFile,
  );
}

List<ShownTreeRow> _filterRows(
  WidgetTester tester, {
  required bool Function(ShownTreeRow row) keeps,
}) {
  return <ShownTreeRow>[
    for (final ShownTreeRow row in readShownTreeRows(tester))
      if (keeps(row)) row,
  ];
}

bool _isFolderRow(ShownTreeRow row) {
  return row.folderState != FolderState.notAFolder;
}

bool _isFileRow(ShownTreeRow row) => !_isFolderRow(row);

void main() {
  testWidgets('test_build_row_property_tapping_a_file_opens_exactly_its_'
      'path', (WidgetTester tester) async {
    final Random random = seededRandom(100491);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> openedFiles = <String>[];
      final FileTreeController controller = await _pumpTree(
        tester,
        random,
        randomFolderTree(random),
        currentPath: null,
        onOpenFile: openedFiles.add,
      );
      await openRandomFolders(tester, random);
      final List<ShownTreeRow> files = _filterRows(tester, keeps: _isFileRow);
      if (files.isEmpty) {
        controller.dispose();
        continue;
      }
      final List<String> before = readShownTreePaths(tester);
      final String path = pickOne(random, files).path;

      await tapTreeRow(tester, path);

      expect(openedFiles, <String>[path]);
      expect(readShownTreePaths(tester), before);
      controller.dispose();
    }
  });

  testWidgets('test_build_row_property_only_the_current_path_is_'
      'emphasized', (WidgetTester tester) async {
    final Random random = seededRandom(100492);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final List<VisibleTreeLine> rootLines = listVisibleLinesByModel(
        tree,
        <String>{},
      );
      final String? currentPath = switch (random.nextInt(3)) {
        0 => null,
        1 => randomHostileText(random),
        _ => rootLines.isEmpty ? null : pickOne(random, rootLines).path,
      };

      final FileTreeController controller = await _pumpTree(
        tester,
        random,
        tree,
        currentPath: currentPath,
        onOpenFile: ignoreOpenedFile,
      );
      await openRandomFolders(tester, random);

      for (final ShownTreeRow row in readShownTreeRows(tester)) {
        final bool isCurrent = row.emphasis == RowEmphasis.current;
        expect(isCurrent, row.path == currentPath, reason: row.path);
      }
      controller.dispose();
    }
  });

  testWidgets('test_build_row_property_tapping_folders_never_opens_a_'
      'file', (WidgetTester tester) async {
    final Random random = seededRandom(100493);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> openedFiles = <String>[];
      final FileTreeController controller = await _pumpTree(
        tester,
        random,
        randomFolderTree(random),
        currentPath: null,
        onOpenFile: openedFiles.add,
      );

      final Set<String> openFolders = await openRandomFolders(tester, random);

      expect(openedFiles, isEmpty);
      for (final String folder in openFolders) {
        expect(controller.isExpanded(folder), isTrue);
      }
      controller.dispose();
    }
  });

  testWidgets('test_describe_folder_state_property_matches_the_open_'
      'folders', (WidgetTester tester) async {
    final Random random = seededRandom(100494);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FileTreeController controller = await _pumpTree(
        tester,
        random,
        randomFolderTree(random),
        currentPath: null,
        onOpenFile: ignoreOpenedFile,
      );
      final Set<String> openFolders = await openRandomFolders(tester, random);

      for (final ShownTreeRow row in _filterRows(
        tester,
        keeps: _isFolderRow,
      )) {
        final FolderState expected = openFolders.contains(row.path)
            ? FolderState.expanded
            : FolderState.collapsed;
        expect(row.folderState, expected, reason: row.path);
      }
      controller.dispose();
    }
  });

  testWidgets('test_describe_folder_state_property_tapping_flips_only_that_'
      'folder', (WidgetTester tester) async {
    final Random random = seededRandom(100495);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FileTreeController controller = await _pumpTree(
        tester,
        random,
        randomFolderTree(random),
        currentPath: null,
        onOpenFile: ignoreOpenedFile,
      );
      await openRandomFolders(tester, random);
      final List<ShownTreeRow> folders = _filterRows(
        tester,
        keeps: _isFolderRow,
      );
      if (folders.isEmpty) {
        controller.dispose();
        continue;
      }
      final Map<String, FolderState> before = <String, FolderState>{
        for (final ShownTreeRow row in readShownTreeRows(tester))
          row.path: row.folderState,
      };
      final String tapped = pickOne(random, folders).path;

      await tapTreeRow(tester, tapped);

      for (final ShownTreeRow row in readShownTreeRows(tester)) {
        final FolderState? earlier = before[row.path];
        if (earlier == null) {
          continue;
        }
        if (row.path == tapped) {
          expect(row.folderState, isNot(earlier));
        } else {
          expect(row.folderState, earlier, reason: row.path);
        }
      }
      controller.dispose();
    }
  });

  testWidgets('test_describe_folder_state_property_files_and_links_are_'
      'never_folders', (WidgetTester tester) async {
    final Random random = seededRandom(100496);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final FileTreeController controller = await _pumpTree(
        tester,
        random,
        tree,
        currentPath: null,
        onOpenFile: ignoreOpenedFile,
      );
      final Set<String> openFolders = await openRandomFolders(tester, random);

      final List<VisibleTreeLine> lines = listVisibleLinesByModel(
        tree,
        openFolders,
      );
      final List<ShownTreeRow> rows = readShownTreeRows(tester);
      for (int index = 0; index < lines.length; index += 1) {
        final bool isFolder =
            lines[index].entry.kind == RepositoryEntryKind.folder;
        expect(_isFolderRow(rows[index]), isFolder, reason: rows[index].path);
      }
      controller.dispose();
    }
  });
}
