import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/device_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/pairing_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

Future<node.PairingRequestScreen?> readPairingRequestWhileCurrent({
  required NodeCommandChannel channel,
  required String code,
  required bool Function(String code) isCurrentCode,
}) async {
  final node.PairingRequestScreen screen;
  try {
    screen = await channel.execute(node.PairingRequestCommand(code: code));
  } on NodeCommandFailure catch (failure, stackTrace) {
    if (!isCurrentCode(code)) {
      return null;
    }
    Error.throwWithStackTrace(translateNodeFailure(failure), stackTrace);
  }

  if (!isCurrentCode(code)) {
    return null;
  }
  return screen;
}

Future<String?> findApproverName({
  required NodeCommandChannel channel,
  required node.AccountSummary account,
}) async {
  final DeviceId? approverId = account.device.approvedBy;
  if (approverId == null) {
    return null;
  }

  final List<node.DeviceView> devices = await executeNodeCommand(
    channel,
    const node.ListDevicesCommand(),
  );
  try {
    return findDeviceName(devices, approverId);
  } on RecordNotFound {
    return null;
  }
}

Future<PairingOutcome> waitForJoinAnswer({
  required NodeCommandChannel channel,
  required node.PendingJoin pending,
  required Duration pollInterval,
  required List<String> runnerLabels,
  required void Function(WaitingJoin? waitingJoin) showWaitingJoin,
}) async {
  while (true) {
    await Future<void>.delayed(pollInterval);
    final node.JoinStatusView status = await executeNodeCommand(
      channel,
      const node.JoinStatusCommand(),
    );
    switch (status) {
      case node.JoinWaiting():
        showWaitingJoin(mapWaitingJoinFromNode(pending, status));
        continue;
      case node.JoinApproved(:final node.AccountSummary account):
        return mapPairingOutcomeFromNode(
          account,
          runnerLabels: runnerLabels,
          approverName: await findApproverName(
            channel: channel,
            account: account,
          ),
        );
      case node.JoinRejected():
        throw PeopleFacingRefusal('The other device rejected this pairing');
      case node.JoinExpired():
        throw PeopleFacingRefusal(
          'The pairing code expired before it was approved',
        );
    }
  }
}
