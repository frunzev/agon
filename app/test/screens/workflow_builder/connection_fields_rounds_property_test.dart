import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const List<int> _ruleRounds = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
const Offset _outsideTheMenu = Offset(1, 1);

void _ignoreRounds(int _) {}

String? _randomProblem(Random random) {
  return random.nextBool() ? null : '${randomText(random)} problem';
}

int? _randomLimit(Random random) {
  return random.nextInt(4) == 0 ? null : pickOne(random, _ruleRounds);
}

String _describeShownChoice(int? roundLimit) {
  if (roundLimit == null) {
    return chooseRoundsLabel;
  }
  return describeRoundLimitChoice(roundLimit);
}

Future<void> _openRoundsMenu(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButton<RoundLimitChoice>));
  await pumpFrames(tester);
}

void main() {
  test('test_round_limit_field_constructor_property_keeps_fields', () {
    final Random random = seededRandom(118104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int? roundLimit = _randomLimit(random);
      final String? problem = _randomProblem(random);

      final RoundLimitField field = RoundLimitField(
        roundLimit: roundLimit,
        problem: problem,
        onChanged: _ignoreRounds,
      );

      expect(field.roundLimit, roundLimit);
      expect(field.problem, problem);
      expect(identical(field.onChanged, _ignoreRounds), isTrue);
    }
  });

  test('test_round_limit_field_constructor_property_keeps_the_key', () {
    final Random random = seededRandom(118105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomText(random));

      final RoundLimitField field = RoundLimitField(
        key: key,
        roundLimit: _randomLimit(random),
        problem: null,
        onChanged: _ignoreRounds,
      );

      expect(field.key, key);
    }
  });

  test('test_round_limit_field_constructor_property_no_limit_is_kept', () {
    const RoundLimitField field = RoundLimitField(
      roundLimit: null,
      problem: null,
      onChanged: _ignoreRounds,
    );

    expect(field.roundLimit, isNull);
    expect(field.problem, isNull);
  });

  testWidgets('test_round_limit_field_build_property_shows_current_choice', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118106);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int? roundLimit = _randomLimit(random);
      final String? problem = _randomProblem(random);
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );

      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: RoundLimitField(
          roundLimit: roundLimit,
          problem: problem,
          onChanged: _ignoreRounds,
        ),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(find.text(roundsLabel), findsOneWidget);
      final DropdownButton<RoundLimitChoice> dropdown = tester.widget(
        find.byType(DropdownButton<RoundLimitChoice>),
      );
      expect(dropdown.value, RoundLimitChoice(roundLimit));
      expect(find.text(_describeShownChoice(roundLimit)), findsWidgets);
      if (problem != null) {
        expect(find.text(problem), findsOneWidget);
      }
    }
  });

  testWidgets('test_round_limit_field_build_property_menu_lists_rule_rounds', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118107);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int? roundLimit = _randomLimit(random);
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: RoundLimitField(
          roundLimit: roundLimit,
          problem: null,
          onChanged: _ignoreRounds,
        ),
      );

      await _openRoundsMenu(tester);

      final List<DropdownMenuItem<RoundLimitChoice>> items = tester
          .widget<DropdownButton<RoundLimitChoice>>(
            find.byType(DropdownButton<RoundLimitChoice>),
          )
          .items!;
      final List<int?> enabledRounds = <int?>[
        for (final DropdownMenuItem<RoundLimitChoice> item in items)
          if (item.enabled) item.value?.rounds,
      ];
      expect(enabledRounds, _ruleRounds);
      expect(find.text(describeRoundLimitChoice(1)), findsWidgets);
      expect(find.text(describeRoundLimitChoice(10)), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tapAt(_outsideTheMenu);
      await pumpFrames(tester);
    }
  });

  testWidgets('test_round_limit_field_build_property_problem_under_the_menu', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118108);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem = '${randomText(random)} problem';
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: RoundLimitField(
          roundLimit: _randomLimit(random),
          problem: problem,
          onChanged: _ignoreRounds,
        ),
      );

      final Rect menu = tester.getRect(
        find.byType(DropdownButton<RoundLimitChoice>),
      );
      final Rect shownProblem = tester.getRect(find.text(problem));
      expect(menu.bottom, lessThanOrEqualTo(shownProblem.top));
    }
  });

  testWidgets('test_choose_rounds_property_picked_round_is_reported_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118109);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<int> chosen = <int>[];
      final int? roundLimit = _randomLimit(random);
      final int picked = pickOne(random, _ruleRounds);
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: RoundLimitField(
          roundLimit: roundLimit,
          problem: null,
          onChanged: chosen.add,
        ),
      );

      await _openRoundsMenu(tester);
      await tester.tap(find.text(describeRoundLimitChoice(picked)).last);
      await pumpFrames(tester);

      expect(chosen, <int>[picked]);
    }
  });

  testWidgets('test_choose_rounds_property_prompt_is_never_reported', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118110);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<int> chosen = <int>[];
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: RoundLimitField(
          roundLimit: null,
          problem: null,
          onChanged: chosen.add,
        ),
      );

      await _openRoundsMenu(tester);
      await tester.tap(find.text(chooseRoundsLabel).last, warnIfMissed: false);
      await pumpFrames(tester);
      await tester.tapAt(_outsideTheMenu);
      await pumpFrames(tester);

      expect(chosen, isEmpty);
    }
  });

  testWidgets('test_choose_rounds_property_closing_the_menu_reports_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118111);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<int> chosen = <int>[];
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: RoundLimitField(
          roundLimit: _randomLimit(random),
          problem: null,
          onChanged: chosen.add,
        ),
      );

      await _openRoundsMenu(tester);
      await tester.tapAt(_outsideTheMenu);
      await pumpFrames(tester);

      expect(chosen, isEmpty);
      expect(find.byType(DropdownButton<RoundLimitChoice>), findsOneWidget);
    }
  });
}
