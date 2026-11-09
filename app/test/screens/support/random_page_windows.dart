import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const double _shortestWindowHeight = 560;
const double _tallestWindowHeight = 1100;

Size randomPageWindowSize(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  final double height = randomWidth(
    random,
    least: _shortestWindowHeight,
    most: _tallestWindowHeight,
  );
  return Size(width, height);
}

Future<void> pumpPageInRandomWindow(
  WidgetTester tester, {
  required Random random,
  required Widget page,
}) async {
  final Size windowSize = randomPageWindowSize(random);
  final TargetPlatform platform = platformMeantByWidth(windowSize.width);
  await tester.pumpWidget(const SizedBox.shrink());
  useViewSize(tester, windowSize);
  await tester.pumpWidget(wrapInApp(page, platform: platform));
  await tester.pump();
}

Future<void> tapShownText(WidgetTester tester, String text) async {
  final Finder shown = find.text(text).last;
  await tester.ensureVisible(shown);
  await tester.tap(shown);
  await tester.pump();
}

final class TapCounter {
  int count = 0;

  void countTap() {
    count += 1;
  }
}
