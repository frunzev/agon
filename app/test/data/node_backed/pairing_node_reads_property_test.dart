import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/pairing_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/device_without_account.dart';

import '../../bridge/support/random_account_json.dart';
import '../../bridge/support/random_catalog_json.dart';
import '../../support/random_inputs.dart';
import 'support/pairing_reads_node.dart';
import 'support/simulated_node_replies.dart';

const String _typePrefix = 'test_pairing_node_reads';
const int _iterations = 60;

void main() {
  test('${_typePrefix}_read_pairing_request_while_current_property_'
      'returns_the_screen_of_a_current_code', () async {
    final Random random = seededRandom(85201);
    for (int i = 0; i < _iterations; i += 1) {
      final PairingReadsNode pairingNode = PairingReadsNode(
        joinStatuses: <Map<String, Object?>>[],
        devices: <Map<String, Object?>>[],
      );
      final Map<String, Object?> screenJson = randomPairingRequestScreenJson(
        random,
      );
      pairingNode.pairingRequestScreen = screenJson;
      final String code = randomText(random);

      final node.PairingRequestScreen? screen =
          await readPairingRequestWhileCurrent(
            channel: buildSimulatedChannel(pairingNode.answer),
            code: code,
            isCurrentCode: (String asked) => asked == code,
          );

      expect(
        screen?.toJson(),
        node.PairingRequestScreen.fromJson(screenJson).toJson(),
      );
    }
  });

  test('${_typePrefix}_read_pairing_request_while_current_property_a_'
      'stale_code_yields_nothing', () async {
    final Random random = seededRandom(85202);
    for (int i = 0; i < _iterations; i += 1) {
      final PairingReadsNode pairingNode = PairingReadsNode(
        joinStatuses: <Map<String, Object?>>[],
        devices: <Map<String, Object?>>[],
      );
      pairingNode.pairingRequestScreen = randomPairingRequestScreenJson(
        random,
      );
      if (random.nextBool()) {
        pairingNode.pairingRequestError = 'the pairing code has expired';
      }

      final node.PairingRequestScreen? screen =
          await readPairingRequestWhileCurrent(
            channel: buildSimulatedChannel(pairingNode.answer),
            code: randomText(random),
            isCurrentCode: (String asked) => false,
          );

      expect(screen, isNull);
    }
  });

  test('${_typePrefix}_read_pairing_request_while_current_property_a_'
      'current_code_failure_is_translated', () async {
    final Random random = seededRandom(85203);
    for (int i = 0; i < _iterations; i += 1) {
      final PairingReadsNode pairingNode = PairingReadsNode(
        joinStatuses: <Map<String, Object?>>[],
        devices: <Map<String, Object?>>[],
      );
      final int status = 400 + random.nextInt(200);
      final String reason = 'reason ${randomWordPhrase(random)}x';
      final List<({String message, String? kind, TypeMatcher<Object> type})>
      failures = <({String message, String? kind, TypeMatcher<Object> type})>[
        (
          message: 'the app server answered $status: $reason',
          kind: null,
          type: isA<AppServerRefusal>(),
        ),
        (
          message: 'this device has no account',
          kind: noAccountFailureKind,
          type: isA<DeviceWithoutAccount>(),
        ),
        (message: 'plain trouble', kind: null, type: isA<StateError>()),
      ];
      final ({String message, String? kind, TypeMatcher<Object> type})
      failure = pickOne(random, failures);
      pairingNode.pairingRequestError = failure.message;
      pairingNode.pairingRequestErrorKind = failure.kind;
      final List<String> askedCodes = <String>[];
      final String code = randomText(random);

      await expectLater(
        readPairingRequestWhileCurrent(
          channel: buildSimulatedChannel(pairingNode.answer),
          code: code,
          isCurrentCode: (String asked) {
            askedCodes.add(asked);
            return true;
          },
        ),
        throwsA(failure.type),
      );
      expect(askedCodes, everyElement(code));
      expect(askedCodes, isNotEmpty);
    }
  });

  test('${_typePrefix}_find_approver_name_property_no_approver_asks_the_'
      'node_nothing', () async {
    final Random random = seededRandom(85204);
    for (int i = 0; i < _iterations; i += 1) {
      final PairingReadsNode pairingNode = PairingReadsNode(
        joinStatuses: <Map<String, Object?>>[],
        devices: <Map<String, Object?>>[],
      );

      final String? name = await findApproverName(
        channel: buildSimulatedChannel(pairingNode.answer),
        account: readApprovedAccount(
          buildApprovedStatusJson(random, approverId: null),
        ),
      );

      expect(name, isNull);
      expect(pairingNode.commands, isEmpty);
    }
  });

  test('${_typePrefix}_find_approver_name_property_names_the_listed_'
      'approver', () async {
    final Random random = seededRandom(85205);
    for (int i = 0; i < _iterations; i += 1) {
      final String approverId = 'approver-${random.nextInt(1 << 30)}';
      final String approverName = randomText(random);
      final List<Map<String, Object?>> devices = <Map<String, Object?>>[
        for (int index = 0; index < random.nextInt(4); index += 1)
          randomDeviceViewJson(random),
        buildNamedDeviceViewJson(
          random,
          deviceId: approverId,
          name: approverName,
        ),
      ]..shuffle(random);
      final PairingReadsNode pairingNode = PairingReadsNode(
        joinStatuses: <Map<String, Object?>>[],
        devices: devices,
      );

      final String? name = await findApproverName(
        channel: buildSimulatedChannel(pairingNode.answer),
        account: readApprovedAccount(
          buildApprovedStatusJson(random, approverId: approverId),
        ),
      );

      expect(name, approverName);
      expect(pairingNode.commands, <String>['list_devices']);
    }
  });

  test('${_typePrefix}_find_approver_name_property_an_unlisted_approver_'
      'has_no_name', () async {
    final Random random = seededRandom(85206);
    for (int i = 0; i < _iterations; i += 1) {
      final PairingReadsNode pairingNode = PairingReadsNode(
        joinStatuses: <Map<String, Object?>>[],
        devices: <Map<String, Object?>>[
          for (int index = 0; index < random.nextInt(4); index += 1)
            randomDeviceViewJson(random),
        ],
      );

      final String? name = await findApproverName(
        channel: buildSimulatedChannel(pairingNode.answer),
        account: readApprovedAccount(
          buildApprovedStatusJson(
            random,
            approverId: 'gone-${random.nextInt(9)}',
          ),
        ),
      );

      expect(name, isNull);
    }
  });
}
