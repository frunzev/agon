import 'dart:math';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import 'random_branching_workflows.dart';
import 'random_inputs.dart';

const int _longestRoundSeconds = 4000;

EarlierRound randomEarlierRound(Random random) {
  final DateTime startedAt = randomUtcMoment(random);
  final Duration roundLength = Duration(
    seconds: random.nextInt(_longestRoundSeconds),
  );
  final bool hasTimes = random.nextInt(4) != 0;

  return EarlierRound(
    status: pickOne(random, StepStatus.values),
    startedAt: hasTimes ? startedAt : null,
    finishedAt: hasTimes ? startedAt.add(roundLength) : null,
    result: random.nextBool() ? randomWordPhrase(random) : null,
    outcome: random.nextBool() ? pickOne(random, sampleOutcomes) : null,
  );
}

List<EarlierRound> randomEarlierRounds(Random random, int count) {
  return <EarlierRound>[
    for (int i = 0; i < count; i += 1) randomEarlierRound(random),
  ];
}

RunStep buildAgentRunStep({
  required WorkflowAgent agent,
  required String? loopSource,
  required List<EarlierRound> earlierRounds,
  required String? result,
}) {
  return RunStep(
    name: agent.name,
    agentId: agent.id,
    runner: null,
    status: result == null ? StepStatus.waiting : StepStatus.done,
    startedAt: null,
    finishedAt: null,
    result: result,
    outcome: null,
    loopSource: loopSource,
    earlierRounds: earlierRounds,
  );
}
