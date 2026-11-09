import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/shared/person_step_card.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'support/person_step_card_harness.dart';

void main() {
  test('test_person_step_card_create_state_property_fresh_every_call', () {
    final Random random = seededRandom(111410);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PersonStepCard card = buildRandomCard(
        random,
        HeldPersonStepRepository(),
      );
      final int count = 2 + random.nextInt(4);

      final Set<State<PersonStepCard>> states = <State<PersonStepCard>>{
        for (int index = 0; index < count; index += 1) card.createState(),
      };

      expect(states, hasLength(count));
    }
  });

  testWidgets('test_person_step_card_create_state_property_starts_idle', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111411);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PersonStepCard card = buildRandomCard(
        random,
        HeldPersonStepRepository(),
      );

      await pumpCard(tester, width: randomCardWidth(random), card: card);

      expect(readWrittenAnswer(tester), isEmpty);
      expect(find.text(emptyAnswerProblem), findsNothing);
      expect(isCardButtonEnabled(tester, sendAnswerLabel), isTrue);
      for (final String choice in card.openStep.choices) {
        expect(isCardButtonEnabled(tester, choice), isTrue);
      }
    }
  });

  testWidgets('test_person_step_card_create_state_property_new_key_forgets', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111412);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldPersonStepRepository repository = HeldPersonStepRepository();
      final double width = randomCardWidth(random);
      final PersonStepCard first = buildRandomCard(random, repository);
      await pumpCard(tester, width: width, card: first);
      await tester.enterText(findWrittenAnswerField(), 'typed $i');

      final PersonStepCard second = PersonStepCard(
        key: ValueKey<int>(i),
        openStep: randomCardQuestion(random),
        incomingResults: first.incomingResults,
        contextLine: first.contextLine,
        personStepRepository: repository,
      );
      await pumpCard(tester, width: width, card: second);

      expect(readWrittenAnswer(tester), isEmpty);
    }
  });

  testWidgets('test_person_step_card_dispose_property_late_answers_are_calm', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111413);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldPersonStepRepository repository = HeldPersonStepRepository();
      final Completer<void> slowNode = Completer<void>();
      repository.heldAnswer = slowNode;
      final PersonStepCard card = buildRandomCard(random, repository);
      await pumpCard(tester, width: randomCardWidth(random), card: card);
      await sendWrittenCardAnswer(tester, 'answer $i');

      await tester.pumpWidget(const SizedBox.shrink());
      repository.refusal = random.nextBool()
          ? PeopleFacingRefusal(randomHostileText(random))
          : null;
      slowNode.complete();
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(repository.sentAnswers, hasLength(1));
    }
  });

  testWidgets('test_person_step_card_dispose_property_unmount_while_typing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111414);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldPersonStepRepository repository = HeldPersonStepRepository();
      final PersonStepCard card = buildRandomCard(random, repository);
      await pumpCard(tester, width: randomCardWidth(random), card: card);
      await tester.enterText(findWrittenAnswerField(), randomText(random));

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(repository.sentAnswers, isEmpty);
    }
  });

  testWidgets('test_person_step_card_dispose_property_remount_starts_over', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111415);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldPersonStepRepository repository = HeldPersonStepRepository();
      repository.refusal = PeopleFacingRefusal('refused $i');
      final double width = randomCardWidth(random);
      final PersonStepCard card = buildRandomCard(random, repository);
      await pumpCard(tester, width: width, card: card);
      await sendWrittenCardAnswer(tester, 'answer $i');
      expect(find.text('Refused $i'), findsOneWidget);

      await pumpCard(tester, width: width, card: card);

      expect(find.text('Refused $i'), findsNothing);
      expect(isCardButtonEnabled(tester, sendAnswerLabel), isTrue);
    }
  });
}
