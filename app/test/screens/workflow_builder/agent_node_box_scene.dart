import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';

const int _longTextRepeats = 12;
const double nodePortInset =
    (CanvasMetrics.nodeWidth - CanvasMetrics.portExtent) / 2;

typedef NodeParts = ({
  String kindText,
  String name,
  String? targetText,
  StepKind stepKind,
  NodeLook look,
});

String _randomNodeText(Random random) {
  final String text = randomText(random);
  return pickOne(random, <String>[
    text,
    randomHostileText(random),
    List<String>.filled(_longTextRepeats, 'ünïcødé-$text').join(),
  ]);
}

NodeParts randomNodeParts(Random random) {
  return (
    kindText: _randomNodeText(random),
    name: _randomNodeText(random),
    targetText: random.nextBool() ? null : _randomNodeText(random),
    stepKind: pickOne(random, StepKind.values),
    look: pickOne(random, NodeLook.values),
  );
}

AgentNodeBox buildNodeBox(NodeParts parts) {
  return AgentNodeBox(
    kindText: parts.kindText,
    name: parts.name,
    targetText: parts.targetText,
    stepKind: parts.stepKind,
    look: parts.look,
  );
}

Future<NodeParts> pumpRandomNodeBox(WidgetTester tester, Random random) async {
  final NodeParts parts = randomNodeParts(random);
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: Center(child: buildNodeBox(parts)),
  );
  return parts;
}

Finder findNodeOutlineBox() {
  return find.descendant(
    of: find.byType(AgentNodeBox),
    matching: find.byWidgetPredicate(
      (Widget widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.rectangle,
    ),
  );
}

BoxDecoration readNodeOutline(WidgetTester tester) {
  final DecoratedBox box = tester.widget(findNodeOutlineBox());
  return box.decoration as BoxDecoration;
}

Finder findNodePorts() {
  return find.descendant(
    of: find.byType(AgentNodeBox),
    matching: find.byWidgetPredicate(
      (Widget widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle,
    ),
  );
}

Finder findDashedNodeOutline() {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is CustomPaint && widget.painter is DashedOutlinePainter,
  );
}
