import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/widgets/forms/field_problem_text.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';

const int _longProblemRepeats = 12;

String _randomRoundsProblem(Random random) {
  return pickOne(random, <String>[
    chooseRoundsProblem,
    randomHostileText(random),
    List<String>.filled(_longProblemRepeats, randomText(random)).join(' '),
  ]);
}

int? _randomRoundLimit(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return fewestLoopRounds + random.nextInt(mostLoopRounds);
}

Future<void> _pumpRoundLimitField(
  WidgetTester tester, {
  required Random random,
  required String? problem,
}) async {
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: SingleChildScrollView(
      child: RoundLimitField(
        roundLimit: _randomRoundLimit(random),
        problem: problem,
        onChanged: (int _) {},
      ),
    ),
  );
}

Finder _findProblemOutsideSharedText(String problem) {
  return find.byWidgetPredicate((Widget widget) {
    return widget is Text && widget.data == problem;
  });
}

void main() {
  testWidgets('test_round_limit_field_build_property_problem_is_the_shared_'
      'field_problem_text', (WidgetTester tester) async {
    final Random random = seededRandom(1190301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem = _randomRoundsProblem(random);
      await _pumpRoundLimitField(tester, random: random, problem: problem);

      final Finder shared = find.byType(FieldProblemText);
      expect(shared, findsOneWidget);
      expect(tester.widget<FieldProblemText>(shared).problem, problem);
      expect(
        find.descendant(of: shared, matching: find.text(problem)),
        findsOneWidget,
      );
      expect(_findProblemOutsideSharedText(problem), findsOneWidget);
    }
  });

  testWidgets('test_round_limit_field_build_property_problem_is_red_and_'
      'fits', (WidgetTester tester) async {
    final Random random = seededRandom(1190302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem = _randomRoundsProblem(random);
      await _pumpRoundLimitField(tester, random: random, problem: problem);

      expect(tester.takeException(), isNull, reason: 'round $i');
      final Text shown = tester.widget<Text>(
        _findProblemOutsideSharedText(problem),
      );
      expect(shown.style?.color, AppColors.danger);
      expect(
        tester.getSize(find.byType(RoundLimitField)).width,
        lessThanOrEqualTo(tester.view.physicalSize.width),
      );
    }
  });

  testWidgets('test_round_limit_field_build_property_no_problem_no_problem_'
      'text', (WidgetTester tester) async {
    final Random random = seededRandom(1190303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpRoundLimitField(tester, random: random, problem: null);

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(find.byType(FieldProblemText), findsNothing);
      expect(find.text(chooseRoundsProblem), findsNothing);
    }
  });
}
