import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

List<String> readShownTexts(WidgetTester tester, Finder within) {
  final Finder texts = find.descendant(
    of: within,
    matching: find.byType(Text),
  );
  final List<String> shownTexts = <String>[];

  for (final Text text in tester.widgetList<Text>(texts)) {
    shownTexts.add(text.data ?? text.textSpan!.toPlainText());
  }

  return shownTexts;
}

Future<double> pumpAtRandomWidth(
  WidgetTester tester,
  Random random,
  Widget child,
) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(tester, width: width, child: child);
  expect(tester.takeException(), isNull, reason: 'width $width');
  return width;
}
