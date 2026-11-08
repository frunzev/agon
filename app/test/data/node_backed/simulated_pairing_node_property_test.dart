import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/pairing_repository_harness.dart';
import 'support/simulated_pairing_node.dart';

const String _typePrefix = 'test_simulated_pairing_node';
const String _nameCharacters = 'abcdefghijklmnopqrstuvwxyz0123456789-';
const int _largestNameLength = 20;

String _randomDeviceName(Random random) {
  final int length = 1 + random.nextInt(_largestNameLength);
  final StringBuffer name = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    name.write(pickOne(random, _nameCharacters.split('')));
  }
  return name.toString();
}

Future<PairingOutcome> _join(
  NodeBackedPairingRepository repository, {
  required String deviceName,
  required DeviceRole role,
}) {
  return repository.joinWithCode(
    serverAddress: null,
    code: simulatedPairingCode,
    deviceName: deviceName,
    role: role,
  );
}

void main() {
  test(
    '${_typePrefix}_join_with_code_property_echoes_the_asked_device',
    () async {
      final Random random = seededRandom(88601);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SimulatedPairingNode simulated = buildPairingNode();
        final NodeBackedPairingRepository repository = buildPairingRepository(
          simulated,
          MovableClock(pairingStart),
        );
        final String deviceName = _randomDeviceName(random);
        final DeviceRole role = pickOne(random, DeviceRole.values);

        final PairingOutcome outcome = await _join(
          repository,
          deviceName: deviceName,
          role: role,
        );

        expect(outcome.deviceName, deviceName);
        expect(outcome.role, role);
        repository.dispose();
      }
    },
  );

  test(
    '${_typePrefix}_read_join_status_property_follows_the_latest_join',
    () async {
      final Random random = seededRandom(88602);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SimulatedPairingNode simulated = buildPairingNode();
        final NodeBackedPairingRepository repository = buildPairingRepository(
          simulated,
          MovableClock(pairingStart),
        );
        await _join(
          repository,
          deviceName: _randomDeviceName(random),
          role: pickOne(random, DeviceRole.values),
        );
        final String laterName = _randomDeviceName(random);
        final DeviceRole laterRole = pickOne(random, DeviceRole.values);

        final PairingOutcome outcome = await _join(
          repository,
          deviceName: laterName,
          role: laterRole,
        );

        expect(outcome.deviceName, laterName);
        expect(outcome.role, laterRole);
        repository.dispose();
      }
    },
  );

  test(
    '${_typePrefix}_create_hosted_account_property_echoes_the_role',
    () async {
      final Random random = seededRandom(88603);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SimulatedPairingNode simulated = buildPairingNode();
        final NodeBackedPairingRepository repository = buildPairingRepository(
          simulated,
          MovableClock(pairingStart),
        );
        final String deviceName = _randomDeviceName(random);
        final DeviceRole role = pickOne(random, DeviceRole.values);

        final PairingOutcome outcome = await repository.createHostedAccount(
          workspaceName: _randomDeviceName(random),
          deviceName: deviceName,
          role: role,
        );

        expect(outcome.deviceName, deviceName);
        expect(outcome.role, role);
        repository.dispose();
      }
    },
  );
}
