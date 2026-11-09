import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_tree_row_inputs.dart';

const double _edgeMarkerAndGap =
    AppBorders.selected + AppSizes.iconSmall + AppSpacing.space2;
const int _shallowestDesignDepths = 6;

FileTreeRow _rowAtDepth(int depth, FolderState state) {
  return FileTreeRow(
    name: 'n$depth',
    size: null,
    depth: depth,
    folderState: state,
    emphasis: RowEmphasis.normal,
    onTap: ignoreTreeRowTap,
  );
}

double _readIndent(WidgetTester tester, int depth) {
  final double nameLeft = tester.getTopLeft(findFileTreeRowName('n$depth')).dx;
  return nameLeft - _edgeMarkerAndGap;
}

void main() {
  testWidgets('test_describe_indent_property_shallow_rows_follow_the_'
      'design_steps', (WidgetTester tester) async {
    final Random random = seededRandom(100471);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderState state = pickOne(random, FolderState.values);

      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: desktopWidth, most: widestWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int depth = 0; depth < _shallowestDesignDepths; depth += 1)
              _rowAtDepth(depth, state),
          ],
        ),
      );

      for (int depth = 0; depth < _shallowestDesignDepths; depth += 1) {
        final double expected = AppSpacing.space3 + depth * AppSpacing.space5;
        expect(_readIndent(tester, depth), closeTo(expected, 0.01));
      }
    }
  });

  testWidgets('test_describe_indent_property_leaves_the_name_most_of_the_'
      'row', (WidgetTester tester) async {
    final Random random = seededRandom(100472);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final int depth = random.nextInt(deepestTreeRowDepth);

      final List<FileTreeRow> rows = <FileTreeRow>[
        _rowAtDepth(depth, pickOne(random, FolderState.values)),
      ];
      final double width = await pumpFileTreeRows(tester, random, rows);

      expect(_readIndent(tester, depth), lessThanOrEqualTo(width / 2));
    }
  });

  testWidgets('test_describe_indent_property_never_shrinks_with_depth', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100473);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final int shallower = random.nextInt(deepestTreeRowDepth);
      final int deeper = shallower + 1 + random.nextInt(deepestTreeRowDepth);
      final FolderState state = pickOne(random, FolderState.values);

      await pumpFileTreeRows(tester, random, <FileTreeRow>[
        _rowAtDepth(shallower, state),
        _rowAtDepth(deeper, state),
      ]);

      expect(
        _readIndent(tester, deeper),
        greaterThanOrEqualTo(_readIndent(tester, shallower)),
      );
    }
  });
}
