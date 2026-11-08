import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../fakes/support/pairing_inputs.dart';
import '../node_backed/support/node_backed_pairing_rig.dart';
import 'support/contract_step_failures.dart';
import 'support/pairing_contract_rigs.dart';

const String _typePrefix = 'test_pairing_repository';
const int _iterations = 10;
const String _validCode = '4F7-K2Q';
const List<String?> _validServerAddresses = <String?>[
  null,
  'https://pair.example.org',
  'http://127.0.0.1:7070',
];

String _randomMalformedCode(Random random) {
  String code = randomHostileText(random);
  while (describePairingCodeProblem(code) == null) {
    code = '$code${randomHostileText(random)}x';
  }
  return code;
}

String _randomWorkspaceOrBadName(Random random) {
  if (random.nextBool()) {
    return randomBadName(random);
  }
  return randomDeviceName(random);
}

Future<PairingOutcome> _joinValidly(
  NamedPairingRepository implementation,
  Random random, {
  required String deviceName,
  required DeviceRole role,
}) {
  return implementation.repository.joinWithCode(
    serverAddress: pickOne(random, _validServerAddresses),
    code: _validCode,
    deviceName: deviceName,
    role: role,
  );
}

void main() {
  test('${_typePrefix}_find_waiting_join_property_none_outside_a_'
      'join', () async {
    final Random random = seededRandom(85421);
    for (int i = 0; i < _iterations; i += 1) {
      for (final NamedPairingRepository implementation
          in buildEveryAccountPairingRepository()) {
        expect(implementation.repository.findWaitingJoin(), isNull);
        await findStepFailure(
          () => implementation.repository.joinWithCode(
            serverAddress: null,
            code: _randomMalformedCode(random),
            deviceName: randomDeviceName(random),
            role: pickOne(random, DeviceRole.values),
          ),
        );
        expect(
          implementation.repository.findWaitingJoin(),
          isNull,
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_find_waiting_join_property_none_after_a_finished_'
      'join', () async {
    final Random random = seededRandom(85422);
    for (int i = 0; i < _iterations; i += 1) {
      for (final NamedPairingRepository implementation
          in buildEveryAccountPairingRepository()) {
        await _joinValidly(
          implementation,
          random,
          deviceName: randomDeviceName(random),
          role: pickOne(random, DeviceRole.values),
        );
        expect(
          implementation.repository.findWaitingJoin(),
          isNull,
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_find_waiting_join_property_none_after_hosting_an_'
      'account', () async {
    final Random random = seededRandom(85423);
    for (int i = 0; i < _iterations; i += 1) {
      for (final NamedPairingRepository implementation
          in buildEveryAccountPairingRepository()) {
        await implementation.repository.createHostedAccount(
          workspaceName: randomDeviceName(random),
          deviceName: randomDeviceName(random),
          role: pickOne(random, DeviceRole.values),
        );
        expect(
          implementation.repository.findWaitingJoin(),
          isNull,
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_join_with_code_property_refuses_malformed_codes_'
      'and_addresses', () async {
    final Random random = seededRandom(85424);
    for (int i = 0; i < _iterations; i += 1) {
      final bool hasBadCode = random.nextBool();
      final String code = hasBadCode
          ? _randomMalformedCode(random)
          : _validCode;
      final String serverAddress = hasBadCode
          ? pickOne(random, _validServerAddresses) ?? ''
          : 'ftp ${randomHostileText(random)}';

      for (final NamedPairingRepository implementation
          in buildEveryAccountPairingRepository()) {
        final Object? failure = await findStepFailure(
          () => implementation.repository.joinWithCode(
            serverAddress: serverAddress,
            code: code,
            deviceName: randomDeviceName(random),
            role: pickOne(random, DeviceRole.values),
          ),
        );
        expect(failure, isA<FormatException>(), reason: implementation.name);
      }
    }
  });

  test('${_typePrefix}_join_with_code_property_refuses_bad_device_'
      'names', () async {
    final Random random = seededRandom(85425);
    for (int i = 0; i < _iterations; i += 1) {
      final String badName = randomBadName(random);

      for (final NamedPairingRepository implementation
          in buildEveryAccountPairingRepository()) {
        final Object? failure = await findStepFailure(
          () => _joinValidly(
            implementation,
            random,
            deviceName: badName,
            role: pickOne(random, DeviceRole.values),
          ),
        );
        expect(failure, isA<ArgumentError>(), reason: implementation.name);
      }
    }
  });

  test('${_typePrefix}_join_with_code_property_keeps_the_device_name_and_'
      'role', () async {
    final Random random = seededRandom(85426);
    for (int i = 0; i < _iterations; i += 1) {
      final String deviceName = randomDeviceName(random);
      final DeviceRole role = pickOne(random, DeviceRole.values);

      for (final NamedPairingRepository implementation
          in buildEveryAccountPairingRepository()) {
        final PairingOutcome outcome = await _joinValidly(
          implementation,
          random,
          deviceName: deviceName,
          role: role,
        );
        expect(outcome.deviceName, deviceName, reason: implementation.name);
        expect(outcome.role, role, reason: implementation.name);
        expect(outcome.workspaceNames, isNotEmpty);
      }
    }
  });

  test('${_typePrefix}_create_hosted_account_property_refuses_bad_device_'
      'or_workspace_names', () async {
    final Random random = seededRandom(85427);
    for (int i = 0; i < _iterations; i += 1) {
      final bool hasBadDeviceName = random.nextBool();
      final String deviceName = hasBadDeviceName
          ? randomBadName(random)
          : randomDeviceName(random);
      final String workspaceName = hasBadDeviceName
          ? _randomWorkspaceOrBadName(random)
          : randomBadName(random);

      for (final NamedPairingRepository implementation
          in buildEveryAccountPairingRepository()) {
        final Object? failure = await findStepFailure(
          () => implementation.repository.createHostedAccount(
            workspaceName: workspaceName,
            deviceName: deviceName,
            role: pickOne(random, DeviceRole.values),
          ),
        );
        expect(failure, isA<ArgumentError>(), reason: implementation.name);
      }
    }
  });

  test('${_typePrefix}_create_hosted_account_property_owns_exactly_the_'
      'one_new_workspace', () async {
    final Random random = seededRandom(85428);
    for (int i = 0; i < _iterations; i += 1) {
      final String workspaceName = randomDeviceName(random);
      final String deviceName = randomDeviceName(random);
      final DeviceRole role = pickOne(random, DeviceRole.values);

      for (final NamedPairingRepository implementation
          in buildEveryAccountPairingRepository()) {
        final PairingOutcome outcome = await implementation.repository
            .createHostedAccount(
              workspaceName: workspaceName,
              deviceName: deviceName,
              role: role,
            );
        expect(outcome.workspaceNames, <String>[workspaceName]);
        expect(outcome.deviceName, deviceName, reason: implementation.name);
        expect(outcome.role, role, reason: implementation.name);
        expect(outcome.approverName, isNull, reason: implementation.name);
      }
    }
  });

  test('${_typePrefix}_create_hosted_account_property_every_'
      'implementation_refuses_alike', () async {
    final Random random = seededRandom(85429);
    for (int i = 0; i < _iterations; i += 1) {
      final String workspaceName = _randomWorkspaceOrBadName(random);
      final String deviceName = _randomWorkspaceOrBadName(random);
      final DeviceRole role = pickOne(random, DeviceRole.values);
      final List<bool> refusals = <bool>[];

      for (final NamedPairingRepository implementation
          in buildEveryAccountPairingRepository()) {
        final Object? failure = await findStepFailure(
          () => implementation.repository.createHostedAccount(
            workspaceName: workspaceName,
            deviceName: deviceName,
            role: role,
          ),
        );
        refusals.add(failure != null);
      }

      expect(refusals.toSet(), hasLength(1), reason: '$refusals');
    }
  });
}
