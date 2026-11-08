import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/memory_workspace_choice_store.dart';
import '../../../support/random_inputs.dart';
import 'identifier_ordered_records.dart';
import 'simulated_catalog_node.dart';

const Duration workspaceRigRetryInterval = Duration(seconds: 30);
final DateTime workspaceRigMoment = DateTime.utc(2026, 11, 7, 9, 30);
const int _largestWorkspaceCount = 4;
const String _commandField = 'command';

final class WorkspaceRepositoryRig {
  WorkspaceRepositoryRig._({
    required this.node,
    required this.transport,
    required this.choiceStore,
    required this.repository,
  });

  factory WorkspaceRepositoryRig.open(
    Random random, {
    required bool hasAccount,
  }) {
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: hasAccount,
    );
    final int workspaceCount = random.nextInt(_largestWorkspaceCount + 1);
    for (int i = 0; i < workspaceCount; i += 1) {
      simulated.addWorkspace(randomWordPhrase(random));
    }
    final ScriptedNodeTransport transport = ScriptedNodeTransport(
      answer: IdentifierOrderedCatalogNode(simulated).answer,
    );
    final MemoryWorkspaceChoiceStore choiceStore = MemoryWorkspaceChoiceStore(
      chosenWorkspaceId: null,
    );
    return WorkspaceRepositoryRig._(
      node: simulated,
      transport: transport,
      choiceStore: choiceStore,
      repository: NodeBackedWorkspaceRepository(
        channel: NodeCommandChannel(transport: transport),
        clock: FixedClock(workspaceRigMoment),
        retryInterval: workspaceRigRetryInterval,
        choiceStore: choiceStore,
      ),
    );
  }

  final SimulatedCatalogNode node;
  final ScriptedNodeTransport transport;
  final MemoryWorkspaceChoiceStore choiceStore;
  final NodeBackedWorkspaceRepository repository;

  List<String> listSentCommandNames() {
    final List<String> names = <String>[];
    for (final RecordedExchange exchange in transport.exchanges) {
      final Map<String, Object?> command =
          jsonDecode(exchange.inputJson) as Map<String, Object?>;
      names.add(command[_commandField]! as String);
    }
    return names;
  }

  List<String> listNodeWorkspaceIds() {
    final List<String> workspaceIds = <String>[
      for (final Map<String, Object?> workspace in node.workspaces)
        workspace['id']! as String,
    ];
    workspaceIds.sort();
    return workspaceIds;
  }

  List<String> listShownWorkspaceIds() {
    return <String>[
      for (final Workspace workspace in repository.listWorkspaces())
        workspace.id.value,
    ];
  }

  WorkspaceId pickNodeWorkspaceId(Random random) {
    final Map<String, Object?> workspace = pickOne(random, node.workspaces);
    return WorkspaceId(workspace['id']! as String);
  }
}

Future<WorkspaceRepositoryRig> openLoadedWorkspaceRig(Random random) async {
  final WorkspaceRepositoryRig rig = WorkspaceRepositoryRig.open(
    random,
    hasAccount: true,
  );
  rig.node.addWorkspace(randomWordPhrase(random));
  await rig.repository.load();
  return rig;
}

Future<Object?> readRepositoryProblem(
  Future<Object?> Function() attempt,
) async {
  try {
    await attempt();
  } on Object catch (problem) {
    return problem;
  }
  return null;
}
