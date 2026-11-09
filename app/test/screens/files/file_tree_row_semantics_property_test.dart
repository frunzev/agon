import 'dart:math';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_tree_view.dart';

import '../../support/random_inputs.dart';
import 'file_tree_row_inputs.dart';

Tristate _expectedExpandedFlag(FolderState state) {
  return switch (state) {
    FolderState.notAFolder => Tristate.none,
    FolderState.collapsed => Tristate.isFalse,
    FolderState.expanded => Tristate.isTrue,
  };
}

void main() {
  testWidgets('test_describe_expanded_state_property_semantics_follow_the_'
      'folder_state', (WidgetTester tester) async {
    final Random random = seededRandom(100454);
    final SemanticsHandle semantics = tester.ensureSemantics();

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderState state = pickOne(random, FolderState.values);
      final FileTreeRow row = randomFileTreeRow(
        random,
        folderState: state,
        onTap: ignoreTreeRowTap,
      );

      await pumpFileTreeRows(tester, random, <FileTreeRow>[row]);

      final SemanticsData data = tester
          .getSemantics(find.byType(InkWell))
          .getSemanticsData();
      expect(data.flagsCollection.isExpanded, _expectedExpandedFlag(state));
    }
    semantics.dispose();
  });

  testWidgets('test_describe_expanded_state_property_every_row_is_a_'
      'button', (WidgetTester tester) async {
    final Random random = seededRandom(100455);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FileTreeRow row = randomFileTreeRow(
        random,
        folderState: pickOne(random, FolderState.values),
        onTap: ignoreTreeRowTap,
      );

      await pumpFileTreeRows(tester, random, <FileTreeRow>[row]);

      final Semantics outer = readOuterRowSemantics(tester);
      expect(outer.properties.button, isTrue);
      final bool isFolder = row.folderState != FolderState.notAFolder;
      expect(outer.properties.expanded != null, isFolder);
    }
  });

  testWidgets('test_describe_expanded_state_property_opening_flips_only_'
      'the_expanded_flag', (WidgetTester tester) async {
    final Random random = seededRandom(100460);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FileTreeRow collapsed = randomFileTreeRow(
        random,
        folderState: FolderState.collapsed,
        onTap: ignoreTreeRowTap,
      );
      final FileTreeRow expanded = FileTreeRow(
        name: collapsed.name,
        size: collapsed.size,
        depth: collapsed.depth,
        folderState: FolderState.expanded,
        emphasis: collapsed.emphasis,
        onTap: collapsed.onTap,
      );

      await pumpFileTreeRows(tester, random, <FileTreeRow>[collapsed]);
      final Semantics before = readOuterRowSemantics(tester);
      await pumpFileTreeRows(tester, random, <FileTreeRow>[expanded]);
      final Semantics after = readOuterRowSemantics(tester);

      expect(before.properties.expanded, isFalse);
      expect(after.properties.expanded, isTrue);
      expect(after.properties.button, before.properties.button);
    }
  });
}
