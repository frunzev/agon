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
const int _largestWaitingPolls = 3;
const String _joinedWorkspaceName = 'home';
const Map<DeviceRole, String> _roleWireNames = <DeviceRole, String>{
  DeviceRole.client: 'client',
  DeviceRole.runner: 'runner',
  DeviceRole.clientAndRunner: 'client_and_runner',
};
const List<String> _serverAddresses = <String>[
  'https://relay.example.com',
  'http://127.0.0.1:7070',
];

String _randomName(Random random) {
  final int length = 1 + random.nextInt(_largestNameLength);
  final StringBuffer name = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    name.write(pickOne(random, _nameCharacters.split('')));
  }
  return name.toString();
}

NodeBackedPairingRepository _repositoryFor(SimulatedPairingNode simulated) {
  return buildPairingRepository(simulated, MovableClock(pairingStart));
}

Future<PairingOutcome> _join(
  NodeBackedPairingRepository repository, {
  required String? serverAddress,
  required String deviceName,
  required DeviceRole role,
}) {
  return repository.joinWithCode(
    serverAddress: serverAddress,
    code: simulatedPairingCode,
    deviceName: deviceName,
    role: role,
  );
}

void main() {
  test('${_typePrefix}_join_with_code_property_records_the_server', () async {
    final Random random = seededRandom(88801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SimulatedPairingNode simulated = buildPairingNode();
      final NodeBackedPairingRepository repository = _repositoryFor(simulated);
      final String serverAddress = pickOne(random, _serverAddresses);

      await _join(
        repository,
        serverAddress: serverAddress,
        deviceName: _randomName(random),
        role: pickOne(random, DeviceRole.values),
      );

      expect(simulated.joinServerAddresses, <Object?>[serverAddress]);
      repository.dispose();
    }
  });

  test('${_typePrefix}_join_with_code_property_remembers_the_ask', () async {
    final Random random = seededRandom(88802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SimulatedPairingNode simulated = buildPairingNode();
      final NodeBackedPairingRepository repository = _repositoryFor(simulated);
      final String deviceName = _randomName(random);
      final DeviceRole role = pickOne(random, DeviceRole.values);

      await _join(
        repository,
        serverAddress: null,
        deviceName: deviceName,
        role: role,
      );

      expect(simulated.joinedDeviceName, deviceName);
      expect(simulated.joinedRole, _roleWireNames[role]);
      repository.dispose();
    }
  });

  test('${_typePrefix}_read_join_status_property_waits_then_echoes', () async {
    final Random random = seededRandom(88803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int waitingPolls = 1 + random.nextInt(_largestWaitingPolls);
      final SimulatedPairingNode simulated = buildPairingNode(
        joinPollsBeforeAnswer: waitingPolls,
      );
      final NodeBackedPairingRepository repository = _repositoryFor(simulated);
      final String deviceName = _randomName(random);

      final PairingOutcome outcome = await _join(
        repository,
        serverAddress: null,
        deviceName: deviceName,
        role: pickOne(random, DeviceRole.values),
      );

      expect(simulated.joinStatusPollCount, greaterThan(waitingPolls));
      expect(outcome.deviceName, deviceName);
      repository.dispose();
    }
  });

  test(
    '${_typePrefix}_read_join_status_property_refusal_has_no_account',
    () async {
      final Random random = seededRandom(88804);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SimulatedPairingNode simulated = buildPairingNode(
          joinAnswer: 'rejected',
        );
        final NodeBackedPairingRepository repository = _repositoryFor(
          simulated,
        );

        await expectLater(
          _join(
            repository,
            serverAddress: null,
            deviceName: _randomName(random),
            role: pickOne(random, DeviceRole.values),
          ),
          throwsA(anything),
        );

        expect(simulated.hasAccount, isFalse);
        repository.dispose();
      }
    },
  );

  test('${_typePrefix}_create_hosted_account_property_only_once', () async {
    final Random random = seededRandom(88805);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SimulatedPairingNode simulated = buildPairingNode();
      final NodeBackedPairingRepository repository = _repositoryFor(simulated);
      final DeviceRole role = pickOne(random, DeviceRole.values);

      await repository.createHostedAccount(
        workspaceName: _randomName(random),
        deviceName: _randomName(random),
        role: role,
      );

      await expectLater(
        repository.createHostedAccount(
          workspaceName: _randomName(random),
          deviceName: _randomName(random),
          role: role,
        ),
        throwsA(anything),
      );
      repository.dispose();
    }
  });

  test(
    '${_typePrefix}_create_hosted_account_property_names_the_workspace',
    () async {
      final Random random = seededRandom(88806);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SimulatedPairingNode simulated = buildPairingNode();
        final NodeBackedPairingRepository repository = _repositoryFor(
          simulated,
        );
        final String workspaceName = _randomName(random);

        final PairingOutcome outcome = await repository.createHostedAccount(
          workspaceName: workspaceName,
          deviceName: _randomName(random),
          role: pickOne(random, DeviceRole.values),
        );

        expect(outcome.workspaceNames, <String>[workspaceName]);
        repository.dispose();
      }
    },
  );

  test('${_typePrefix}_build_account_json_property_join_names_home', () async {
    final Random random = seededRandom(88807);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SimulatedPairingNode simulated = buildPairingNode();
      final NodeBackedPairingRepository repository = _repositoryFor(simulated);

      final PairingOutcome outcome = await _join(
        repository,
        serverAddress: null,
        deviceName: _randomName(random),
        role: pickOne(random, DeviceRole.values),
      );

      expect(outcome.workspaceNames, <String>[_joinedWorkspaceName]);
      repository.dispose();
    }
  });

  test(
    '${_typePrefix}_build_account_json_property_keeps_every_role',
    () async {
      final Random random = seededRandom(88808);

      for (final DeviceRole role in DeviceRole.values) {
        final SimulatedPairingNode simulated = buildPairingNode();
        final NodeBackedPairingRepository repository = _repositoryFor(
          simulated,
        );

        final PairingOutcome outcome = await _join(
          repository,
          serverAddress: null,
          deviceName: _randomName(random),
          role: role,
        );

        expect(outcome.role, role);
        repository.dispose();
      }
    },
  );

  test(
    '${_typePrefix}_build_account_json_property_approver_only_for_joins',
    () async {
      final Random random = seededRandom(88809);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SimulatedPairingNode joining = buildPairingNode();
        final SimulatedPairingNode hosting = buildPairingNode();
        final NodeBackedPairingRepository joiningRepository = _repositoryFor(
          joining,
        );
        final NodeBackedPairingRepository hostingRepository = _repositoryFor(
          hosting,
        );
        final DeviceRole role = pickOne(random, DeviceRole.values);

        final PairingOutcome joined = await _join(
          joiningRepository,
          serverAddress: null,
          deviceName: _randomName(random),
          role: role,
        );
        final PairingOutcome hosted = await hostingRepository
            .createHostedAccount(
              workspaceName: _randomName(random),
              deviceName: _randomName(random),
              role: role,
            );

        expect(joined.approverName, isNotNull);
        expect(hosted.approverName, isNull);
        joiningRepository.dispose();
        hostingRepository.dispose();
      }
    },
  );
}
