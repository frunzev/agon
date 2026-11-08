import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/default_protected_patterns.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../../screens/support/planned_refusal.dart';
import '../../../screens/support/refusing_place_repositories.dart';
import '../../../support/memory_workspace_choice_store.dart';
import '../../../support/server_group_repositories.dart';
import '../../node_backed/support/simulated_catalog_node.dart';
import '../../node_backed/support/simulated_node_replies.dart';
import 'contract_step_failures.dart';
import 'workspace_contract_nodes.dart';

const Duration _retryInterval = Duration(seconds: 30);
const String defaultPatternsMarker = 'default patterns';
final DateTime _contractMoment = DateTime.parse(simulatedMoment);

final class ContractWorkspaceImplementation {
  ContractWorkspaceImplementation({
    required this.name,
    required this.repository,
    required this.defaultPatterns,
    required List<Workspace> seeded,
  }) : workspaceIdsByKey = <String, WorkspaceId>{
         for (final Workspace workspace in seeded)
           workspace.id.value: workspace.id,
       };

  final String name;
  final WorkspaceRepository repository;
  final List<String> defaultPatterns;
  final Map<String, WorkspaceId> workspaceIdsByKey;

  String findKey(WorkspaceId workspaceId) {
    for (final MapEntry<String, WorkspaceId> entry
        in workspaceIdsByKey.entries) {
      if (entry.value == workspaceId) {
        return entry.key;
      }
    }
    return 'unknown ${workspaceId.value}';
  }

  WorkspaceId resolveKey(String key) {
    return workspaceIdsByKey[key] ?? WorkspaceId(key);
  }
}

typedef WorkspaceContractWorld = ({
  RustLikeWorkspaceNode node,
  NodeBackedWorkspaceRepository nodeRepository,
  List<ContractWorkspaceImplementation> implementations,
});

typedef WorkspaceStep = Future<Object?> Function(
  ContractWorkspaceImplementation implementation,
);

typedef WorkspaceOutcome = ({String name, Object? failure, String? returned});

FakeWorkspaceRepository _buildTwin(NodeBackedWorkspaceRepository source) {
  return FakeWorkspaceRepository(
    workspaces: source.listWorkspaces(),
    currentWorkspaceId: source.currentWorkspace().id,
    appServerStatus: source.findAppServerStatus(),
    appServerGroup: source.findAppServerGroup(),
    currentDeviceId: const DeviceId(simulatedDeviceId),
    clock: FixedClock(_contractMoment),
  );
}

Future<WorkspaceContractWorld> openWorkspaceContractWorld(
  Random random,
) async {
  final RustLikeWorkspaceNode node = buildRandomWorkspaceNode(random);
  final NodeBackedWorkspaceRepository nodeRepository =
      NodeBackedWorkspaceRepository(
        channel: NodeCommandChannel(
          transport: ScriptedNodeTransport(answer: node.answer),
        ),
        clock: FixedClock(_contractMoment),
        retryInterval: _retryInterval,
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  await nodeRepository.load();
  final List<Workspace> seeded = nodeRepository.listWorkspaces();
  final Workspace chosen = seeded[random.nextInt(seeded.length)];
  await nodeRepository.switchWorkspace(chosen.id);

  final FakeWorkspaceRepository scriptedInner = _buildTwin(nodeRepository);
  final List<ContractWorkspaceImplementation> implementations =
      <ContractWorkspaceImplementation>[
        ContractWorkspaceImplementation(
          name: 'fake',
          repository: _buildTwin(nodeRepository),
          defaultPatterns: defaultProtectedPatterns,
          seeded: seeded,
        ),
        ContractWorkspaceImplementation(
          name: 'node backed',
          repository: nodeRepository,
          defaultPatterns: defaultProtectedPatterns,
          seeded: seeded,
        ),
        ContractWorkspaceImplementation(
          name: 'refusing double',
          repository: RefusingWorkspaceRepository(
            stored: _buildTwin(nodeRepository),
            refusal: PlannedRefusal(),
          ),
          defaultPatterns: defaultProtectedPatterns,
          seeded: seeded,
        ),
        ContractWorkspaceImplementation(
          name: 'scripted backup double',
          repository: ScriptedServerBackupRepository(
            inner: scriptedInner,
            startBackup: scriptedInner.startServerBackup,
          ),
          defaultPatterns: defaultProtectedPatterns,
          seeded: seeded,
        ),
      ];
  return (
    node: node,
    nodeRepository: nodeRepository,
    implementations: implementations,
  );
}

Object? _describePatterns(
  ContractWorkspaceImplementation implementation,
  List<String> patterns,
) {
  final bool isDefault =
      jsonEncode(patterns) == jsonEncode(implementation.defaultPatterns);
  return isDefault ? defaultPatternsMarker : patterns;
}

String describeContractWorkspace(
  ContractWorkspaceImplementation implementation,
  Workspace workspace,
) {
  return jsonEncode(<Object?>[
    implementation.findKey(workspace.id),
    workspace.name,
    workspace.appServerAddress,
    _describePatterns(implementation, workspace.protectedFiles),
    workspace.approvalPolicy.name,
  ]);
}

List<String> describeContractWorkspaces(
  ContractWorkspaceImplementation implementation,
) {
  final List<String> descriptions = <String>[
    for (final Workspace workspace
        in implementation.repository.listWorkspaces())
      describeContractWorkspace(implementation, workspace),
  ];
  descriptions.sort();
  return descriptions;
}

String describeAppServerGroup(AppServerGroup group) {
  final List<String> members = <String>[
    for (final AppServerMember member in group.members)
      '${member.deviceId.value} ${member.standing.name}',
  ];
  members.sort();
  return jsonEncode(<Object?>[
    members,
    group.thisDeviceStanding.name,
    group.canKeepBackup,
  ]);
}

String describeAppServerStatus(AppServerStatus status) {
  return jsonEncode(<Object?>[
    status.address,
    status.state.name,
    status.lastConnectedAt?.toUtc().toIso8601String(),
    status.retryInterval.inMicroseconds,
  ]);
}

String? describeReturned(
  ContractWorkspaceImplementation implementation,
  Object? returned,
) {
  return switch (returned) {
    Workspace() => describeContractWorkspace(implementation, returned),
    AppServerGroup() => describeAppServerGroup(returned),
    AppServerStatus() => describeAppServerStatus(returned),
    _ => null,
  };
}

Future<WorkspaceOutcome> _runOnWorkspaceRepository(
  ContractWorkspaceImplementation implementation,
  WorkspaceStep step,
) async {
  final Object? returned;
  try {
    returned = await step(implementation);
  } on Object catch (failure) {
    return (name: implementation.name, failure: failure, returned: null);
  }
  return (
    name: implementation.name,
    failure: null,
    returned: describeReturned(implementation, returned),
  );
}

Future<List<WorkspaceOutcome>> runOnEveryWorkspaceRepository(
  WorkspaceContractWorld world,
  WorkspaceStep step,
) async {
  final List<WorkspaceOutcome> outcomes = <WorkspaceOutcome>[];
  for (final ContractWorkspaceImplementation implementation
      in world.implementations) {
    outcomes.add(await _runOnWorkspaceRepository(implementation, step));
  }
  return outcomes;
}

bool isWorkspaceStepRefused(List<WorkspaceOutcome> outcomes) {
  return outcomes.first.failure != null;
}

void expectWorkspaceOutcomesAgree(List<WorkspaceOutcome> outcomes) {
  final WorkspaceOutcome first = outcomes.first;
  for (final WorkspaceOutcome outcome in outcomes) {
    final Object? failure = outcome.failure;
    final String reason = '${outcome.name}: $failure vs ${first.failure}';
    expect(failure != null, first.failure != null, reason: reason);
    if (failure != null) {
      final bool isExpected =
          isContractRefusal(failure) || failure is RecordNotFound;
      expect(isExpected, isTrue, reason: reason);
    }
    expect(outcome.returned, first.returned, reason: outcome.name);
  }
}

void expectWorkspaceStateAgrees(WorkspaceContractWorld world) {
  final ContractWorkspaceImplementation first = world.implementations.first;
  final List<String> listing = describeContractWorkspaces(first);
  final String current = first.findKey(first.repository.currentWorkspace().id);
  final String group = describeAppServerGroup(
    first.repository.findAppServerGroup(),
  );
  final String status = describeAppServerStatus(
    first.repository.findAppServerStatus(),
  );
  for (final ContractWorkspaceImplementation implementation
      in world.implementations) {
    final WorkspaceRepository repository = implementation.repository;
    final String name = implementation.name;
    expect(describeContractWorkspaces(implementation), listing, reason: name);
    expect(
      implementation.findKey(repository.currentWorkspace().id),
      current,
      reason: name,
    );
    expect(
      describeAppServerGroup(repository.findAppServerGroup()),
      group,
      reason: name,
    );
    expect(
      describeAppServerStatus(repository.findAppServerStatus()),
      status,
      reason: name,
    );
  }
}
