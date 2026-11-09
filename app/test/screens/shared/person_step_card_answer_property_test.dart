import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/shared/person_step_card.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../../support/widget_harness.dart';
import 'support/person_step_card_harness.dart';

const List<String> _lookAlikeCharacters = <String>['﻿', '​', '⁠', '᠎'];

String _randomLookAlikes(Random random) {
  final int count = 1 + random.nextInt(3);
  final StringBuffer lookAlikes = StringBuffer();
  for (int i = 0; i < count; i += 1) {
    lookAlikes.write(pickOne(random, _lookAlikeCharacters));
  }
  return lookAlikes.toString();
}

String _randomPadded(
  Random random,
  RuleTitleWhiteSpaceTable table,
  String core,
) {
  final String before = table.randomWhiteSpaceRun(random);
  final String after = table.randomWhiteSpaceRun(random);
  return '$before$core$after';
}

Future<HeldPersonStepRepository> _pumpHeldCard(
  WidgetTester tester,
  Random random, {
  required double width,
}) async {
  final HeldPersonStepRepository repository = HeldPersonStepRepository();
  await pumpCard(
    tester,
    width: width,
    card: buildRandomCard(random, repository),
  );
  return repository;
}

List<String> _listSentTexts(HeldPersonStepRepository repository) {
  return <String>[
    for (final SentAnswer sent in repository.sentAnswers) sent.answer,
  ];
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  testWidgets('test_send_written_answer_property_white_space_is_not_sent', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldPersonStepRepository repository = await _pumpHeldCard(
        tester,
        random,
        width: randomCardWidth(random),
      );

      await sendWrittenCardAnswer(tester, table.randomWhiteSpaceRun(random));

      expect(repository.sentAnswers, isEmpty);
      expect(find.text(emptyAnswerProblem), findsOneWidget);
    }
  });

  testWidgets('test_send_written_answer_property_sends_the_answer_trimmed', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldPersonStepRepository repository = await _pumpHeldCard(
        tester,
        random,
        width: randomCardWidth(random),
      );
      final String core = 'a${randomText(random)}z';

      await sendWrittenCardAnswer(tester, _randomPadded(random, table, core));

      expect(_listSentTexts(repository), <String>[core]);
      expect(find.text(emptyAnswerProblem), findsNothing);
    }
  });

  testWidgets('test_send_written_answer_property_look_alikes_are_not_blank', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldPersonStepRepository repository = await _pumpHeldCard(
        tester,
        random,
        width: randomCardWidth(random),
      );
      final String lookAlikes = _randomLookAlikes(random);

      await sendWrittenCardAnswer(
        tester,
        _randomPadded(random, table, lookAlikes),
      );

      expect(_listSentTexts(repository), <String>[lookAlikes]);
      expect(find.text(emptyAnswerProblem), findsNothing);
    }
  });

  testWidgets('test_send_written_answer_property_enter_sends_like_send', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldPersonStepRepository repository = await _pumpHeldCard(
        tester,
        random,
        width: desktopWidth,
      );
      final String core = 'a${randomText(random)}z';

      await tester.enterText(
        findWrittenAnswerField(),
        _randomPadded(random, table, core),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await pumpFrames(tester);

      expect(_listSentTexts(repository), <String>[core]);
    }
  });

  testWidgets('test_send_answer_property_double_submit_answers_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldPersonStepRepository repository = HeldPersonStepRepository();
      final Completer<void> slowNode = Completer<void>();
      repository.heldAnswer = slowNode;
      final PersonStepCard card = buildRandomCard(random, repository);
      await pumpCard(tester, width: randomCardWidth(random), card: card);
      await tester.enterText(findWrittenAnswerField(), 'answer $i');
      final String label = pickOne(random, <String>[
        sendAnswerLabel,
        ...card.openStep.choices,
      ]);

      await tapCardButton(tester, label);
      await tapCardButton(tester, label);
      slowNode.complete();
      await pumpFrames(tester);

      expect(repository.sentAnswers, hasLength(1));
    }
  });

  testWidgets('test_send_answer_property_controls_wait_for_the_node', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldPersonStepRepository repository = HeldPersonStepRepository();
      final Completer<void> slowNode = Completer<void>();
      repository.heldAnswer = slowNode;
      final PersonStepCard card = buildRandomCard(random, repository);
      await pumpCard(tester, width: randomCardWidth(random), card: card);
      final List<String> labels = <String>[
        sendAnswerLabel,
        ...card.openStep.choices,
      ];

      await sendWrittenCardAnswer(tester, 'answer $i');
      for (final String label in labels) {
        expect(isCardButtonEnabled(tester, label), isFalse);
      }
      slowNode.complete();
      await pumpFrames(tester);

      for (final String label in labels) {
        expect(isCardButtonEnabled(tester, label), isTrue);
      }
      expect(find.text(emptyAnswerProblem), findsNothing);
    }
  });

  testWidgets('test_send_answer_property_refusal_shows_and_keeps_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111607);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldPersonStepRepository repository = await _pumpHeldCard(
        tester,
        random,
        width: randomCardWidth(random),
      );
      final String problem = 'the answer ${randomText(random)} is refused';
      repository.refusal = PeopleFacingRefusal(problem);

      await sendWrittenCardAnswer(tester, 'answer $i');

      expect(find.text(describeAnswerProblem(problem)), findsOneWidget);
      expect(readWrittenAnswer(tester), 'answer $i');
      expect(isCardButtonEnabled(tester, sendAnswerLabel), isTrue);
    }
  });

  testWidgets('test_send_answer_property_next_answer_clears_the_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111608);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldPersonStepRepository repository = await _pumpHeldCard(
        tester,
        random,
        width: randomCardWidth(random),
      );
      repository.refusal = PeopleFacingRefusal('refused $i');
      await sendWrittenCardAnswer(tester, 'first $i');
      repository.refusal = null;

      await sendWrittenCardAnswer(tester, 'second $i');

      expect(find.text('Refused $i'), findsNothing);
      expect(_listSentTexts(repository), <String>['first $i', 'second $i']);
    }
  });
}
