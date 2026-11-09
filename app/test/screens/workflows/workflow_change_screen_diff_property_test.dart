import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/widgets/code_block.dart';

import '../../support/random_inputs.dart';
import 'workflow_change_scene.dart';

List<String> _readDocumentLines(String document) {
  final List<String> lines = document.split('\n');
  if (lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

void main() {
  testWidgets('test_workflow_change_screen_build_page_property_diff_keeps_'
      'both_documents_line_for_line', (WidgetTester tester) async {
    final Random random = seededRandom(1220207);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RandomChangePage page = await openRandomChangePage(tester, random);
      final WorkflowChange? change = page.change;
      if (change == null) {
        continue;
      }
      final CodeBlock block = tester.widget<CodeBlock>(find.byType(CodeBlock));
      final List<String> before = <String>[];
      final List<String> after = <String>[];

      for (final CodeBlockLine line in block.lines) {
        final String marker = line.text.substring(0, diffMarkerWidth);
        final String text = line.text.substring(diffMarkerWidth);
        if (line.change != LineChange.added) {
          before.add(text);
        }
        if (line.change != LineChange.removed) {
          after.add(text);
        }
        final String expectedMarker = switch (line.change) {
          LineChange.unchanged => '  ',
          LineChange.added => '+ ',
          LineChange.removed => '- ',
        };
        expect(marker, expectedMarker);
      }

      expect(before, _readDocumentLines(change.signedDocument));
      expect(after, _readDocumentLines(change.changedDocument));
    }
  });

  testWidgets('test_workflow_change_screen_build_page_property_every_line_'
      'is_shown_with_its_indentation', (WidgetTester tester) async {
    final Random random = seededRandom(1220208);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RandomChangePage page = await openRandomChangePage(tester, random);
      if (page.change == null) {
        continue;
      }
      final Finder block = find.byType(CodeBlock);
      final CodeBlock shown = tester.widget<CodeBlock>(block);

      for (final CodeBlockLine line in shown.lines) {
        expect(
          find.descendant(of: block, matching: find.text(line.text)),
          findsWidgets,
          reason: '"${line.text}"',
        );
      }
    }
  });

  testWidgets('test_workflow_change_screen_build_page_property_lists_every_'
      'difference', (WidgetTester tester) async {
    final Random random = seededRandom(1220209);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RandomChangePage page = await openRandomChangePage(tester, random);
      final WorkflowChange? change = page.change;
      if (change == null) {
        expect(find.text('What changes'), findsNothing);
        continue;
      }

      expect(find.text('What changes'), findsOneWidget);
      for (final WorkflowDifference difference in change.differences) {
        expect(find.text(difference.subject), findsWidgets);
        expect(find.text(difference.change), findsWidgets);
      }
    }
  });
}
