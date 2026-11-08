import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';

import '../../screens/support/planned_refusal.dart';
import '../../screens/support/refusing_place_repositories.dart';
import '../../support/random_inputs.dart';
import '../../support/recording_pairing_repository.dart';
import 'support/contract_step_failures.dart';
import 'support/pairing_contract_rigs.dart';

const String _typePrefix = 'test_pairing_repository';
const int _iterations = 8;
const int _largestStartDelaySeconds = 60;
const Duration _severalPolls = Duration(milliseconds: 10);

void main() {
  test('${_typePrefix}_find_active_session_property_no_session_before_'
      'any_start', () {
    final PairingContractWorld world = buildIdlePairingWorld();
    final List<PairingRepository> repositories = <PairingRepository>[
      for (final NamedPairingRepository implementation
          in world.implementations)
        implementation.repository,
      RecordingPairingRepository(hostingProblem: null),
    ];

    for (final PairingRepository repository in repositories) {
      expect(repository.findActiveSession(), isNull);
      expect(repository.findPendingRequest(), isNull);
    }
    closePairingWorld(world);
  });

  test('${_typePrefix}_find_active_session_property_shows_the_started_'
      'session_until_it_expires', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingContractWorld world = buildIdlePairingWorld();

      for (final NamedPairingRepository implementation
          in world.implementations) {
        final PairingSession started = await implementation.repository
            .startPairing();
        final PairingSession? shown = implementation.repository
            .findActiveSession();
        expect(shown?.code, started.code, reason: implementation.name);
        expect(shown?.expiresAt, started.expiresAt);
      }
      expirePairingCodes(world);
      for (final NamedPairingRepository implementation
          in world.implementations) {
        expect(
          implementation.repository.findActiveSession(),
          isNull,
          reason: implementation.name,
        );
      }
      closePairingWorld(world);
    }
  });

  test('${_typePrefix}_find_active_session_property_cancelling_ends_the_'
      'session', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingContractWorld world = buildIdlePairingWorld();
      await startPairingEverywhere(world);

      for (final NamedPairingRepository implementation
          in world.implementations) {
        await implementation.repository.cancelPairing();
        expect(
          implementation.repository.findActiveSession(),
          isNull,
          reason: implementation.name,
        );
      }
      closePairingWorld(world);
    }
  });

  test('${_typePrefix}_start_pairing_property_the_session_lives_from_'
      'now_on', () async {
    final Random random = seededRandom(85401);
    for (int i = 0; i < _iterations; i += 1) {
      final PairingContractWorld world = buildIdlePairingWorld();
      world.clock.moment = world.clock.moment.add(
        Duration(seconds: random.nextInt(_largestStartDelaySeconds)),
      );

      for (final NamedPairingRepository implementation
          in world.implementations) {
        final PairingSession started = await implementation.repository
            .startPairing();
        expect(started.expiresAt.isAfter(world.clock.now()), isTrue);
        expect(started.expiresAt.isAfter(started.createdAt), isTrue);
        expect(started.code.trim(), isNotEmpty, reason: implementation.name);
      }
      closePairingWorld(world);
    }
  });

  test('${_typePrefix}_start_pairing_property_starting_again_keeps_one_'
      'session_without_a_request', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingContractWorld world = await buildWaitingPairingWorld();

      for (final NamedPairingRepository implementation
          in world.implementations) {
        final PairingSession restarted = await implementation.repository
            .startPairing();
        expect(
          implementation.repository.findActiveSession()?.code,
          restarted.code,
          reason: implementation.name,
        );
        expect(
          implementation.repository.findPendingRequest(),
          isNull,
          reason: implementation.name,
        );
      }
      closePairingWorld(world);
    }
  });

  test('${_typePrefix}_start_pairing_property_a_refused_start_leaves_no_'
      'session', () async {
    final Random random = seededRandom(85402);
    for (int i = 0; i < _iterations; i += 1) {
      final PairingContractWorld world = buildIdlePairingWorld();
      final PlannedRefusal refusal = PlannedRefusal();
      final ExplainedRefusal planned = randomExplainedRefusal(random);
      refusal.problem = planned.problem;
      final RefusingPairingRepository refusing = RefusingPairingRepository(
        stored: buildContractFakePairing(
          clock: world.clock,
          session: null,
          request: null,
        ),
        refusal: refusal,
      );

      final Object? failure = await findStepFailure(refusing.startPairing);

      expect(failure, same(planned.problem));
      expect(refusing.findActiveSession(), isNull);
      expect(refusal.attempts, 1);
      closePairingWorld(world);
    }
  });

  test('${_typePrefix}_find_pending_request_property_shows_the_joining_'
      'device_only_while_the_code_lives', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingContractWorld world = await buildWaitingPairingWorld();

      for (final NamedPairingRepository implementation
          in world.implementations) {
        expect(
          implementation.repository.findPendingRequest(),
          isNotNull,
          reason: implementation.name,
        );
      }
      expirePairingCodes(world);
      for (final NamedPairingRepository implementation
          in world.implementations) {
        expect(
          implementation.repository.findPendingRequest(),
          isNull,
          reason: implementation.name,
        );
      }
      closePairingWorld(world);
    }
  });

  test('${_typePrefix}_find_pending_request_property_none_while_no_'
      'device_joins', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingContractWorld world = buildIdlePairingWorld();
      await startPairingEverywhere(world);
      await Future<void>.delayed(_severalPolls);

      for (final NamedPairingRepository implementation
          in world.implementations) {
        expect(
          implementation.repository.findPendingRequest(),
          isNull,
          reason: implementation.name,
        );
      }
      closePairingWorld(world);
    }
  });

  test('${_typePrefix}_find_pending_request_property_closing_the_session_'
      'forgets_the_request', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingContractWorld world = await buildWaitingPairingWorld();

      for (final NamedPairingRepository implementation
          in world.implementations) {
        await implementation.repository.rejectPairing();
        expect(
          implementation.repository.findPendingRequest(),
          isNull,
          reason: implementation.name,
        );
      }
      closePairingWorld(world);
    }
  });
}
