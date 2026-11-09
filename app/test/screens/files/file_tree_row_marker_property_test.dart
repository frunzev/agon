import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';

import '../../support/random_inputs.dart';
import 'file_tree_row_inputs.dart';

const double _quarterTurn = 0.25;

void main() {
  testWidgets('test_build_marker_property_only_folders_show_a_chevron', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100457);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderState state = pickOne(random, FolderState.values);

      await pumpFileTreeRows(tester, random, <FileTreeRow>[
        randomFileTreeRow(random, folderState: state, onTap: ignoreTreeRowTap),
      ]);

      final Finder chevron = find.byWidgetPredicate(
        (Widget widget) =>
            widget is AppIcon && widget.kind == AppIconKind.chevronRight,
      );
      final bool isFolder = state != FolderState.notAFolder;
      expect(chevron, isFolder ? findsOneWidget : findsNothing);
    }
  });

  testWidgets('test_build_marker_property_open_folders_point_down', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100458);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderState state = pickOne(random, <FolderState>[
        FolderState.collapsed,
        FolderState.expanded,
      ]);

      await pumpFileTreeRows(tester, random, <FileTreeRow>[
        randomFileTreeRow(random, folderState: state, onTap: ignoreTreeRowTap),
      ]);
      await tester.pump(const Duration(seconds: 1));

      final AnimatedRotation rotation = tester.widget(
        find.byType(AnimatedRotation),
      );
      final double expectedTurns = state == FolderState.expanded
          ? _quarterTurn
          : 0;
      expect(rotation.turns, expectedTurns);
    }
  });

  testWidgets('test_build_marker_property_names_line_up_across_kinds', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100459);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int depth = random.nextInt(4);
      final List<FileTreeRow> rows = <FileTreeRow>[
        for (final FolderState state in FolderState.values)
          FileTreeRow(
            name: 'n${state.name}',
            size: null,
            depth: depth,
            folderState: state,
            emphasis: pickOne(random, RowEmphasis.values),
            onTap: ignoreTreeRowTap,
          ),
      ];

      await pumpFileTreeRows(tester, random, rows);

      final Set<double> lefts = <double>{
        for (final FolderState state in FolderState.values)
          tester.getTopLeft(findFileTreeRowName('n${state.name}')).dx,
      };
      expect(lefts, hasLength(1));
    }
  });
}
