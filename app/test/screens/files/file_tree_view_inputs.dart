import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/file_tree_controller.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/screens/files/repository_file_paths.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_property_inputs.dart';

const String treeRootFolder = '';
const int _largestFolderTapCount = 6;

typedef VisibleTreeLine = ({String path, int depth, RepositoryEntry entry});

typedef ShownTreeRow = ({
  String path,
  String name,
  int? size,
  int depth,
  FolderState folderState,
  RowEmphasis emphasis,
});

void ignoreOpenedFile(String path) {}

List<VisibleTreeLine> listVisibleLinesByModel(
  FolderTree tree,
  Set<String> openFolders,
) {
  final List<VisibleTreeLine> lines = <VisibleTreeLine>[];
  _walkFolder(tree, openFolders, treeRootFolder, 0, lines);
  return lines;
}

void _walkFolder(
  FolderTree tree,
  Set<String> openFolders,
  String folder,
  int depth,
  List<VisibleTreeLine> lines,
) {
  for (final RepositoryEntry entry in tree[folder]!) {
    final String path = joinRepositoryPath(folder, entry.name);
    lines.add((path: path, depth: depth, entry: entry));
    final bool isFolder = entry.kind == RepositoryEntryKind.folder;
    if (isFolder && openFolders.contains(path)) {
      _walkFolder(tree, openFolders, path, depth + 1, lines);
    }
  }
}

List<String> listVisiblePathsByModel(
  FolderTree tree,
  Set<String> openFolders,
) {
  return <String>[
    for (final VisibleTreeLine line in listVisibleLinesByModel(
      tree,
      openFolders,
    ))
      line.path,
  ];
}

List<String> listVisibleFolderPaths(FolderTree tree, Set<String> openFolders) {
  return <String>[
    for (final String path in listVisiblePathsByModel(tree, openFolders))
      if (tree.containsKey(path)) path,
  ];
}

List<ShownTreeRow> readShownTreeRows(WidgetTester tester) {
  final List<ShownTreeRow> rows = <ShownTreeRow>[];
  for (final Element element in find.byType(FileTreeRow).evaluate()) {
    final FileTreeRow row = element.widget as FileTreeRow;
    final ValueKey<String> key = row.key! as ValueKey<String>;
    rows.add((
      path: key.value,
      name: row.name,
      size: row.size,
      depth: row.depth,
      folderState: row.folderState,
      emphasis: row.emphasis,
    ));
  }
  return rows;
}

List<String> readShownTreePaths(WidgetTester tester) {
  return <String>[
    for (final ShownTreeRow row in readShownTreeRows(tester)) row.path,
  ];
}

Future<FileTreeController> pumpRevealedFileTree(
  WidgetTester tester,
  Random random, {
  required ScriptedFolderRepository repository,
  required String? currentPath,
  required ValueChanged<String> onOpenFile,
}) async {
  final FileTreeController controller = FileTreeController(
    fileRepository: repository,
    location: sampleBranchLocation,
  );
  await controller.revealFolders(const <String>[treeRootFolder]);
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(
    tester,
    width: width,
    child: FileTreeView(
      controller: controller,
      currentPath: currentPath,
      onOpenFile: onOpenFile,
    ),
  );
  expect(tester.takeException(), isNull, reason: 'width $width');
  return controller;
}

Future<void> tapTreeRow(WidgetTester tester, String path) async {
  final Finder row = find.byKey(ValueKey<String>(path));
  await tester.ensureVisible(row);
  await tester.pump();
  await tester.tap(row);
  await tester.pump();
  await tester.pump();
}

Future<Set<String>> openRandomFolders(
  WidgetTester tester,
  Random random,
) async {
  final Set<String> openFolders = <String>{};
  final int tapCount = random.nextInt(_largestFolderTapCount);
  for (int tap = 0; tap < tapCount; tap += 1) {
    final List<ShownTreeRow> folders = <ShownTreeRow>[
      for (final ShownTreeRow row in readShownTreeRows(tester))
        if (row.folderState != FolderState.notAFolder) row,
    ];
    if (folders.isEmpty) {
      return openFolders;
    }
    final String path = pickOne(random, folders).path;
    await tapTreeRow(tester, path);
    if (!openFolders.remove(path)) {
      openFolders.add(path);
    }
  }
  return openFolders;
}
