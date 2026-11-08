import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/support/random_account_json.dart';
import '../../bridge/support/random_catalog_json.dart';
import '../../support/random_inputs.dart';
import 'support/pairing_reads_node.dart';
import 'support/simulated_node_replies.dart';

const String _typePrefix = 'test_pairing_node_reads';
const int _iterations = 60;
const int _largestWaitingPolls = 4;
const Duration _quickPolling = Duration(microseconds: 1);

void main() {
  test('${_typePrefix}_wait_for_join_answer_property_shows_each_wait_then_'
      'returns_the_approved_outcome', () async {
    final Random random = seededRandom(85207);
    for (int i = 0; i < _iterations; i += 1) {
      final int waitingPolls = random.nextInt(_largestWaitingPolls);
      final List<Map<String, Object?>> waits = <Map<String, Object?>>[
        for (int index = 0; index < waitingPolls; index += 1)
          buildWaitingStatusJson(random),
      ];
      final Map<String, Object?> approved = buildApprovedStatusJson(
        random,
        approverId: random.nextBool() ? null : 'unlisted-approver',
      );
      final PairingReadsNode pairingNode = PairingReadsNode(
        joinStatuses: <Map<String, Object?>>[...waits, approved],
        devices: <Map<String, Object?>>[],
      );
      final node.PendingJoin pending = node.PendingJoin.fromJson(
        randomPendingJoinJson(random),
      );
      final List<String> runnerLabels = <String>[randomText(random)];
      final List<WaitingJoin?> shown = <WaitingJoin?>[];

      final PairingOutcome outcome = await waitForJoinAnswer(
        channel: buildSimulatedChannel(pairingNode.answer),
        pending: pending,
        pollInterval: _quickPolling,
        runnerLabels: runnerLabels,
        showWaitingJoin: shown.add,
      );

      final node.AccountSummary account = readApprovedAccount(approved);
      expect(shown.length, waitingPolls);
      for (int index = 0; index < waitingPolls; index += 1) {
        final List<Object?> words =
            waits[index]['fingerprint_words']! as List<Object?>;
        expect(shown[index]?.fingerprintWords, words.isEmpty ? null : words);
        expect(shown[index]?.code, words.isEmpty ? null : pending.displayCode);
      }
      expect(outcome.deviceName, account.device.name);
      expect(outcome.runnerLabels, runnerLabels);
      expect(outcome.approverName, isNull);
    }
  });

  test('${_typePrefix}_wait_for_join_answer_property_a_refusal_ends_the_'
      'wait_in_plain_words', () async {
    final Random random = seededRandom(85208);
    for (int i = 0; i < _iterations; i += 1) {
      final String answer = pickOne(random, <String>['rejected', 'expired']);
      final PairingReadsNode pairingNode = PairingReadsNode(
        joinStatuses: <Map<String, Object?>>[
          for (int index = 0; index < random.nextInt(3); index += 1)
            buildWaitingStatusJson(random),
          <String, Object?>{'state': answer, 'fingerprint_words': <Object?>[]},
          buildApprovedStatusJson(random, approverId: null),
        ],
        devices: <Map<String, Object?>>[],
      );

      await expectLater(
        waitForJoinAnswer(
          channel: buildSimulatedChannel(pairingNode.answer),
          pending: node.PendingJoin.fromJson(randomPendingJoinJson(random)),
          pollInterval: _quickPolling,
          runnerLabels: const <String>[],
          showWaitingJoin: (WaitingJoin? waitingJoin) {},
        ),
        throwsA(isA<StateError>()),
      );
      expect(pairingNode.joinStatuses, hasLength(1));
    }
  });

  test('${_typePrefix}_wait_for_join_answer_property_an_approval_by_an_'
      'unlisted_device_still_pairs', () async {
    final Random random = seededRandom(85209);
    for (int i = 0; i < _iterations; i += 1) {
      final Map<String, Object?> approved = buildApprovedStatusJson(
        random,
        approverId: 'approver-${random.nextInt(1 << 30)}',
      );
      final PairingReadsNode pairingNode = PairingReadsNode(
        joinStatuses: <Map<String, Object?>>[approved],
        devices: <Map<String, Object?>>[
          for (int index = 0; index < random.nextInt(4); index += 1)
            randomDeviceViewJson(random),
        ],
      );

      final PairingOutcome outcome = await waitForJoinAnswer(
        channel: buildSimulatedChannel(pairingNode.answer),
        pending: node.PendingJoin.fromJson(randomPendingJoinJson(random)),
        pollInterval: _quickPolling,
        runnerLabels: const <String>[],
        showWaitingJoin: (WaitingJoin? waitingJoin) {},
      );

      expect(outcome.deviceName, readApprovedAccount(approved).device.name);
      expect(outcome.approverName, isNull);
    }
  });
}
