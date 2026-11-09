import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

String? _randomProblem(Random random) {
  return random.nextBool() ? null : '${randomText(random)} problem';
}

void main() {
  testWidgets('test_outcome_field_build_property_shows_label_hint_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TextEditingController controller = TextEditingController();
      final String hint = '${randomText(random)} hint';
      final String? problem = _randomProblem(random);
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );

      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: OutcomeField(
          controller: controller,
          hint: hint,
          problem: problem,
          onChanged: (String _) {},
        ),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(find.text(outcomeLabel), findsOneWidget);
      expect(find.text(hint), findsOneWidget);
      if (problem != null) {
        expect(find.text(problem), findsOneWidget);
      }
      final InputDecoration decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      expect(decoration.errorText, problem);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('test_outcome_field_build_property_typing_reports_the_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TextEditingController controller = TextEditingController();
      final List<String> changes = <String>[];
      final String typed = randomText(random);
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: OutcomeField(
          controller: controller,
          hint: loopOutcomeHint,
          problem: null,
          onChanged: changes.add,
        ),
      );

      await tester.enterText(find.byType(TextField), typed);
      await tester.pump();

      expect(controller.text, typed);
      expect(changes, typed.isEmpty ? isEmpty : <String>[typed]);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('test_outcome_field_build_property_shows_the_saved_outcome', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String saved = randomText(random);
      final TextEditingController controller = TextEditingController(
        text: saved,
      );
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: OutcomeField(
          controller: controller,
          hint: loopOutcomeHint,
          problem: null,
          onChanged: (String _) {},
        ),
      );

      final TextField field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, saved);
      expect(field.autocorrect, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });
}
