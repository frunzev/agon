import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/repository/person_step_repository.dart';
import 'package:agent_orchestration/screens/shared/person_step_card.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../data/models/support/random_run_records.dart';
import '../../../support/app_harness.dart';
import '../../../support/random_inputs.dart';
import '../../../support/widget_harness.dart';

typedef SentAnswer = ({RunId runId, String stepName, String answer});

final class HeldPersonStepRepository extends ChangeNotifier
    implements PersonStepRepository {
  final List<SentAnswer> sentAnswers = <SentAnswer>[];
  Completer<void>? heldAnswer;
  Object? refusal;

  @override
  List<OpenPersonStep> listOpenPersonSteps() => const <OpenPersonStep>[];

  @override
  Future<void> answerPersonStep({
    required RunId runId,
    required String stepName,
    required String answer,
  }) async {
    sentAnswers.add((runId: runId, stepName: stepName, answer: answer));
    final Completer<void>? held = heldAnswer;
    if (held != null) {
      await held.future;
    }
    final Object? currentRefusal = refusal;
    if (currentRefusal != null) {
      Error.throwWithStackTrace(currentRefusal, StackTrace.current);
    }
  }
}

OpenPersonStep randomCardQuestion(Random random) {
  return OpenPersonStep(
    runId: RunId(randomHostileText(random)),
    taskId: TaskId(randomHostileText(random)),
    workspaceId: WorkspaceId(randomHostileText(random)),
    stepName: randomHostileText(random),
    question: randomHostileText(random),
    choices: <String>[
      for (final String choice in randomHostileTexts(random)) 'choice $choice',
    ],
    askedAt: random.nextBool() ? null : randomUtcMoment(random),
  );
}

PersonStepCard buildRandomCard(
  Random random,
  HeldPersonStepRepository repository,
) {
  return PersonStepCard(
    openStep: randomCardQuestion(random),
    incomingResults: randomRecordsOf(random, randomRunStep),
    contextLine: randomOptionalHostileText(random),
    personStepRepository: repository,
  );
}

double randomCardWidth(Random random) {
  return randomWidth(random, least: narrowestWidth, most: widestWidth);
}

Future<void> pumpCard(
  WidgetTester tester, {
  required double width,
  required PersonStepCard card,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScrollableAtWidth(tester, width: width, child: card);
}

Finder findWrittenAnswerField() {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is TextField &&
        widget.decoration?.hintText == writtenAnswerHint,
  );
}

Finder findCardButton(String label) {
  return find.widgetWithText(AppButton, label).first;
}

bool isCardButtonEnabled(WidgetTester tester, String label) {
  return tester.widget<AppButton>(findCardButton(label)).onPressed != null;
}

Future<void> tapCardButton(WidgetTester tester, String label) async {
  final Finder button = findCardButton(label);
  await tester.ensureVisible(button);
  await tester.tap(button);
}

Future<void> sendWrittenCardAnswer(WidgetTester tester, String answer) async {
  await tester.enterText(findWrittenAnswerField(), answer);
  await tapCardButton(tester, sendAnswerLabel);
  await pumpFrames(tester);
}

String readWrittenAnswer(WidgetTester tester) {
  final TextField field = tester.widget<TextField>(findWrittenAnswerField());
  return field.controller!.text;
}
