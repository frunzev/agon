import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_sizes.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_tree_row_inputs.dart';

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

void main() {
  testWidgets('test_file_tree_row_build_property_each_level_indents_by_the_'
      'same_step', (WidgetTester tester) async {
    final Random random = seededRandom(100453);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int depth = random.nextInt(3);
      final FolderState state = pickOne(random, FolderState.values);

      await pumpScrollableAtWidth(
        tester,
        width: desktopWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int level = depth; level < depth + 3; level += 1)
              _rowAtDepth(level, state),
          ],
        ),
      );

      final double first = tester
          .getTopLeft(findFileTreeRowName('n$depth'))
          .dx;
      final double second = tester
          .getTopLeft(findFileTreeRowName('n${depth + 1}'))
          .dx;
      final double third = tester
          .getTopLeft(findFileTreeRowName('n${depth + 2}'))
          .dx;
      expect(second, greaterThan(first));
      expect(third - second, closeTo(second - first, 0.01));
    }
  });

  testWidgets('test_file_tree_row_build_property_tap_calls_on_tap_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100456);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      int taps = 0;
      final FileTreeRow row = randomFileTreeRow(
        random,
        folderState: pickOne(random, FolderState.values),
        onTap: () => taps += 1,
      );

      await pumpFileTreeRows(tester, random, <FileTreeRow>[row]);
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(taps, 1);
    }
  });

  testWidgets('test_build_fitted_row_property_deep_rows_fit_every_width', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100451);

    for (int i = 0; i < widgetPropertyIterations * 3; i += 1) {
      final FileTreeRow row = randomFileTreeRow(
        random,
        folderState: pickOne(random, FolderState.values),
        onTap: ignoreTreeRowTap,
      );

      final List<FileTreeRow> rows = <FileTreeRow>[row];
      final double width = await pumpFileTreeRows(tester, random, rows);

      final Rect name = tester.getRect(findFileTreeRowName(row.name));
      expect(name.width, greaterThan(0), reason: 'depth ${row.depth}');
      expect(name.right, lessThanOrEqualTo(width + 0.5));
    }
  });

  testWidgets('test_build_fitted_row_property_shows_the_size_only_when_'
      'known', (WidgetTester tester) async {
    final Random random = seededRandom(100452);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FileTreeRow row = randomFileTreeRow(
        random,
        folderState: pickOne(random, FolderState.values),
        onTap: ignoreTreeRowTap,
      );

      await pumpFileTreeRows(tester, random, <FileTreeRow>[row]);

      final int? size = row.size;
      expect(findFileTreeRowName(row.name), findsOneWidget);
      final Finder texts = find.descendant(
        of: find.byType(FileTreeRow),
        matching: find.byType(Text),
      );
      expect(texts, size == null ? findsOneWidget : findsNWidgets(2));
      if (size != null) {
        expect(find.text(describeFileSize(size)), findsOneWidget);
      }
    }
  });

  testWidgets('test_build_fitted_row_property_keeps_the_control_height', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100461);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FileTreeRow row = randomFileTreeRow(
        random,
        folderState: pickOne(random, FolderState.values),
        onTap: ignoreTreeRowTap,
      );

      final List<FileTreeRow> rows = <FileTreeRow>[row];
      final double width = await pumpFileTreeRows(tester, random, rows);

      final double height = tester.getSize(find.byType(FileTreeRow)).height;
      final double controlHeight = AppSizes.controlHeightFor(
        densityMeantByWidth(width),
      );
      expect(height, greaterThanOrEqualTo(controlHeight));
    }
  });
}
