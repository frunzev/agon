import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';

const String _doneLabel = 'Done';
const int _longTitleRepeats = 15;

String _randomTitle(Random random) {
  return pickOne(random, <String>[
    newLoopTitle,
    personStepPanelTitle,
    randomHostileText(random),
    List<String>.filled(_longTitleRepeats, randomText(random)).join(' '),
  ]);
}

Future<TapCounter?> _pumpHeading(
  WidgetTester tester,
  Random random,
  String title,
) async {
  final TapCounter? dones = random.nextBool() ? TapCounter() : null;
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: SingleChildScrollView(
      child: PanelHeading(title: title, onDone: dones?.countTap),
    ),
  );
  return dones;
}

void main() {
  testWidgets('test_panel_heading_build_property_title_is_a_header', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1192001);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String title = _randomTitle(random);

      await _pumpHeading(tester, random, title);

      final Finder header = find.ancestor(
        of: find.text(title),
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is Semantics && widget.properties.header == true,
        ),
      );
      expect(header, findsOneWidget);
    }
  });

  testWidgets('test_panel_heading_build_property_done_shows_only_when_'
      'given', (WidgetTester tester) async {
    final Random random = seededRandom(1192002);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TapCounter? dones = await _pumpHeading(
        tester,
        random,
        _randomTitle(random),
      );
      if (dones == null) {
        expect(find.text(_doneLabel), findsNothing);
        continue;
      }

      await tester.tap(find.text(_doneLabel));
      await tester.pump();

      expect(dones.count, 1);
    }
  });

  testWidgets('test_panel_heading_build_property_long_titles_fit', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1192003);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpHeading(tester, random, _randomTitle(random));

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(PanelHeading)).width,
        lessThanOrEqualTo(tester.view.physicalSize.width),
      );
    }
  });
}
