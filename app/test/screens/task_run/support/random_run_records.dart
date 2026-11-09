import 'dart:math';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/node_json_primitives.dart';
import '../../../support/random_inputs.dart';
import '../../../support/random_step_rounds.dart';

const List<String> _stepNames = <String>[
  'plan',
  'build-ios',
  'implement',
  'review-pr',
  'open-pr',
];
const String _strayStepName = 'removed-step';
const int _mostLogLines = 30;
const int _mostNotes = 6;
const int _mostRounds = 3;
const String _longLogWord = 'xcodebuild-archive-output ';

DeviceId? randomStepRunner(Random random, Device thisDevice) {
  return pickOne<DeviceId?>(random, <DeviceId?>[
    null,
    thisDevice.id,
    pickOne(random, galleryDevices).id,
    DeviceId(randomUuidText(random)),
  ]);
}

String randomLogText(Random random) {
  return pickOne(random, <String>[
    randomHostileText(random),
    randomText(random),
    _longLogWord * (20 + random.nextInt(200)),
  ]);
}

List<RunStep> _randomSteps(Random random, Device thisDevice) {
  final List<String> names = List<String>.of(_stepNames)..shuffle(random);
  final int count = 1 + random.nextInt(names.length);
  return <RunStep>[
    for (final String name in names.take(count))
      RunStep(
        name: name,
        agentId: null,
        runner: randomStepRunner(random, thisDevice),
        status: pickOne(random, StepStatus.values),
        startedAt: random.nextBool() ? randomUtcMoment(random) : null,
        finishedAt: random.nextBool() ? randomUtcMoment(random) : null,
        result: random.nextBool() ? randomHostileText(random) : null,
        outcome: null,
        loopSource: null,
        earlierRounds: randomEarlierRounds(
          random,
          random.nextInt(_mostRounds),
        ),
      ),
  ];
}

List<LogLine> _randomLog(Random random, List<RunStep> steps) {
  final int count = random.nextInt(_mostLogLines);
  final List<String> stepNames = <String>[
    for (final RunStep step in steps) step.name,
    _strayStepName,
  ];
  return <LogLine>[
    for (int i = 0; i < count; i += 1)
      LogLine(
        at: randomUtcMoment(random),
        stepName: pickOne(random, stepNames),
        text: randomLogText(random),
        isError: random.nextInt(4) == 0,
      ),
  ];
}

List<RunNote> randomRunNotes(Random random) {
  final int count = random.nextInt(_mostNotes);
  return <RunNote>[
    for (int i = 0; i < count; i += 1)
      RunNote(at: randomUtcMoment(random), text: randomLogText(random)),
  ];
}

Run randomRunRecord(Random random, {required Device thisDevice}) {
  final List<RunStep> steps = _randomSteps(random, thisDevice);
  return Run(
    id: RunId(randomUuidText(random)),
    taskId: TaskId(randomUuidText(random)),
    number: 1 + random.nextInt(99),
    status: pickOne(random, RunStatus.values),
    steps: steps,
    log: _randomLog(random, steps),
    chat: const <ChatMessage>[],
    failure: null,
    link: pickOne(random, RunnerLink.values),
    linkLostAt: null,
    agentSession: null,
    worktreeBranch: null,
    startedBy: thisDevice.id,
    startedAt: randomUtcMoment(random),
    finishedAt: null,
    loopRounds: const <LoopRounds>[],
    notes: randomRunNotes(random),
  );
}
