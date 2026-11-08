import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';

import '../../support/random_inputs.dart';
import 'support/runner_contract_rigs.dart';

const String _typePrefix = 'test_runner_repository';
const int _longestSequence = 5;

List<AgentPlace> _randomNonEmptyPlaces(Random random) {
  final List<AgentPlace> places = randomChosenPlaces(random);
  if (places.isEmpty) {
    return <AgentPlace>[pickOne(random, AgentPlace.values)];
  }
  return places;
}

List<AgentPlace> _listOfferedPlaces(RunnerRepository repository) {
  return <AgentPlace>[
    for (final PlaceOffer offer in repository.findThisDeviceOffers()!)
      offer.place,
  ];
}

void main() {
  test('${_typePrefix}_find_this_device_offers_property_every_'
      'implementation_offers_the_same_places', () async {
    final Random random = seededRandom(85821);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      final RunnerContractWorld world = await buildRunnerWorldAfterRandomSteps(
        random,
      );

      expectRunnersAgree(world);
      closeRunnerContractWorld(world);
    }
  });

  test('${_typePrefix}_find_this_device_offers_property_offers_each_place_'
      'at_most_once', () async {
    final Random random = seededRandom(85822);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      final RunnerContractWorld world = await buildRunnerWorldAfterRandomSteps(
        random,
      );

      for (final NamedRunnerRepository implementation
          in world.implementations) {
        if (implementation.repository.findThisDeviceOffers() == null) {
          continue;
        }
        final List<AgentPlace> offered = _listOfferedPlaces(
          implementation.repository,
        );
        expect(
          offered.toSet(),
          hasLength(offered.length),
          reason: implementation.name,
        );
      }
      closeRunnerContractWorld(world);
    }
  });

  test('${_typePrefix}_find_this_device_offers_property_choosing_offers_'
      'exactly_the_chosen_places', () async {
    final Random random = seededRandom(85823);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      final RunnerContractWorld world = await buildRunnerWorldAfterRandomSteps(
        random,
      );
      if (world.rig.repository.findThisDeviceOffers() == null) {
        closeRunnerContractWorld(world);
        continue;
      }
      final List<AgentPlace> chosen = _randomNonEmptyPlaces(random);

      for (final NamedRunnerRepository implementation
          in world.implementations) {
        await implementation.repository.chooseAgentOffers(chosen);
        expect(
          _listOfferedPlaces(implementation.repository).toSet(),
          chosen.toSet(),
          reason: implementation.name,
        );
      }
      expectRunnersAgree(world);
      closeRunnerContractWorld(world);
    }
  });

  test('${_typePrefix}_find_this_runner_problem_property_every_'
      'implementation_reports_the_same_problem', () async {
    final Random random = seededRandom(85824);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      final RunnerContractWorld world = await buildRunnerContractWorld(random);
      final int stepCount = random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        await runRandomRunnerStep(random, world);
        final String? expected = world.implementations.first.repository
            .findThisRunnerProblem();
        for (final NamedRunnerRepository implementation
            in world.implementations) {
          expect(
            implementation.repository.findThisRunnerProblem(),
            expected,
            reason: implementation.name,
          );
        }
      }
      closeRunnerContractWorld(world);
    }
  });

  test('${_typePrefix}_find_this_runner_problem_property_blocks_only_when_'
      'every_offer_has_a_problem', () async {
    final Random random = seededRandom(85825);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      final RunnerContractWorld world = await buildRunnerWorldAfterRandomSteps(
        random,
      );

      for (final NamedRunnerRepository implementation
          in world.implementations) {
        final List<PlaceOffer>? offers = implementation.repository
            .findThisDeviceOffers();
        final String? problem = implementation.repository
            .findThisRunnerProblem();
        if (offers == null || offers.isEmpty) {
          expect(problem, isNull, reason: implementation.name);
          continue;
        }
        final bool isEveryOfferBlocked = offers.every(
          (PlaceOffer offer) => offer.problem != null,
        );
        final String? expected = isEveryOfferBlocked
            ? offers.first.problem
            : null;
        expect(problem, expected, reason: implementation.name);
      }
      closeRunnerContractWorld(world);
    }
  });

  test('${_typePrefix}_find_this_runner_problem_property_choosing_keeps_'
      'each_place_problem', () async {
    final Random random = seededRandom(85826);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      final RunnerContractWorld world = await buildRunnerWorldAfterRandomSteps(
        random,
      );
      if (world.rig.repository.findThisDeviceOffers() == null) {
        closeRunnerContractWorld(world);
        continue;
      }
      final List<AgentPlace> chosen = _randomNonEmptyPlaces(random);

      for (final NamedRunnerRepository implementation
          in world.implementations) {
        final Map<AgentPlace, String?> problemsBefore = <AgentPlace, String?>{
          for (final PlaceOffer offer
              in implementation.repository.findThisDeviceOffers()!)
            offer.place: offer.problem,
        };
        await implementation.repository.chooseAgentOffers(chosen);
        for (final PlaceOffer offer
            in implementation.repository.findThisDeviceOffers()!) {
          expect(
            offer.problem,
            problemsBefore[offer.place],
            reason: implementation.name,
          );
        }
      }
      closeRunnerContractWorld(world);
    }
  });

  test('${_typePrefix}_choose_agent_offers_property_refuses_an_empty_'
      'choice_without_change', () async {
    final Random random = seededRandom(85827);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      final RunnerContractWorld world = await buildRunnerWorldAfterRandomSteps(
        random,
      );
      final String before = describeThisDevice(world.rig.repository);

      final List<RunnerStepOutcome> outcomes = await runOnRunnerRepositories(
        world,
        (RunnerRepository repository) =>
            repository.chooseAgentOffers(const <AgentPlace>[]),
      );

      for (final RunnerStepOutcome outcome in outcomes) {
        expect(outcome.failure, isA<StateError>(), reason: '$outcome');
      }
      expect(describeThisDevice(world.rig.repository), before);
      expectRunnersAgree(world);
      closeRunnerContractWorld(world);
    }
  });

  test('${_typePrefix}_choose_agent_offers_property_a_device_that_cannot_'
      'run_is_refused', () async {
    final Random random = seededRandom(85828);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      final RunnerContractWorld world = await buildRunnerContractWorld(random);
      final bool canRun = world.rig.repository.findThisDeviceOffers() != null;
      final List<AgentPlace> chosen = _randomNonEmptyPlaces(random);

      final List<RunnerStepOutcome> outcomes = await runOnRunnerRepositories(
        world,
        (RunnerRepository repository) => repository.chooseAgentOffers(chosen),
      );

      for (final RunnerStepOutcome outcome in outcomes) {
        expect(outcome.failure == null, canRun, reason: '$outcome');
      }
      expectRunnersAgree(world);
      closeRunnerContractWorld(world);
    }
  });

  test('${_typePrefix}_choose_agent_offers_property_choosing_twice_'
      'changes_nothing_more', () async {
    final Random random = seededRandom(85829);
    for (int i = 0; i < runnerSequenceIterations; i += 1) {
      final RunnerContractWorld world = await buildRunnerWorldAfterRandomSteps(
        random,
      );
      if (world.rig.repository.findThisDeviceOffers() == null) {
        closeRunnerContractWorld(world);
        continue;
      }
      final List<AgentPlace> chosen = _randomNonEmptyPlaces(random);

      for (final NamedRunnerRepository implementation
          in world.implementations) {
        await implementation.repository.chooseAgentOffers(chosen);
        final String once = describeThisDevice(implementation.repository);
        await implementation.repository.chooseAgentOffers(chosen);
        expect(describeThisDevice(implementation.repository), once);
      }
      expectRunnersAgree(world);
      closeRunnerContractWorld(world);
    }
  });
}
