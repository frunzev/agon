import 'dart:math';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/step_round_text.dart';

import '../../../support/random_branching_workflows.dart';
import '../../../support/random_inputs.dart';
import '../../../support/random_step_rounds.dart';

const int _mostUnlimitedEarlierRounds = 3;
const int _longestStepSeconds = 5000;
const int _longestRunSeconds = 90000;
const int _largestRunNumber = 500;
const int _largestNoteCount = 3;
const String oneAgentStepName = 'claude-code';
const List<DeviceId> shownRunners = <DeviceId>[
  GalleryDeviceIds.macStudio,
  GalleryDeviceIds.officeServer,
  GalleryDeviceIds.gpuBox,
];
const List<RunStatus> _finishedRunStatuses = <RunStatus>[
  RunStatus.failed,
  RunStatus.cancelled,
  RunStatus.done,
];

typedef StepTimes = ({DateTime? startedAt, DateTime? finishedAt});

DateTime _randomMomentBefore(Random random, DateTime now, int mostSeconds) {
  return now.subtract(Duration(seconds: 1 + random.nextInt(mostSeconds)));
}

DateTime _randomMomentBetween(Random random, DateTime from, DateTime to) {
  final int spanSeconds = to.difference(from).inSeconds;
  return from.add(Duration(seconds: random.nextInt(spanSeconds + 1)));
}

StepTimes randomStepTimes(Random random, StepStatus status, DateTime now) {
  final DateTime startedAt = _randomMomentBefore(
    random,
    now,
    _longestStepSeconds,
  );
  final DateTime finishedAt = _randomMomentBetween(random, startedAt, now);
  switch (status) {
    case StepStatus.waiting:
      return (startedAt: null, finishedAt: null);
    case StepStatus.running:
    case StepStatus.waitingForApproval:
    case StepStatus.waitingForPerson:
      return (startedAt: startedAt, finishedAt: null);
    case StepStatus.done:
    case StepStatus.failed:
      return (startedAt: startedAt, finishedAt: finishedAt);
    case StepStatus.skipped:
      if (random.nextBool()) {
        return (startedAt: null, finishedAt: null);
      }
      return (startedAt: startedAt, finishedAt: finishedAt);
  }
}

int randomEarlierRoundCount(
  Random random, {
  required WorkflowAgent agent,
  required Workflow workflow,
}) {
  final RunStep probe = buildAgentRunStep(
    agent: agent,
    loopSource: null,
    earlierRounds: const <EarlierRound>[],
    result: null,
  );
  final int? roundLimit = findStepRoundLimit(step: probe, workflow: workflow);
  final int mostRounds = roundLimit ?? _mostUnlimitedEarlierRounds;
  return random.nextInt(mostRounds + 1);
}

RunStep randomShownStep(
  Random random, {
  required String name,
  required WorkflowAgentId? agentId,
  required bool isPerson,
  required int earlierRoundCount,
  required DateTime now,
}) {
  final StepStatus status = pickOne(random, StepStatus.values);
  final StepTimes times = randomStepTimes(random, status, now);
  final bool hasRunner = !isPerson && times.startedAt != null;

  return RunStep(
    name: name,
    agentId: agentId,
    runner: hasRunner ? pickOne(random, shownRunners) : null,
    status: status,
    startedAt: times.startedAt,
    finishedAt: times.finishedAt,
    result: random.nextBool() ? randomWordPhrase(random) : null,
    outcome: random.nextBool() ? pickOne(random, sampleOutcomes) : null,
    loopSource: null,
    earlierRounds: randomEarlierRounds(random, earlierRoundCount),
  );
}

List<RunStep> randomStepsOfWorkflow(
  Random random, {
  required Workflow workflow,
  required DateTime now,
}) {
  return <RunStep>[
    for (final WorkflowAgent agent in workflow.agents)
      randomShownStep(
        random,
        name: agent.name,
        agentId: agent.id,
        isPerson: agent.stepKind == StepKind.person,
        earlierRoundCount: randomEarlierRoundCount(
          random,
          agent: agent,
          workflow: workflow,
        ),
        now: now,
      ),
  ];
}

List<RunStep> randomOneAgentSteps(Random random, DateTime now) {
  return <RunStep>[
    randomShownStep(
      random,
      name: oneAgentStepName,
      agentId: null,
      isPerson: false,
      earlierRoundCount: 0,
      now: now,
    ),
  ];
}

Workflow randomWorkflowWithAgents(Random random) {
  while (true) {
    final Workflow workflow = randomBranchingWorkflow(random);
    if (workflow.agents.isNotEmpty) {
      return workflow;
    }
  }
}

RunFailure? _randomFailure(
  Random random,
  RunStatus status,
  List<RunStep> steps,
) {
  if (status != RunStatus.failed || random.nextInt(4) == 0) {
    return null;
  }
  return RunFailure(
    stepName: pickOne(random, steps).name,
    runner: random.nextBool() ? pickOne(random, shownRunners) : null,
    reason: 'failed: ${randomWordPhrase(random)}',
    retryRunsOnSameRunner: random.nextBool(),
  );
}

List<RunNote> randomRunNotes(Random random, DateTime now) {
  final int count = random.nextInt(_largestNoteCount + 1);
  return <RunNote>[
    for (int i = 0; i < count; i += 1)
      RunNote(
        at: _randomMomentBefore(random, now, _longestStepSeconds),
        text: 'note $i ${randomWordPhrase(random)}',
      ),
  ];
}

Run buildShownRun(
  Random random, {
  required RunId runId,
  required TaskId taskId,
  required List<RunStep> steps,
  required DateTime now,
}) {
  final RunStatus status = pickOne(random, RunStatus.values);
  final DateTime startedAt = _randomMomentBefore(
    random,
    now,
    _longestRunSeconds,
  );
  final bool isFinished = _finishedRunStatuses.contains(status);

  return Run(
    id: runId,
    taskId: taskId,
    number: 1 + random.nextInt(_largestRunNumber),
    status: status,
    steps: steps,
    log: const <LogLine>[],
    chat: const <ChatMessage>[],
    failure: _randomFailure(random, status, steps),
    link: pickOne(random, RunnerLink.values),
    linkLostAt: null,
    agentSession: null,
    worktreeBranch: null,
    startedBy: GalleryDeviceIds.airLaptop,
    startedAt: startedAt,
    finishedAt: isFinished
        ? _randomMomentBetween(random, startedAt, now)
        : null,
    loopRounds: const <LoopRounds>[],
    notes: randomRunNotes(random, now),
  );
}
