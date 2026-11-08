import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';

import '../../support/random_inputs.dart';
import 'support/contract_step_failures.dart';
import 'support/runner_contract_rigs.dart';

const String _typePrefix = 'test_runner_repository';
const int _longestSequence = 5;

typedef _Turn = Future<Runner> Function(RunnerRepository, DeviceId);

Future<Runner> _pause(RunnerRepository repository, DeviceId deviceId) {
  return repository.pauseRunner(deviceId);
}

Future<Runner> _resume(RunnerRepository repository, DeviceId deviceId) {
  return repository.resumeRunner(deviceId);
}

DeviceId _pickUnlistedRunnerId(Random random, RunnerContractWorld world) {
  final Set<String> listed = <String>{
    for (final Runner runner in world.rig.repository.listRunners())
      runner.deviceId.value,
  };
  final List<String> outside = <String>[
    for (final String deviceId in world.rig.node.device.runners.keys)
      if (!listed.contains(deviceId)) deviceId,
  ];
  if (outside.isEmpty || random.nextBool()) {
    return DeviceId('missing-${randomText(random)}');
  }
  return DeviceId(pickOne(random, outside));
}

Future<void> _expectTurnSetsOnlyThatRunner(
  Random random,
  _Turn turn, {
  required bool isAccepting,
}) async {
  final RunnerContractWorld world = await buildRunnerWorldAfterRandomSteps(
    random,
  );
  final DeviceId? deviceId = pickListedRunnerId(random, world);
  if (deviceId == null) {
    closeRunnerContractWorld(world);
    return;
  }

  for (final NamedRunnerRepository implementation in world.implementations) {
    final Runner before = implementation.repository.findRunner(deviceId);
    final Runner turned = await turn(implementation.repository, deviceId);
    expect(turned.acceptingNewRuns, isAccepting, reason: implementation.name);
    expect(turned.labels, before.labels, reason: implementation.name);
    expect(turned.slotsTotal, before.slotsTotal, reason: implementation.name);
    expect(
      implementation.repository.findRunner(deviceId).acceptingNewRuns,
      isAccepting,
    );
  }
  expectRunnersAgree(world);
  closeRunnerContractWorld(world);
}

Future<void> _expectTurnIdempotent(Random random, _Turn turn) async {
  final RunnerContractWorld world = await buildRunnerWorldAfterRandomSteps(
    random,
  );
  final DeviceId? deviceId = pickListedRunnerId(random, world);
  if (deviceId == null) {
    closeRunnerContractWorld(world);
    return;
  }

  for (final NamedRunnerRepository implementation in world.implementations) {
    await turn(implementation.repository, deviceId);
    final List<String> once = describeRunners(implementation.repository);
    await turn(implementation.repository, deviceId);
    expect(describeRunners(implementation.repository), once);
  }
  expectRunnersAgree(world);
  closeRunnerContractWorld(world);
}

Future<void> _expectUnlistedTurnRefused(Random random, _Turn turn) async {
  final RunnerContractWorld world = await buildRunnerContractWorld(random);
  final DeviceId deviceId = _pickUnlistedRunnerId(random, world);
  final Map<String, Object?>? storedBefore =
      world.rig.node.device.runners[deviceId.value];
  final String acceptingBefore = '${storedBefore?['accepting_new_runs']}';

  final List<RunnerStepOutcome> outcomes = await runOnRunnerRepositories(
    world,
    (RunnerRepository repository) => turn(repository, deviceId),
  );

  for (final RunnerStepOutcome outcome in outcomes) {
    expect(outcome.failure, isA<RecordNotFound>(), reason: '$outcome');
  }
  final Map<String, Object?>? storedAfter =
      world.rig.node.device.runners[deviceId.value];
  expect('${storedAfter?['accepting_new_runs']}', acceptingBefore);
  expectRunnersAgree(world);
  closeRunnerContractWorld(world);
}

void main() {
  test('${_typePrefix}_list_runners_property_every_implementation_lists_'
      'the_same_runners', () async {
    final Random random = seededRandom(85801);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      final RunnerContractWorld world = await buildRunnerContractWorld(random);
      expectRunnersAgree(world);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        await runRandomRunnerStep(random, world);
        expectRunnersAgree(world);
      }
      closeRunnerContractWorld(world);
    }
  });

  test('${_typePrefix}_list_runners_property_callers_cannot_change_the_'
      'listing', () async {
    final Random random = seededRandom(85802);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      final RunnerContractWorld world = await buildRunnerWorldAfterRandomSteps(
        random,
      );

      for (final NamedRunnerRepository implementation
          in world.implementations) {
        final List<Runner> listed = implementation.repository.listRunners();
        final List<String> before = describeRunners(implementation.repository);
        final Object? failure = await findStepFailure(
          () async => listed.clear(),
        );
        expect(failure, isA<UnsupportedError>(), reason: implementation.name);
        expect(describeRunners(implementation.repository), before);
      }
      closeRunnerContractWorld(world);
    }
  });

  test('${_typePrefix}_list_runners_property_lists_each_runner_'
      'once', () async {
    final Random random = seededRandom(85803);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      final RunnerContractWorld world = await buildRunnerWorldAfterRandomSteps(
        random,
      );

      for (final NamedRunnerRepository implementation
          in world.implementations) {
        final List<Runner> runners = implementation.repository.listRunners();
        final Set<DeviceId> deviceIds = <DeviceId>{
          for (final Runner runner in runners) runner.deviceId,
        };
        expect(deviceIds, hasLength(runners.length));
      }
      closeRunnerContractWorld(world);
    }
  });

  test('${_typePrefix}_find_runner_property_finds_every_listed_runner_as_'
      'listed', () async {
    final Random random = seededRandom(85804);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      final RunnerContractWorld world = await buildRunnerWorldAfterRandomSteps(
        random,
      );

      for (final NamedRunnerRepository implementation
          in world.implementations) {
        for (final Runner listed in implementation.repository.listRunners()) {
          final Runner found = implementation.repository.findRunner(
            listed.deviceId,
          );
          expect(describeRunner(found), describeRunner(listed));
        }
      }
      closeRunnerContractWorld(world);
    }
  });

  test('${_typePrefix}_find_runner_property_unknown_or_unlisted_runners_'
      'are_not_found', () async {
    final Random random = seededRandom(85805);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      final RunnerContractWorld world = await buildRunnerWorldAfterRandomSteps(
        random,
      );
      final DeviceId deviceId = _pickUnlistedRunnerId(random, world);

      for (final NamedRunnerRepository implementation
          in world.implementations) {
        final Object? failure = await findStepFailure(
          () async => implementation.repository.findRunner(deviceId),
        );
        expect(failure, isA<RecordNotFound>(), reason: implementation.name);
        expect((failure! as RecordNotFound).kind, runnerKind);
        expect((failure as RecordNotFound).identifier, deviceId.value);
      }
      closeRunnerContractWorld(world);
    }
  });

  test('${_typePrefix}_find_runner_property_every_implementation_finds_'
      'the_same_runner', () async {
    final Random random = seededRandom(85806);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      final RunnerContractWorld world = await buildRunnerWorldAfterRandomSteps(
        random,
      );
      final DeviceId? deviceId = pickListedRunnerId(random, world);
      if (deviceId == null) {
        closeRunnerContractWorld(world);
        continue;
      }
      final String expected = describeRunner(
        world.implementations.first.repository.findRunner(deviceId),
      );

      for (final NamedRunnerRepository implementation
          in world.implementations) {
        expect(
          describeRunner(implementation.repository.findRunner(deviceId)),
          expected,
          reason: implementation.name,
        );
      }
      closeRunnerContractWorld(world);
    }
  });

  test('${_typePrefix}_pause_runner_property_pauses_only_that_'
      'runner', () async {
    final Random random = seededRandom(85807);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      await _expectTurnSetsOnlyThatRunner(random, _pause, isAccepting: false);
    }
  });

  test('${_typePrefix}_pause_runner_property_is_idempotent', () async {
    final Random random = seededRandom(85808);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      await _expectTurnIdempotent(random, _pause);
    }
  });

  test('${_typePrefix}_pause_runner_property_unknown_or_unlisted_runners_'
      'are_refused_without_change', () async {
    final Random random = seededRandom(85809);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      await _expectUnlistedTurnRefused(random, _pause);
    }
  });

  test('${_typePrefix}_resume_runner_property_resumes_only_that_'
      'runner', () async {
    final Random random = seededRandom(85810);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      await _expectTurnSetsOnlyThatRunner(random, _resume, isAccepting: true);
    }
  });

  test('${_typePrefix}_resume_runner_property_is_idempotent', () async {
    final Random random = seededRandom(85811);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      await _expectTurnIdempotent(random, _resume);
    }
  });

  test('${_typePrefix}_resume_runner_property_unknown_or_unlisted_runners_'
      'are_refused_without_change', () async {
    final Random random = seededRandom(85812);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      await _expectUnlistedTurnRefused(random, _resume);
    }
  });
}
