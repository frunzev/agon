import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/run_step_progress.dart';
import 'package:agent_orchestration/screens/shared/person_step_card.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/task_repositories.dart';
import 'support/person_step_card_harness.dart';

const String _missingStepStart = 'No open person step with id ';

OpenPersonStep _randomQuestionOnRun(Random random, Run run, int index) {
  return OpenPersonStep(
    runId: run.id,
    taskId: run.taskId,
    workspaceId: GalleryWorkspaceIds.acme,
    stepName: 'step-$index',
    question: randomHostileText(random),
    choices: <String>[
      for (final String choice in randomHostileTexts(random)) 'pick $choice',
    ],
    askedAt: null,
  );
}

void main() {
  final List<Run> finishedRuns = <Run>[
    for (final Run run in galleryRuns)
      if (isRunFinished(run.status)) run,
  ];

  testWidgets('test_send_answer_property_finished_runs_refuse_answers', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final OpenPersonStep openStep = _randomQuestionOnRun(
        random,
        pickOne(random, finishedRuns),
        i,
      );
      final FakePersonStepRepository repository = FakePersonStepRepository(
        openSteps: <OpenPersonStep>[openStep],
        taskRepository: buildGalleryTaskRepository(),
      );
      await pumpCard(
        tester,
        width: randomCardWidth(random),
        card: PersonStepCard(
          openStep: openStep,
          incomingResults: const <RunStep>[],
          contextLine: null,
          personStepRepository: repository,
        ),
      );
      final String label = pickOne(random, <String>[
        sendAnswerLabel,
        ...openStep.choices,
      ]);

      await tester.enterText(findWrittenAnswerField(), 'answer $i');
      await tapCardButton(tester, label);
      await pumpFrames(tester);

      expect(find.text('${_missingStepStart}step-$i'), findsOneWidget);
      expect(isCardButtonEnabled(tester, sendAnswerLabel), isTrue);
      expect(repository.listOpenPersonSteps(), isEmpty);
    }
  });
}
