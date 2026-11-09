import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/widgets/forms/field_problem_text.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../screens/support/random_page_windows.dart';
import '../../support/random_inputs.dart';

const int _longProblemRepeats = 20;

String _randomProblem(Random random) {
  return pickOne(random, <String>[
    randomHostileText(random),
    List<String>.filled(_longProblemRepeats, randomText(random)).join(' '),
    'This was deleted. Pick one from the list.',
  ]);
}

Future<String> _pumpProblem(WidgetTester tester, Random random) async {
  final String problem = _randomProblem(random);
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: SingleChildScrollView(child: FieldProblemText(problem: problem)),
  );
  return problem;
}

void main() {
  testWidgets('test_field_problem_text_build_property_shows_the_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1163001);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem = await _pumpProblem(tester, random);

      expect(find.text(problem), findsOneWidget);
    }
  });

  testWidgets('test_field_problem_text_build_property_in_danger_color', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1163002);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem = await _pumpProblem(tester, random);
      final Text text = tester.widget(find.text(problem));

      expect(text.style!.color, AppColors.danger);
    }
  });

  testWidgets('test_field_problem_text_build_property_long_text_wraps', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1163003);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpProblem(tester, random);

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(
        tester.getSize(find.byType(FieldProblemText)).width,
        lessThanOrEqualTo(tester.view.physicalSize.width),
      );
    }
  });
}
