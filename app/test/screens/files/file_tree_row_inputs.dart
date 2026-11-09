import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_property_inputs.dart';

const int deepestTreeRowDepth = 40;

void ignoreTreeRowTap() {}

FileTreeRow randomFileTreeRow(
  Random random, {
  required FolderState folderState,
  required VoidCallback onTap,
}) {
  final bool isFolder = folderState != FolderState.notAFolder;
  final bool hasSize = !isFolder && random.nextInt(4) != 0;
  return FileTreeRow(
    name: randomHostileFileName(random),
    size: hasSize ? randomFileSize(random) : null,
    depth: random.nextInt(deepestTreeRowDepth),
    folderState: folderState,
    emphasis: pickOne(random, RowEmphasis.values),
    onTap: onTap,
  );
}

Future<double> pumpFileTreeRows(
  WidgetTester tester,
  Random random,
  List<FileTreeRow> rows,
) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(
    tester,
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    ),
  );
  expect(tester.takeException(), isNull, reason: 'width $width');
  return width;
}

Finder findFileTreeRowName(String name) {
  return find.descendant(
    of: find.byType(FileTreeRow),
    matching: find.text(name),
  );
}

Semantics readOuterRowSemantics(WidgetTester tester) {
  final Finder outer = find
      .descendant(
        of: find.byType(FileTreeRow),
        matching: find.byType(Semantics),
      )
      .first;
  return tester.widget(outer);
}
