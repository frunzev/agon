import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/screens/shared/person_step_card.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/person_step_dependencies.dart';
import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import 'support/run_page_retry_harness.dart';
import 'support/task_run_screen_scenes.dart';

const String _stepsTitle = 'Steps';
const int _longestWaitMinutes = 300;

OpenPersonStep _askAbout(Random random, Run run, RunStep step, int index) {
  final bool hasAskedTime = random.nextInt(4) != 0;
  final Duration waited = Duration(
    minutes: random.nextInt(_longestWaitMinutes),
  );
  return OpenPersonStep(
    runId: run.id,
    taskId: run.taskId,
    workspaceId: GalleryWorkspaceIds.acme,
    stepName: step.name,
    question: 'Question $index: ${randomWordPhrase(random)}?',
    choices: <String>[
      for (final String outcome in sampleOutcomes)
        if (random.nextBool()) outcome,
    ],
    askedAt: hasAskedTime ? galleryNow.subtract(waited) : null,
  );
}

List<OpenPersonStep> _randomQuestions(Random random, Run run) {
  final List<RunStep> asked = <RunStep>[
    for (final RunStep step in run.steps)
      if (random.nextBool()) step,
  ];
  return <OpenPersonStep>[
    for (int index = 0; index < asked.length; index += 1)
      _askAbout(random, run, asked[index], index),
  ];
}

typedef _QuestionScene = ({RunPageScene scene, List<OpenPersonStep> own});

_QuestionScene _randomQuestionScene(Random random) {
  final Run run = randomRunOfTask(
    random,
    task: pickOne(random, listGalleryWork()),
  );
  final List<OpenPersonStep> own = _randomQuestions(random, run);
  final RunPageScene scene = buildRunPageScene(
    run: run,
    openSteps: <OpenPersonStep>[galleryOpenQuestion, ...own],
    approvals: const <ApprovalRequest>[],
  );
  return (scene: scene, own: own);
}

Future<_QuestionScene> _openQuestionPage(
  WidgetTester tester,
  Random random,
) async {
  final _QuestionScene question = _randomQuestionScene(random);
  await openRunPage(
    tester,
    random: random,
    dependencies: question.scene.dependencies,
    runId: question.scene.run.id,
  );
  return question;
}

List<OpenPersonStep> _expectedCards(_QuestionScene question) {
  if (!isRunActive(question.scene.run)) {
    return const <OpenPersonStep>[];
  }
  return question.own;
}

void main() {
  testWidgets(
    'test_task_run_screen_build_question_card_property_card_per_question',
    (WidgetTester tester) async {
      final Random random = seededRandom(115701);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _QuestionScene question = await _openQuestionPage(
          tester,
          random,
        );

        final List<OpenPersonStep> expected = _expectedCards(question);
        final List<PersonStepCard> cards = tester
            .widgetList<PersonStepCard>(find.byType(PersonStepCard))
            .toList();
        expect(cards, hasLength(expected.length));
        for (int index = 0; index < cards.length; index += 1) {
          expect(identical(cards[index].openStep, expected[index]), isTrue);
        }
        expect(find.text(questionText), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'test_task_run_screen_build_question_card_property_shows_choices',
    (WidgetTester tester) async {
      final Random random = seededRandom(115702);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _QuestionScene question = await _openQuestionPage(
          tester,
          random,
        );

        for (final OpenPersonStep openStep in _expectedCards(question)) {
          final Finder card = find.byWidgetPredicate(
            (Widget widget) =>
                widget is PersonStepCard &&
                identical(widget.openStep, openStep),
          );
          expect(
            find.descendant(of: card, matching: find.text(openStep.question)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: card,
              matching: find.text(describeQuestionTitle(openStep.stepName)),
            ),
            findsOneWidget,
          );
          for (final String choice in openStep.choices) {
            expect(
              find.descendant(
                of: card,
                matching: find.widgetWithText(AppButton, choice),
              ),
              findsOneWidget,
            );
          }
        }
      }
    },
  );

  testWidgets(
    'test_task_run_screen_build_question_card_property_cards_sit_above_steps',
    (WidgetTester tester) async {
      final Random random = seededRandom(115703);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _QuestionScene question = await _openQuestionPage(
          tester,
          random,
        );

        final double stepsTop = tester.getTopLeft(find.text(_stepsTitle)).dy;
        double previousTop = double.negativeInfinity;
        for (final OpenPersonStep openStep in _expectedCards(question)) {
          final double top = tester
              .getTopLeft(find.text(openStep.question))
              .dy;
          expect(top, lessThan(stepsTop));
          expect(top, greaterThan(previousTop));
          previousTop = top;
        }
      }
    },
  );
}
