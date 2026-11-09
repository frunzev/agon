import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/shared/person_step_card.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/random_inputs.dart';
import '../support/runner_settings_screen_checks.dart';
import 'support/person_step_card_harness.dart';

const int _resultMaximumLines = 8;

List<String> _readCardTexts(WidgetTester tester) {
  return readShownTexts(tester, find.byType(PersonStepCard));
}

List<String> _readButtonLabels(WidgetTester tester) {
  return <String>[
    for (final AppButton button in tester.widgetList<AppButton>(
      find.descendant(
        of: find.byType(PersonStepCard),
        matching: find.byType(AppButton),
      ),
    ))
      button.label,
  ];
}

Future<PersonStepCard> _pumpRandomCard(
  WidgetTester tester,
  Random random,
) async {
  final PersonStepCard card = buildRandomCard(
    random,
    HeldPersonStepRepository(),
  );
  await pumpCard(tester, width: randomCardWidth(random), card: card);
  return card;
}

void main() {
  testWidgets('test_person_step_card_build_property_fits_any_width', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111501);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PersonStepCard card = await _pumpRandomCard(tester, random);

      final List<String> texts = _readCardTexts(tester);
      expect(tester.takeException(), isNull);
      expect(texts, contains(describeQuestionTitle(card.openStep.stepName)));
      expect(texts, contains(card.openStep.question));
    }
  });

  testWidgets('test_person_step_card_build_property_context_line_leads', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PersonStepCard card = await _pumpRandomCard(tester, random);

      final List<String> texts = _readCardTexts(tester);
      final String? contextLine = card.contextLine;
      final List<String> expectedStart = <String>[
        ?contextLine,
        describeQuestionTitle(card.openStep.stepName),
        card.openStep.question,
      ];
      expect(texts.sublist(0, expectedStart.length), expectedStart);
    }
  });

  testWidgets('test_person_step_card_build_property_no_problem_at_first', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PersonStepCard card = await _pumpRandomCard(tester, random);

      final List<String> texts = _readCardTexts(tester);
      final int expectedCount =
          (card.contextLine == null ? 0 : 1) +
          2 +
          (card.incomingResults.isEmpty
              ? 0
              : 1 + 2 * card.incomingResults.length) +
          card.openStep.choices.length +
          2;
      expect(texts, hasLength(expectedCount));
      expect(texts, isNot(contains(emptyAnswerProblem)));
    }
  });

  testWidgets('test_build_incoming_results_property_label_only_with_results', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PersonStepCard card = await _pumpRandomCard(tester, random);

      final bool showsLabel = _readCardTexts(tester).contains(whatCameInLabel);

      expect(showsLabel, card.incomingResults.isNotEmpty);
    }
  });

  testWidgets('test_build_incoming_results_property_each_step_in_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PersonStepCard card = await _pumpRandomCard(tester, random);
      if (card.incomingResults.isEmpty) {
        continue;
      }

      final List<String> texts = _readCardTexts(tester);
      final int labelIndex = texts.indexOf(whatCameInLabel);
      final List<String> expected = <String>[
        for (final RunStep step in card.incomingResults) ...<String>[
          step.name,
          step.result ?? '',
        ],
      ];
      expect(
        texts.sublist(labelIndex + 1, labelIndex + 1 + expected.length),
        expected,
      );
    }
  });

  testWidgets('test_build_incoming_results_property_long_results_are_cut', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PersonStepCard card = await _pumpRandomCard(tester, random);

      final List<Text> resultTexts = <Text>[
        for (final Text text in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(PersonStepCard),
            matching: find.byType(Text),
          ),
        ))
          if (text.maxLines != null && text.data != writtenAnswerHint) text,
      ];
      expect(resultTexts, hasLength(card.incomingResults.length));
      for (final Text text in resultTexts) {
        expect(text.maxLines, _resultMaximumLines);
        expect(text.overflow, TextOverflow.ellipsis);
      }
    }
  });

  testWidgets('test_build_choice_buttons_property_one_button_per_choice', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111507);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PersonStepCard card = await _pumpRandomCard(tester, random);

      expect(_readButtonLabels(tester), <String>[
        ...card.openStep.choices,
        sendAnswerLabel,
      ]);
    }
  });

  testWidgets('test_build_choice_buttons_property_choice_sends_itself', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111508);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldPersonStepRepository repository = HeldPersonStepRepository();
      final PersonStepCard card = buildRandomCard(random, repository);
      if (card.openStep.choices.isEmpty) {
        continue;
      }
      await pumpCard(tester, width: randomCardWidth(random), card: card);
      final String choice = pickOne(random, card.openStep.choices);

      await tapCardButton(tester, choice);
      await tester.pump();

      expect(repository.sentAnswers, <SentAnswer>[
        (
          runId: card.openStep.runId,
          stepName: card.openStep.stepName,
          answer: choice,
        ),
      ]);
    }
  });

  testWidgets('test_build_choice_buttons_property_wrap_inside_the_card', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111509);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PersonStepCard card = await _pumpRandomCard(tester, random);

      final Rect cardBox = tester.getRect(find.byType(PersonStepCard));
      for (final String choice in card.openStep.choices) {
        final Rect buttonBox = tester.getRect(findCardButton(choice));
        expect(buttonBox.left, greaterThanOrEqualTo(cardBox.left));
        expect(buttonBox.right, lessThanOrEqualTo(cardBox.right + 0.01));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_build_written_answer_property_field_and_send_button', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111510);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpRandomCard(tester, random);

      final AppButton send = tester.widget<AppButton>(
        findCardButton(sendAnswerLabel),
      );
      expect(findWrittenAnswerField(), findsOneWidget);
      expect(send.icon, AppIconKind.send);
      expect(send.onPressed, isNotNull);
    }
  });

  testWidgets('test_build_written_answer_property_send_sits_after_field', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111511);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpRandomCard(tester, random);

      final Rect fieldBox = tester.getRect(findWrittenAnswerField());
      final Rect sendBox = tester.getRect(findCardButton(sendAnswerLabel));
      final Rect cardBox = tester.getRect(find.byType(PersonStepCard));
      expect(sendBox.left, greaterThanOrEqualTo(fieldBox.right));
      expect(sendBox.right, lessThanOrEqualTo(cardBox.right + 0.01));
      expect(sendBox.bottom, closeTo(fieldBox.bottom, 1));
    }
  });

  testWidgets('test_build_written_answer_property_typing_keeps_the_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111512);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldPersonStepRepository repository = HeldPersonStepRepository();
      await pumpCard(
        tester,
        width: randomCardWidth(random),
        card: buildRandomCard(random, repository),
      );
      final String typed = randomText(random);

      await tester.enterText(findWrittenAnswerField(), typed);
      await tester.pump();

      expect(readWrittenAnswer(tester), typed);
      expect(repository.sentAnswers, isEmpty);
    }
  });
}
