import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../../support/random_inputs.dart';
import 'workspace_contract_rigs.dart';
import 'workspace_contract_steps.dart';

const int workspaceContractIterations = 25;
const int workspaceLongestSequence = 8;

typedef WorkspaceFields = ({
  String name,
  List<String> protectedFiles,
  ApprovalPolicy approvalPolicy,
});

int randomWorkspaceStepCount(Random random) {
  return 1 + random.nextInt(workspaceLongestSequence);
}

WorkspaceRepository firstWorkspaceRepository(WorkspaceContractWorld world) {
  return world.implementations.first.repository;
}

Future<WorkspaceContractWorld> openWorkspaceWorldAfterRandomSteps(
  Random random, {
  required List<WorkspaceContractAction> actions,
}) async {
  final WorkspaceContractWorld world = await openWorkspaceContractWorld(
    random,
  );
  expectWorkspaceStateAgrees(world);
  await performRandomWorkspaceSteps(
    random,
    world,
    stepCount: random.nextInt(workspaceLongestSequence),
    actions: actions,
  );
  return world;
}

Future<void> expectWorkspaceAgreementOn(
  int seed,
  List<WorkspaceContractAction> actions,
) async {
  final Random random = seededRandom(seed);
  for (int i = 0; i < workspaceContractIterations; i += 1) {
    final WorkspaceContractWorld world =
        await openWorkspaceWorldAfterRandomSteps(
          random,
          actions: WorkspaceContractAction.values,
        );
    await performRandomWorkspaceSteps(
      random,
      world,
      stepCount: randomWorkspaceStepCount(random),
      actions: actions,
    );
  }
}

Future<void> expectMissingWorkspaceChangesNothing(
  int seed,
  WorkspaceContractAction action,
) async {
  final Random random = seededRandom(seed);
  for (int i = 0; i < workspaceContractIterations; i += 1) {
    final WorkspaceContractWorld world =
        await openWorkspaceWorldAfterRandomSteps(
          random,
          actions: WorkspaceContractAction.values,
        );
    final List<String> before = describeContractWorkspaces(
      world.implementations.first,
    );

    final List<WorkspaceOutcome> outcomes =
        await performKeyedOnEveryWorkspaceRepository(
          random,
          world,
          action: action,
          key: missingWorkspaceKey(random),
        );

    expectWorkspaceOutcomesAgree(outcomes);
    expect(isWorkspaceStepRefused(outcomes), isTrue);
    expectWorkspaceStateAgrees(world);
    expect(describeContractWorkspaces(world.implementations.first), before);
  }
}

Workspace? findListedWorkspaceByKey(
  ContractWorkspaceImplementation implementation,
  String key,
) {
  for (final Workspace workspace
      in implementation.repository.listWorkspaces()) {
    if (implementation.findKey(workspace.id) == key) {
      return workspace;
    }
  }
  return null;
}

WorkspaceFields? readWorkspaceFields(
  ContractWorkspaceImplementation implementation,
  String key,
) {
  final Workspace? workspace = findListedWorkspaceByKey(implementation, key);
  if (workspace == null) {
    return null;
  }
  return (
    name: workspace.name,
    protectedFiles: workspace.protectedFiles,
    approvalPolicy: workspace.approvalPolicy,
  );
}

List<WorkspaceFields?> readFieldsOfEveryImplementation(
  WorkspaceContractWorld world,
  String key,
) {
  return <WorkspaceFields?>[
    for (final ContractWorkspaceImplementation implementation
        in world.implementations)
      readWorkspaceFields(implementation, key),
  ];
}
