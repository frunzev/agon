import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';

import '../../../support/random_inputs.dart';
import 'workflow_contract_rigs.dart';
import 'workflow_contract_steps.dart';

const int workflowContractIterations = 25;
const int workflowLongestSequence = 6;

typedef WorkflowWorldCase = Future<void> Function(
  Random random,
  WorkflowContractWorld world,
);

Future<WorkflowContractWorld> openWorkflowWorldAfterRandomSteps(
  Random random,
) async {
  final WorkflowContractWorld world = await openWorkflowContractWorld(random);
  expectWorkflowStateAgrees(world);
  await performRandomWorkflowSteps(
    random,
    world,
    stepCount: random.nextInt(workflowLongestSequence),
    actions: WorkflowContractAction.values,
  );
  return world;
}

Future<void> forEachWorkflowWorld(int seed, WorkflowWorldCase check) async {
  final Random random = seededRandom(seed);
  for (int i = 0; i < workflowContractIterations; i += 1) {
    final WorkflowContractWorld world =
        await openWorkflowWorldAfterRandomSteps(random);
    await check(random, world);
    closeWorkflowContractWorld(world);
  }
}

Future<void> expectWorkflowAgreementOn(
  int seed,
  List<WorkflowContractAction> actions,
) async {
  final Random random = seededRandom(seed);
  for (int i = 0; i < workflowContractIterations; i += 1) {
    final WorkflowContractWorld world =
        await openWorkflowWorldAfterRandomSteps(random);
    await performRandomWorkflowSteps(
      random,
      world,
      stepCount: 1 + random.nextInt(workflowLongestSequence),
      actions: actions,
    );
    closeWorkflowContractWorld(world);
  }
}

Future<List<WorkflowOutcome>> performAndExpectAgreement(
  Random random,
  WorkflowContractWorld world, {
  required WorkflowContractAction action,
  required String key,
}) async {
  final List<WorkflowOutcome> outcomes = await performWorkflowAction(
    random,
    world,
    action: action,
    key: key,
  );
  expectWorkflowOutcomesAgree(outcomes);
  expectWorkflowStateAgrees(world);
  return outcomes;
}

Future<void> expectWorkflowRefusedWithoutChange(
  Random random,
  WorkflowContractWorld world, {
  required WorkflowContractAction action,
  required String key,
}) async {
  final List<String> before = describeContractWorkflows(
    world.implementations.first,
  );

  final List<WorkflowOutcome> outcomes = await performAndExpectAgreement(
    random,
    world,
    action: action,
    key: key,
  );

  expect(isWorkflowStepRefused(outcomes), isTrue, reason: '$action $key');
  expect(describeContractWorkflows(world.implementations.first), before);
}

Workflow? findFirstListedWorkflow(WorkflowContractWorld world, String key) {
  return findListedWorkflow(world.implementations.first, key);
}

List<String> listUndraftedKeys(WorkflowContractWorld world) {
  return <String>[
    for (final String key in listWorkflowKeys(world))
      if (!key.startsWith(draftedKeyPrefix)) key,
  ];
}

bool hasFirstPendingChange(WorkflowContractWorld world, String key) {
  final ContractWorkflowImplementation first = world.implementations.first;
  return first.repository.findPendingChange(first.resolveKey(key)) != null;
}

Future<Workflow> _saveRenamed(
  ContractWorkflowImplementation implementation,
  String key,
  String name,
) {
  final Workflow listed = findListedWorkflow(implementation, key)!;
  return implementation.repository.saveWorkflow(renameWorkflow(listed, name));
}

Future<List<WorkflowOutcome>> saveRenamedOnEveryRepository(
  WorkflowContractWorld world, {
  required String key,
  required String name,
}) {
  return runOnEveryWorkflowRepository(
    world,
    (ContractWorkflowImplementation implementation) =>
        _saveRenamed(implementation, key, name),
  );
}

Future<Workflow> _sign(
  ContractWorkflowImplementation implementation,
  String key,
) {
  return implementation.repository.signWorkflow(
    implementation.resolveKey(key),
  );
}

Future<List<WorkflowOutcome>> signOnEveryRepository(
  WorkflowContractWorld world,
  String key,
) {
  return runOnEveryWorkflowRepository(
    world,
    (ContractWorkflowImplementation implementation) =>
        _sign(implementation, key),
  );
}

Future<void> _stopDrafting(
  ContractWorkflowImplementation implementation,
  String description,
) {
  return implementation.repository.stopDrafting(
    WorkflowDraft(description: description),
  );
}

Future<List<WorkflowOutcome>> stopDraftingOnEveryRepository(
  WorkflowContractWorld world,
  String description,
) {
  return runOnEveryWorkflowRepository(
    world,
    (ContractWorkflowImplementation implementation) =>
        _stopDrafting(implementation, description),
  );
}

WorkflowId resolveFirstKey(WorkflowContractWorld world, String key) {
  return world.implementations.first.resolveKey(key);
}

Future<Workflow> _createCopy(
  ContractWorkflowImplementation implementation,
  String sourceKey,
  String name,
) {
  final Workflow source = findListedWorkflow(implementation, sourceKey)!;
  return implementation.repository.createWorkflow(
    renameWorkflow(source, name),
  );
}

Future<List<WorkflowOutcome>> createCopyOnEveryRepository(
  WorkflowContractWorld world, {
  required String sourceKey,
  required String name,
}) {
  return runOnEveryWorkflowRepository(
    world,
    (ContractWorkflowImplementation implementation) =>
        _createCopy(implementation, sourceKey, name),
  );
}
