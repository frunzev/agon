import 'dart:math';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/person_step_repository.dart';

import '../../../support/random_inputs.dart';
import '../../fakes/support/person_step_inputs.dart';
import '../../fakes/support/person_step_rigs.dart';
import '../../fakes/support/person_step_runs.dart';
import '../../node_backed/support/simulated_node_replies.dart';
import '../../node_backed/support/simulated_person_step_node.dart';

const int _largestStepCount = 6;
const String unmatchedAnswerStart = 'none of them';
const int _largestUnmatchedNumber = 99;
const int _closedStepOdds = 4;
const int _answerKindCount = 3;

typedef NamedPersonStepRepository = ({
  String name,
  PersonStepRepository repository,
});

typedef PersonStepKey = ({String runId, String stepName});

typedef PersonStepContractWorld = ({
  List<NamedPersonStepRepository> implementations,
  List<OpenPersonStep> askedSteps,
});

Future<PersonStepContractWorld> buildPersonStepWorld(Random random) async {
  final SimulatedPersonStepNode simulated = SimulatedPersonStepNode();
  final int count = 1 + random.nextInt(_largestStepCount);
  for (int i = 0; i < count; i += 1) {
    simulated.askFromElsewhere(random);
    simulated.openSteps.last['choices'] = randomStepChoices(random);
  }
  final NodeBackedPersonStepRepository nodeBacked =
      NodeBackedPersonStepRepository(
        channel: buildSimulatedChannel(simulated.answer),
      );
  await nodeBacked.load();
  final List<OpenPersonStep> everyStep = nodeBacked.listOpenPersonSteps();

  final FakeTaskRepository taskRepository = buildRunsAskingSteps(
    random,
    everyStep,
  );
  for (final RunId runId in pickRandomRuns(
    random,
    listStepRunIds(everyStep),
  )) {
    await taskRepository.cancelRun(runId);
    simulated.finishedRunIds.add(runId.value);
  }
  await nodeBacked.load();

  final FakePersonStepRepository fake = FakePersonStepRepository(
    openSteps: everyStep,
    taskRepository: taskRepository,
  );
  return (
    implementations: <NamedPersonStepRepository>[
      (name: 'fake', repository: fake),
      (name: 'node backed', repository: nodeBacked),
    ],
    askedSteps: everyStep,
  );
}

List<PersonStepKey> describePersonSteps(List<OpenPersonStep> openSteps) {
  return <PersonStepKey>[
    for (final OpenPersonStep openStep in openSteps)
      (runId: openStep.runId.value, stepName: openStep.stepName),
  ];
}

List<PersonStepKey> describeListedSteps(PersonStepRepository repository) {
  return describePersonSteps(repository.listOpenPersonSteps());
}

OpenPersonStep pickAskedStep(Random random, PersonStepContractWorld world) {
  final List<OpenPersonStep> listed = world.implementations.first.repository
      .listOpenPersonSteps();
  if (listed.isEmpty || random.nextInt(_closedStepOdds) == 0) {
    return pickOne(random, world.askedSteps);
  }
  return pickOne(random, listed);
}

String pickAnyAnswer(Random random, OpenPersonStep openStep) {
  return switch (random.nextInt(_answerKindCount)) {
    0 => pickMatchingAnswer(random, openStep),
    1 => '$unmatchedAnswerStart ${random.nextInt(_largestUnmatchedNumber)}',
    _ => pickOne(random, blankPersonAnswers),
  };
}
