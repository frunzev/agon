import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';

import '../../../screens/support/planned_refusal.dart';
import '../../../screens/support/refusing_work_repositories.dart';
import '../../../support/random_inputs.dart';
import '../../../support/runner_memberships.dart';
import '../../node_backed/support/runner_repository_rig.dart';
import 'contract_step_failures.dart';

const String runnerKind = 'runner';
const int runnerSequenceIterations = 25;
const int _longestSequence = 6;
const int _missingRunnerOdds = 5;

typedef NamedRunnerRepository = ({String name, RunnerRepository repository});

typedef RunnerStep = Future<Object?> Function(RunnerRepository repository);

typedef RunnerStepOutcome = ({String name, Object? failure});

typedef RunnerContractWorld = ({
  RunnerRig rig,
  List<NamedRunnerRepository> implementations,
});

FakeRunnerRepository _copyIntoFake(RunnerRepository loaded) {
  return buildMemberRunnerRepository(
    runners: loaded.listRunners(),
    offers: loaded.findThisDeviceOffers(),
    problem: loaded.findThisRunnerProblem(),
  );
}

Future<RunnerContractWorld> buildRunnerContractWorld(Random random) async {
  final RunnerRig rig = buildRunnerRig(random);
  await rig.repository.load();
  return (
    rig: rig,
    implementations: <NamedRunnerRepository>[
      (name: 'fake', repository: _copyIntoFake(rig.repository)),
      (name: 'node backed', repository: rig.repository),
      (
        name: 'refusing double',
        repository: RefusingRunnerRepository(
          stored: _copyIntoFake(rig.repository),
          refusal: PlannedRefusal(),
        ),
      ),
    ],
  );
}

String describeRunner(Runner runner) {
  return '${runner.deviceId.value} ${runner.acceptingNewRuns} '
      '${runner.online} ${runner.slotsBusy}/${runner.slotsTotal} '
      '${runner.labels} ${runner.offers} ${runner.link}';
}

List<String> describeRunners(RunnerRepository repository) {
  return <String>[
    for (final Runner runner in repository.listRunners())
      describeRunner(runner),
  ];
}

String describeThisDevice(RunnerRepository repository) {
  final List<PlaceOffer>? offers = repository.findThisDeviceOffers();
  final List<String>? offerTexts = offers == null
      ? null
      : <String>[
          for (final PlaceOffer offer in offers)
            '${offer.place.name}:${offer.problem}',
        ];
  return '$offerTexts ${repository.findThisRunnerProblem()}';
}

void expectRunnersAgree(RunnerContractWorld world) {
  final RunnerRepository first = world.implementations.first.repository;
  for (final NamedRunnerRepository implementation in world.implementations) {
    expect(
      describeRunners(implementation.repository),
      orderedEquals(describeRunners(first)),
      reason: implementation.name,
    );
    expect(
      describeThisDevice(implementation.repository),
      describeThisDevice(first),
      reason: implementation.name,
    );
  }
}

DeviceId pickRunnerId(Random random, RunnerContractWorld world) {
  final List<String> stored = world.rig.node.device.runners.keys.toList();
  if (stored.isEmpty || random.nextInt(_missingRunnerOdds) == 0) {
    return DeviceId('missing-${randomText(random)}');
  }
  return DeviceId(pickOne(random, stored));
}

DeviceId? pickListedRunnerId(Random random, RunnerContractWorld world) {
  final List<Runner> listed = world.rig.repository.listRunners();
  if (listed.isEmpty) {
    return null;
  }
  return pickOne(random, listed).deviceId;
}

List<AgentPlace> randomChosenPlaces(Random random) {
  return <AgentPlace>[
    for (final AgentPlace place in AgentPlace.values)
      if (random.nextBool()) place,
  ];
}

Future<List<RunnerStepOutcome>> runOnRunnerRepositories(
  RunnerContractWorld world,
  RunnerStep step,
) async {
  final List<RunnerStepOutcome> outcomes = <RunnerStepOutcome>[];
  for (final NamedRunnerRepository implementation in world.implementations) {
    final Object? failure = await findStepFailure(
      () => step(implementation.repository),
    );
    outcomes.add((name: implementation.name, failure: failure));
  }
  return outcomes;
}

void expectSameRunnerOutcome(
  List<RunnerStepOutcome> outcomes, {
  required String label,
}) {
  final bool isFirstRefused = outcomes.first.failure != null;
  for (final RunnerStepOutcome outcome in outcomes) {
    expect(outcome.failure != null, isFirstRefused, reason: '$label $outcome');
    if (outcome.failure != null) {
      final bool isExpected =
          isContractRefusal(outcome.failure) ||
          outcome.failure is RecordNotFound;
      expect(isExpected, isTrue, reason: '$label $outcome');
    }
  }
}

Future<void> runRandomRunnerStep(
  Random random,
  RunnerContractWorld world,
) async {
  final DeviceId deviceId = pickRunnerId(random, world);
  final List<AgentPlace> places = randomChosenPlaces(random);
  final List<({String label, RunnerStep step})> steps =
      <({String label, RunnerStep step})>[
        (
          label: 'pause ${deviceId.value}',
          step: (RunnerRepository runners) => runners.pauseRunner(deviceId),
        ),
        (
          label: 'resume ${deviceId.value}',
          step: (RunnerRepository runners) => runners.resumeRunner(deviceId),
        ),
        (
          label: 'choose $places',
          step: (RunnerRepository runners) =>
              runners.chooseAgentOffers(places),
        ),
      ];
  final ({String label, RunnerStep step}) chosen = pickOne(random, steps);
  final List<RunnerStepOutcome> outcomes = await runOnRunnerRepositories(
    world,
    chosen.step,
  );
  expectSameRunnerOutcome(outcomes, label: chosen.label);
}

Future<RunnerContractWorld> buildRunnerWorldAfterRandomSteps(
  Random random,
) async {
  final RunnerContractWorld world = await buildRunnerContractWorld(random);
  final int stepCount = random.nextInt(_longestSequence);
  for (int step = 0; step < stepCount; step += 1) {
    await runRandomRunnerStep(random, world);
  }
  return world;
}

void closeRunnerContractWorld(RunnerContractWorld world) {
  closeRunnerRig(world.rig);
}
