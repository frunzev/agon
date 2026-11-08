import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;

import '../../../bridge/support/random_account_json.dart';
import '../../../bridge/support/random_catalog_json.dart';
import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/random_inputs.dart';

final class PairingReadsNode {
  PairingReadsNode({required this.joinStatuses, required this.devices});

  final List<Map<String, Object?>> joinStatuses;
  final List<Map<String, Object?>> devices;
  final List<String> commands = <String>[];
  String? pairingRequestError;
  String? pairingRequestErrorKind;
  Map<String, Object?>? pairingRequestScreen;

  String answer(String inputJson) {
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    final String name = command['command']! as String;
    commands.add(name);
    return switch (name) {
      'join_status' => encodeSuccessReply(joinStatuses.removeAt(0)),
      'list_devices' => encodeSuccessReply(devices),
      'pairing_request' => _answerPairingRequest(),
      _ => encodeErrorReply('unknown command: $name'),
    };
  }

  String _answerPairingRequest() {
    final String? error = pairingRequestError;
    final String? kind = pairingRequestErrorKind;
    if (error != null && kind != null) {
      return encodeKindedErrorReply(message: error, kind: kind);
    }
    if (error != null) {
      return encodeErrorReply(error);
    }
    return encodeSuccessReply(pairingRequestScreen);
  }
}

Map<String, Object?> buildWaitingStatusJson(Random random) {
  return <String, Object?>{
    'state': 'waiting',
    'fingerprint_words': random.nextBool()
        ? <Object?>[]
        : <Object?>['apple', randomText(random)],
  };
}

Map<String, Object?> buildApprovedStatusJson(
  Random random, {
  required String? approverId,
}) {
  final Map<String, Object?> account = randomAccountSummaryJson(random);
  (account['device']! as Map<String, Object?>)['approved_by'] = approverId;
  return <String, Object?>{
    'state': 'approved',
    'fingerprint_words': <Object?>['pear'],
    ...account,
  };
}

Map<String, Object?> buildNamedDeviceViewJson(
  Random random, {
  required String deviceId,
  required String name,
}) {
  final Map<String, Object?> view = randomDeviceViewJson(random);
  final Map<String, Object?> device = view['device']! as Map<String, Object?>;
  device['id'] = deviceId;
  device['name'] = name;
  return view;
}

node.AccountSummary readApprovedAccount(Map<String, Object?> approvedJson) {
  return node.AccountSummary.fromJson(approvedJson);
}
