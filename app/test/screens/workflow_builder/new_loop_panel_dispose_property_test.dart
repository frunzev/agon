import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/new_loop_panel_scene.dart';
import 'support/random_connection_scenes.dart';

void main() {
  testWidgets('test_new_loop_panel_dispose_property_unmounting_after_'
      'typing_is_quiet', (WidgetTester tester) async {
    final Random random = seededRandom(1191710);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final LoopPanelLog log = await pumpLoopPanel(
        tester,
        random,
        randomDrawnLoopScene(random),
      );
      await typeLoopOutcome(tester, randomText(random));

      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.takeException(), isNull);
      expect(log.addedLoops, isEmpty);
      expect(log.cancels.count, 0);
    }
  });

  testWidgets('test_new_loop_panel_dispose_property_a_new_panel_starts_'
      'empty', (WidgetTester tester) async {
    final Random random = seededRandom(1191711);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomDrawnLoopScene(random);
      await pumpLoopPanel(tester, random, scene, key: UniqueKey());
      await typeLoopOutcome(tester, 'typed-${random.nextInt(99)}');
      await tapAddLoop(tester);

      await pumpLoopPanel(tester, random, scene, key: UniqueKey());

      final TextField field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      expect(field.decoration?.errorText, isNull);
      expect(find.text(chooseRoundsProblem), findsNothing);
    }
  });

  testWidgets('test_new_loop_panel_dispose_property_same_panel_keeps_'
      'typing', (WidgetTester tester) async {
    final Random random = seededRandom(1191712);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomDrawnLoopScene(random);
      final Key key = UniqueKey();
      final double width = randomLoopPanelWidth(random);
      await pumpLoopPanel(tester, random, scene, key: key, width: width);
      final String typed = 'kept-${random.nextInt(99)}';
      await typeLoopOutcome(tester, typed);

      await pumpLoopPanel(tester, random, scene, key: key, width: width);

      final TextField field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, typed);
    }
  });
}
