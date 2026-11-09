import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/markdown_view.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'markdown_view_inputs.dart';

const int deepestIndentedLevel = 6;
const int deepestNesting = 30;
const String shownBullet = '•';
const String uncheckedBox = '☐';
const List<String> _listMarkers = <String>['-', '*', '+', '1.', '7)'];

String nestMarkdownList(List<String> markers, {required bool isLoose}) {
  final List<String> lines = <String>[];
  int indent = 0;
  for (int level = 0; level < markers.length; level += 1) {
    lines.add('${' ' * indent}${markers[level]} item$level');
    if (isLoose) {
      lines.add('');
    }
    indent += markers[level].length + 1;
  }
  return lines.join('\n');
}

List<String> randomListMarkers(Random random, int depth) {
  return <String>[
    for (int level = 0; level < depth; level += 1)
      pickOne(random, _listMarkers),
  ];
}

String describeShownMarker(String marker) {
  if (marker.endsWith('.') || marker.endsWith(')')) {
    return '${marker.substring(0, marker.length - 1)}.';
  }
  return shownBullet;
}

Finder findNestedItem(int level) {
  return find.descendant(
    of: find.byType(MarkdownView),
    matching: find.byWidgetPredicate(
      (Widget widget) =>
          widget is Text &&
          (readPlainText(widget) == 'item$level' ||
              readPlainText(widget).endsWith(' item$level')),
    ),
  );
}

Future<void> pumpMarkdownAtNarrowestWidth(
  WidgetTester tester,
  String text,
) async {
  await pumpScrollableAtWidth(
    tester,
    width: narrowestWidth,
    child: MarkdownView(text: text),
  );
  expect(tester.takeException(), isNull, reason: text);
}

int countSameMarkersBefore(List<String> markers, int level) {
  final String shown = describeShownMarker(markers[level]);
  int count = 0;
  for (int earlier = 0; earlier < level; earlier += 1) {
    if (describeShownMarker(markers[earlier]) == shown) {
      count += 1;
    }
  }
  return count;
}
