import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/pairing_inputs.dart';
import 'support/contract_step_failures.dart';
import 'support/pairing_contract_rigs.dart';

const String _typePrefix = 'test_pairing_repository';
const int _iterations = 8;

typedef _PairingDecision = Future<Object?> Function(PairingRepository);

Future<Object?> _approve(PairingRepository repository) {
  return repository.approvePairing(approverWorkspaceIds);
}

Future<Object?> _reject(PairingRepository repository) {
  return repository.rejectPairing();
}

Future<Object?> _cancel(PairingRepository repository) {
  return repository.cancelPairing();
}

Future<void> _expectRefusedWith(
  PairingContractWorld world,
  _PairingDecision decide, {
  required String message,
}) async {
  for (final NamedPairingRepository implementation in world.implementations) {
    final PairingSession? before = implementation.repository
        .findActiveSession();
    final Object? failure = await findStepFailure(
      () => decide(implementation.repository),
    );

    expect(failure, isA<StateError>(), reason: implementation.name);
    expect((failure! as StateError).message, message);
    expect(
      implementation.repository.findActiveSession()?.code,
      before?.code,
      reason: implementation.name,
    );
  }
}

Future<void> _expectSessionClosedBy(_PairingDecision decide) async {
  final PairingContractWorld world = await buildWaitingPairingWorld();
  for (final NamedPairingRepository implementation in world.implementations) {
    await decide(implementation.repository);
    expect(
      implementation.repository.findActiveSession(),
      isNull,
      reason: implementation.name,
    );
    expect(implementation.repository.findPendingRequest(), isNull);
  }
  closePairingWorld(world);
}

void main() {
  test('${_typePrefix}_approve_pairing_property_refuses_an_empty_'
      'workspace_choice', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingContractWorld world = await buildWaitingPairingWorld();

      for (final NamedPairingRepository implementation
          in world.implementations) {
        final Object? failure = await findStepFailure(
          () =>
              implementation.repository.approvePairing(const <WorkspaceId>[]),
        );
        expect(failure, isA<ArgumentError>(), reason: implementation.name);
        expect(implementation.repository.findPendingRequest(), isNotNull);
      }
      closePairingWorld(world);
    }
  });

  test('${_typePrefix}_approve_pairing_property_refuses_without_a_'
      'waiting_device_or_a_live_code', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingContractWorld world = buildIdlePairingWorld();
      await _expectRefusedWith(
        world,
        _approve,
        message: noDeviceWaitingToPair,
      );
      await startPairingEverywhere(world);
      await _expectRefusedWith(
        world,
        _approve,
        message: noDeviceWaitingToPair,
      );
      expirePairingCodes(world);
      await _expectRefusedWith(world, _approve, message: noShowingPairingCode);
      closePairingWorld(world);
    }
  });

  test('${_typePrefix}_approve_pairing_property_pairs_the_waiting_device_'
      'and_closes_the_session', () async {
    final Random random = seededRandom(85411);
    for (int i = 0; i < _iterations; i += 1) {
      final PairingContractWorld world = await buildWaitingPairingWorld();
      final List<WorkspaceId> chosen = randomApproverWorkspaces(random);

      for (final NamedPairingRepository implementation
          in world.implementations) {
        final PairingRequest request = implementation.repository
            .findPendingRequest()!;
        final Device paired = await implementation.repository.approvePairing(
          chosen,
        );
        expect(paired.name, request.deviceName, reason: implementation.name);
        expect(paired.revoked, isFalse, reason: implementation.name);
        expect(implementation.repository.findActiveSession(), isNull);
        expect(implementation.repository.findPendingRequest(), isNull);
      }
      closePairingWorld(world);
    }
  });

  test('${_typePrefix}_reject_pairing_property_refuses_without_a_'
      'waiting_device', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingContractWorld world = buildIdlePairingWorld();
      await _expectRefusedWith(world, _reject, message: noDeviceWaitingToPair);
      await startPairingEverywhere(world);
      await _expectRefusedWith(world, _reject, message: noDeviceWaitingToPair);
      closePairingWorld(world);
    }
  });

  test('${_typePrefix}_reject_pairing_property_refuses_after_the_code_'
      'expired', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingContractWorld world = await buildWaitingPairingWorld();
      expirePairingCodes(world);

      await _expectRefusedWith(world, _reject, message: noShowingPairingCode);
      closePairingWorld(world);
    }
  });

  test('${_typePrefix}_reject_pairing_property_closes_the_session', () async {
    for (int i = 0; i < _iterations; i += 1) {
      await _expectSessionClosedBy(_reject);
    }
  });

  test('${_typePrefix}_cancel_pairing_property_refuses_without_a_live_'
      'code', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingContractWorld world = buildIdlePairingWorld();
      await _expectRefusedWith(world, _cancel, message: noShowingPairingCode);
      await startPairingEverywhere(world);
      expirePairingCodes(world);
      await _expectRefusedWith(world, _cancel, message: noShowingPairingCode);
      closePairingWorld(world);
    }
  });

  test('${_typePrefix}_cancel_pairing_property_ends_a_session_with_a_'
      'waiting_device', () async {
    for (int i = 0; i < _iterations; i += 1) {
      await _expectSessionClosedBy(_cancel);
    }
  });

  test('${_typePrefix}_cancel_pairing_property_cancels_only_once', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingContractWorld world = buildIdlePairingWorld();
      await startPairingEverywhere(world);
      for (final NamedPairingRepository implementation
          in world.implementations) {
        await implementation.repository.cancelPairing();
      }

      await _expectRefusedWith(world, _cancel, message: noShowingPairingCode);
      closePairingWorld(world);
    }
  });
}
