import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/rules/place_offers.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_runners.dart';
import '../models/support/random_run_records.dart';
import 'support/random_progress_runs.dart';

const List<StepStatus> _workingStatuses = <StepStatus>[
  StepStatus.running,
  StepStatus.waitingForApproval,
  StepStatus.waitingForPerson,
];
const List<StepStatus> _restingStatuses = <StepStatus>[
  StepStatus.waiting,
  StepStatus.done,
  StepStatus.failed,
  StepStatus.skipped,
];
const List<RunStatus> _finishedStatuses = <RunStatus>[
  RunStatus.failed,
  RunStatus.cancelled,
  RunStatus.done,
];

Runner _withOnline(Runner runner, {required bool online}) {
  return Runner(
    deviceId: runner.deviceId,
    labels: runner.labels,
    slotsTotal: runner.slotsTotal,
    slotsBusy: runner.slotsBusy,
    link: runner.link,
    online: online,
    acceptingNewRuns: runner.acceptingNewRuns,
    offers: runner.offers,
    allowedHosts: runner.allowedHosts,
  );
}

bool _isWaitingWithoutRunners(Run run) {
  return isWaitingForPlace(
    run: run,
    place: AgentPlace.values.first,
    runners: const <Runner>[],
  );
}

RunStep _insertedStep(
  Random random,
  StepStatus status, {
  required bool claimed,
}) {
  return buildProgressStep(
    template: randomRunStep(random),
    name: 'inserted step',
    runner: claimed ? holdingRunner : null,
    status: status,
  );
}

List<RunStep> _restingClaimedSteps(Random random) {
  final List<RunStep> steps = <RunStep>[];
  final int count = random.nextInt(largestProgressStepCount + 1);
  for (int i = 0; i < count; i += 1) {
    final StepStatus status = pickOne(random, _restingStatuses);
    final bool claimed = status == StepStatus.waiting || random.nextBool();
    steps.add(_insertedStep(random, status, claimed: claimed));
  }
  return steps;
}

List<RunStep> _insertRandomly(
  Random random,
  List<RunStep> steps,
  RunStep inserted,
) {
  final int position = random.nextInt(steps.length + 1);
  return <RunStep>[
    ...steps.sublist(0, position),
    inserted,
    ...steps.sublist(position),
  ];
}

void main() {
  test('test_is_place_offered_property_offline_runners_never_count', () {
    final Random random = seededRandom(87401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> offline = <Runner>[
        for (final Runner runner in randomRunners(random))
          _withOnline(runner, online: false),
      ];
      final AgentPlace place = pickOne(random, AgentPlace.values);

      expect(isPlaceOffered(place: place, runners: offline), isFalse);
    }
  });

  test('test_is_place_offered_property_more_runners_never_hide_a_place', () {
    final Random random = seededRandom(87402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);
      final List<Runner> more = <Runner>[...runners, ...randomRunners(random)];
      more.shuffle(random);
      final AgentPlace place = pickOne(random, AgentPlace.values);

      final bool isOffered = isPlaceOffered(place: place, runners: runners);
      final bool isOfferedByMore = isPlaceOffered(place: place, runners: more);

      expect(isOffered && !isOfferedByMore, isFalse);
    }
  });

  test('test_is_waiting_for_place_property_an_offered_place_never_waits', () {
    final Random random = seededRandom(87403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomProgressRun(random);
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final List<Runner> runners = <Runner>[
        ...randomRunners(random),
        buildOnlineRunnerOn(holdingRunner),
      ];

      final bool isWaiting = isWaitingForPlace(
        run: run,
        place: place,
        runners: runners,
      );

      expect(isWaiting, isFalse);
    }
  });

  test('test_is_waiting_for_place_property_finished_runs_never_wait', () {
    final Random random = seededRandom(87404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = buildProgressRun(
        random,
        status: pickOne(random, _finishedStatuses),
        steps: <RunStep>[
          ...randomProgressSteps(random),
          _insertedStep(random, StepStatus.waiting, claimed: false),
        ],
      );

      expect(_isWaitingWithoutRunners(run), isFalse);
    }
  });

  test('test_is_waiting_for_runner_property_working_step_means_no_wait', () {
    final Random random = seededRandom(87405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final StepStatus working = pickOne(random, _workingStatuses);
      final List<RunStep> steps = _insertRandomly(random, <RunStep>[
        ...randomProgressSteps(random),
        _insertedStep(random, StepStatus.waiting, claimed: false),
      ], _insertedStep(random, working, claimed: random.nextBool()));
      final Run run = buildProgressRun(
        random,
        status: pickOne(random, activeRunStatuses),
        steps: steps,
      );

      expect(_isWaitingWithoutRunners(run), isFalse);
    }
  });

  test('test_is_waiting_for_runner_property_needs_an_unclaimed_step', () {
    final Random random = seededRandom(87406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RunStep> claimedSteps = _restingClaimedSteps(random);
      final RunStatus status = pickOne(random, activeRunStatuses);
      final Run claimedRun = buildProgressRun(
        random,
        status: status,
        steps: claimedSteps,
      );
      final Run unclaimedRun = buildProgressRun(
        random,
        status: status,
        steps: _insertRandomly(
          random,
          claimedSteps,
          _insertedStep(random, StepStatus.waiting, claimed: false),
        ),
      );

      expect(_isWaitingWithoutRunners(claimedRun), isFalse);
      expect(_isWaitingWithoutRunners(unclaimedRun), isTrue);
    }
  });

  test('test_is_waiting_for_runner_property_step_order_never_matters', () {
    final Random random = seededRandom(87407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomProgressRun(random);
      final List<RunStep> shuffledSteps = List<RunStep>.of(run.steps);
      shuffledSteps.shuffle(random);
      final Run shuffled = buildProgressRun(
        random,
        status: run.status,
        steps: shuffledSteps,
      );

      final bool isWaiting = _isWaitingWithoutRunners(run);

      expect(_isWaitingWithoutRunners(shuffled), isWaiting);
    }
  });
}
