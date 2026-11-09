import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/code_view.dart';
import 'package:agent_orchestration/screens/files/syntax_languages.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_property_inputs.dart';

const List<String> _codeLines = <String>[
  'const x = "/login";',
  "export function go(a) { return 'b'; }",
  'let value = call(1);',
  'if (ready) { await run(); }',
];
const int _largestCodeLineCount = 12;

typedef ShownCodeLine = ({RenderParagraph number, RenderParagraph code});

SyntaxLanguage? randomSyntaxLanguage(Random random) {
  return findSyntaxLanguage(pickOne(random, sampleFileExtensions));
}

String randomCode(Random random) {
  final int lineCount = random.nextInt(_largestCodeLineCount);
  final List<String> lines = <String>[
    for (int index = 0; index < lineCount; index += 1)
      pickOne(random, <String>[..._codeLines, randomFileText(random)]),
  ];
  return lines.join('\n');
}

Future<void> pumpCodeView(
  WidgetTester tester,
  Random random,
  CodeView view,
) async {
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: view,
  );
}

List<ShownCodeLine> findShownCodeLines() {
  final List<Element> texts = find
      .descendant(of: find.byType(CodeView), matching: find.byType(RichText))
      .evaluate()
      .toList();
  final List<ShownCodeLine> lines = <ShownCodeLine>[];
  for (int index = 0; index + 1 < texts.length; index += 2) {
    lines.add((
      number: texts[index].renderObject! as RenderParagraph,
      code: texts[index + 1].renderObject! as RenderParagraph,
    ));
  }
  return lines;
}

List<TextSpan> readCodeSpans(ShownCodeLine line) {
  final TextSpan outer = line.code.text as TextSpan;
  final TextSpan shownLine = outer.children!.single as TextSpan;
  return <TextSpan>[
    for (final InlineSpan span in shownLine.children!) span as TextSpan,
  ];
}
