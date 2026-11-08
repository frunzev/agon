import 'dart:math';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../../support/random_inputs.dart';
import '../../fakes/support/workspace_inputs.dart';
import 'workspace_contract_rigs.dart';

const String _missingWorkspacePrefix = 'workspace-missing-';
const String _createdKeyPrefix = 'created-';
const int _largestMissingNumber = 1 << 30;
const List<String> _refusedPatterns = <String>[
  '',
  ' leading-space',
  'trailing-space ',
  'quote"d',
  "apostrophe's",
  r'back\slash',
  '(bracketed)',
];

enum WorkspaceContractAction {
  switchWorkspace,
  createWorkspace,
  deleteWorkspace,
  saveProtectedFiles,
  resetProtectedFiles,
  changeApprovalPolicy,
  retryAppServer,
  startServerBackup,
  stopServerBackup,
}

typedef WorkspaceStepRecord = ({
  WorkspaceContractAction action,
  String? key,
  List<WorkspaceOutcome> outcomes,
});

String missingWorkspaceKey(Random random) {
  final int number = random.nextInt(_largestMissingNumber);
  return '$_missingWorkspacePrefix$number';
}

List<String> listWorkspaceKeys(WorkspaceContractWorld world) {
  final ContractWorkspaceImplementation first = world.implementations.first;
  return <String>[
    for (final Workspace workspace in first.repository.listWorkspaces())
      first.findKey(workspace.id),
  ];
}

String pickWorkspaceKey(Random random, WorkspaceContractWorld world) {
  if (random.nextInt(5) == 0) {
    return missingWorkspaceKey(random);
  }
  return pickOne(random, listWorkspaceKeys(world));
}

String currentWorkspaceKey(WorkspaceContractWorld world) {
  final ContractWorkspaceImplementation first = world.implementations.first;
  return first.findKey(first.repository.currentWorkspace().id);
}

String pickKeyOtherThanCurrent(Random random, WorkspaceContractWorld world) {
  final String current = currentWorkspaceKey(world);
  final List<String> others = <String>[
    for (final String key in listWorkspaceKeys(world))
      if (key != current) key,
  ];
  if (others.isEmpty || random.nextInt(5) == 0) {
    return missingWorkspaceKey(random);
  }
  return pickOne(random, others);
}

List<String> randomContractPatterns(Random random) {
  final List<String> patterns = randomPatterns(random);
  if (random.nextInt(3) == 0) {
    patterns.add(pickOne(random, _refusedPatterns));
  }
  return patterns;
}

String nextCreatedWorkspaceKey(WorkspaceContractWorld world) {
  final int knownCount = world.implementations.first.workspaceIdsByKey.length;
  return '$_createdKeyPrefix$knownCount';
}

Future<Workspace> _createAndRemember(
  ContractWorkspaceImplementation implementation,
  String name,
  String key,
) async {
  final Workspace created = await implementation.repository.createWorkspace(
    name: name,
  );
  implementation.workspaceIdsByKey[key] = created.id;
  return created;
}

Future<List<WorkspaceOutcome>> createOnEveryWorkspaceRepository(
  WorkspaceContractWorld world,
  String name,
) {
  final String key = nextCreatedWorkspaceKey(world);
  return runOnEveryWorkspaceRepository(
    world,
    (ContractWorkspaceImplementation implementation) =>
        _createAndRemember(implementation, name, key),
  );
}

Future<Object?> _performKeyed(
  ContractWorkspaceImplementation implementation,
  WorkspaceContractAction action,
  String key,
  List<String> patterns,
  ApprovalPolicy approvalPolicy,
) {
  final WorkspaceId workspaceId = implementation.resolveKey(key);
  return switch (action) {
    WorkspaceContractAction.switchWorkspace =>
      implementation.repository.switchWorkspace(workspaceId),
    WorkspaceContractAction.deleteWorkspace =>
      implementation.repository.deleteWorkspace(workspaceId),
    WorkspaceContractAction.saveProtectedFiles =>
      implementation.repository.saveProtectedFiles(
        workspaceId: workspaceId,
        patterns: patterns,
      ),
    WorkspaceContractAction.resetProtectedFiles =>
      implementation.repository.resetProtectedFiles(workspaceId),
    _ => implementation.repository.changeApprovalPolicy(
      workspaceId: workspaceId,
      approvalPolicy: approvalPolicy,
    ),
  };
}

Future<List<WorkspaceOutcome>> performKeyedOnEveryWorkspaceRepository(
  Random random,
  WorkspaceContractWorld world, {
  required WorkspaceContractAction action,
  required String key,
}) {
  final List<String> patterns = randomContractPatterns(random);
  final ApprovalPolicy approvalPolicy = pickOne(random, ApprovalPolicy.values);
  return runOnEveryWorkspaceRepository(
    world,
    (ContractWorkspaceImplementation implementation) =>
        _performKeyed(implementation, action, key, patterns, approvalPolicy),
  );
}

Future<Workspace> _saveProtectedFiles(
  ContractWorkspaceImplementation implementation,
  String key,
  List<String> patterns,
) {
  return implementation.repository.saveProtectedFiles(
    workspaceId: implementation.resolveKey(key),
    patterns: patterns,
  );
}

Future<List<WorkspaceOutcome>> saveOnEveryWorkspaceRepository(
  WorkspaceContractWorld world, {
  required String key,
  required List<String> patterns,
}) {
  return runOnEveryWorkspaceRepository(
    world,
    (ContractWorkspaceImplementation implementation) =>
        _saveProtectedFiles(implementation, key, patterns),
  );
}

Future<Workspace> _changeApprovalPolicy(
  ContractWorkspaceImplementation implementation,
  String key,
  ApprovalPolicy approvalPolicy,
) {
  return implementation.repository.changeApprovalPolicy(
    workspaceId: implementation.resolveKey(key),
    approvalPolicy: approvalPolicy,
  );
}

Future<List<WorkspaceOutcome>> changePolicyOnEveryWorkspaceRepository(
  WorkspaceContractWorld world, {
  required String key,
  required ApprovalPolicy approvalPolicy,
}) {
  return runOnEveryWorkspaceRepository(
    world,
    (ContractWorkspaceImplementation implementation) =>
        _changeApprovalPolicy(implementation, key, approvalPolicy),
  );
}

Future<Object?> _performServerAction(
  ContractWorkspaceImplementation implementation,
  WorkspaceContractAction action,
) {
  return switch (action) {
    WorkspaceContractAction.retryAppServer =>
      implementation.repository.retryAppServer(),
    WorkspaceContractAction.startServerBackup =>
      implementation.repository.startServerBackup(),
    _ => implementation.repository.stopServerBackup(),
  };
}

Future<List<WorkspaceOutcome>> performServerActionOnEveryRepository(
  WorkspaceContractWorld world,
  WorkspaceContractAction action,
) {
  return runOnEveryWorkspaceRepository(
    world,
    (ContractWorkspaceImplementation implementation) =>
        _performServerAction(implementation, action),
  );
}

bool isServerAction(WorkspaceContractAction action) {
  return action == WorkspaceContractAction.retryAppServer ||
      action == WorkspaceContractAction.startServerBackup ||
      action == WorkspaceContractAction.stopServerBackup;
}

Future<WorkspaceStepRecord> performWorkspaceAction(
  Random random,
  WorkspaceContractWorld world,
  WorkspaceContractAction action,
) async {
  if (action == WorkspaceContractAction.createWorkspace) {
    final List<WorkspaceOutcome> outcomes =
        await createOnEveryWorkspaceRepository(
          world,
          randomWorkspaceName(random),
        );
    return (action: action, key: null, outcomes: outcomes);
  }
  if (isServerAction(action)) {
    final List<WorkspaceOutcome> outcomes =
        await performServerActionOnEveryRepository(world, action);
    return (action: action, key: null, outcomes: outcomes);
  }

  final String key = action == WorkspaceContractAction.deleteWorkspace
      ? pickKeyOtherThanCurrent(random, world)
      : pickWorkspaceKey(random, world);
  final List<WorkspaceOutcome> outcomes =
      await performKeyedOnEveryWorkspaceRepository(
        random,
        world,
        action: action,
        key: key,
      );
  return (action: action, key: key, outcomes: outcomes);
}

Future<void> performRandomWorkspaceSteps(
  Random random,
  WorkspaceContractWorld world, {
  required int stepCount,
  required List<WorkspaceContractAction> actions,
}) async {
  for (int step = 0; step < stepCount; step += 1) {
    final WorkspaceStepRecord record = await performWorkspaceAction(
      random,
      world,
      pickOne(random, actions),
    );
    expectWorkspaceOutcomesAgree(record.outcomes);
    expectWorkspaceStateAgrees(world);
  }
}
