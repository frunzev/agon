import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/data/rules/protected_patterns.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/random_inputs.dart';
import '../../fakes/support/workspace_inputs.dart';
import '../../node_backed/support/identifier_ordered_records.dart';
import '../../node_backed/support/simulated_catalog_node.dart';
import '../../node_backed/support/simulated_protected_files.dart';

const String rustNotKeepingServerMessage = 'this device keeps no app server';
const String _noStanding = 'none';
const String _commandField = 'command';
const String _stopBackupCommand = 'stop_server_backup';
const String _setProtectedFilesCommand = 'set_protected_files';
const List<String> _approvalPolicyWireNames = <String>[
  'never_ask',
  'ask_before_risky_actions',
];
const int _largestWorkspaceCount = 4;

final class RustLikeWorkspaceNode {
  RustLikeWorkspaceNode({required this.catalog})
    : _ordered = IdentifierOrderedCatalogNode(catalog);

  final SimulatedCatalogNode catalog;
  final IdentifierOrderedCatalogNode _ordered;

  String answer(String inputJson) {
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    final Object? commandName = command[_commandField];
    final bool isKeepingNoServer =
        catalog.serverGroup.thisDeviceStanding == _noStanding;
    if (commandName == _stopBackupCommand && isKeepingNoServer) {
      return encodeErrorReply(rustNotKeepingServerMessage);
    }
    if (commandName == _setProtectedFilesCommand) {
      final List<String> patterns = <String>[
        for (final Object? pattern in command['patterns']! as List<Object?>)
          pattern! as String,
      ];
      final String? problem = describeProtectedFilesProblem(patterns);
      if (problem != null) {
        return encodeErrorReply(problem);
      }
    }
    return _ordered.answer(inputJson);
  }
}

void _seedServerGroup(Random random, SimulatedCatalogNode catalog) {
  catalog.serverGroup.canKeepBackup = random.nextBool();
  final int shape = random.nextInt(4);
  if (shape == 0) {
    return;
  }
  if (shape == 1) {
    catalog.serverGroup.makeThisDeviceActive();
    return;
  }
  catalog.serverGroup.foundGroup();
  if (shape == 3 && catalog.serverGroup.canKeepBackup) {
    catalog.serverGroup.startBackup(const <String, Object?>{});
  }
}

RustLikeWorkspaceNode buildRandomWorkspaceNode(Random random) {
  final SimulatedCatalogNode catalog = SimulatedCatalogNode(hasAccount: true);
  final int workspaceCount = 1 + random.nextInt(_largestWorkspaceCount);
  for (int i = 0; i < workspaceCount; i += 1) {
    final Map<String, Object?> workspace = catalog.addWorkspace('team-$i');
    workspace['protected_files'] = buildSimulatedProtectedFilesJson(
      randomPatterns(random),
    );
    workspace['approval_policy'] = pickOne(random, _approvalPolicyWireNames);
  }
  giveRandomIdentifiers(random, catalog.workspaces, kind: 'workspace');
  _seedServerGroup(random, catalog);
  return RustLikeWorkspaceNode(catalog: catalog);
}
