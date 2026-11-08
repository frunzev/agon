import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_inputs.dart';
import 'support/workflow_contract_checks.dart';
import 'support/workflow_contract_rigs.dart';
import 'support/workflow_contract_steps.dart';

const String _typePrefix = 'test_workflow_repository';
const List<String> _invalidNames = <String>['', 'Has Space', 'UPPER', 'é'];

String? _pickUndraftedKey(Random random, WorkflowContractWorld world) {
  final List<String> keys = listUndraftedKeys(world);
  if (keys.isEmpty) {
    return null;
  }
  return pickOne(random, keys);
}

Future<void> _expectRenameKeepsIdentity(
  Random random,
  WorkflowContractWorld world,
) async {
  final String? key = _pickUndraftedKey(random, world);
  if (key == null) {
    return;
  }
  final Workflow before = findFirstListedWorkflow(world, key)!;
  final String name = 'renamed-${random.nextInt(1 << 20)}';

  final List<WorkflowOutcome> outcomes = await saveRenamedOnEveryRepository(
    world,
    key: key,
    name: name,
  );

  expectWorkflowOutcomesAgree(outcomes);
  expectWorkflowStateAgrees(world);
  expect(isWorkflowStepRefused(outcomes), isFalse);
  final Workflow after = findFirstListedWorkflow(world, key)!;
  expect(after.id, before.id);
  expect(after.name, name);
  expect(after.agents, hasLength(before.agents.length));
  expect(after.signature != null, before.signature != null);
}

Future<void> _expectInvalidRenameRefused(
  Random random,
  WorkflowContractWorld world,
) async {
  final String? key = _pickUndraftedKey(random, world);
  if (key == null) {
    return;
  }
  final List<String> before = describeContractWorkflows(
    world.implementations.first,
  );

  final List<WorkflowOutcome> outcomes = await saveRenamedOnEveryRepository(
    world,
    key: key,
    name: pickOne(random, _invalidNames),
  );

  expectWorkflowOutcomesAgree(outcomes);
  expect(isWorkflowStepRefused(outcomes), isTrue);
  expectWorkflowStateAgrees(world);
  expect(describeContractWorkflows(world.implementations.first), before);
}

Future<void> _expectSignedAfterSigning(
  Random random,
  WorkflowContractWorld world,
) async {
  final List<String> keys = listWorkflowKeys(world);
  if (keys.isEmpty) {
    return;
  }
  final String key = pickOne(random, keys);

  final List<WorkflowOutcome> outcomes = await signOnEveryRepository(
    world,
    key,
  );

  expectWorkflowOutcomesAgree(outcomes);
  expectWorkflowStateAgrees(world);
  expect(findFirstListedWorkflow(world, key)?.signature, isNotNull);
}

Future<void> _expectMissingRefused(
  Random random,
  WorkflowContractWorld world,
  WorkflowContractAction action,
) {
  return expectWorkflowRefusedWithoutChange(
    random,
    world,
    action: action,
    key: missingWorkflowKey(random),
  );
}

Future<void> _expectSignMissingRefused(
  Random random,
  WorkflowContractWorld world,
) {
  return _expectMissingRefused(
    random,
    world,
    WorkflowContractAction.signWorkflow,
  );
}

Future<void> _expectDeleteMissingRefused(
  Random random,
  WorkflowContractWorld world,
) {
  return _expectMissingRefused(
    random,
    world,
    WorkflowContractAction.deleteWorkflow,
  );
}

Future<void> _expectDiscardRestoresTheSignedName(
  Random random,
  WorkflowContractWorld world,
) async {
  final String? key = _pickUndraftedKey(random, world);
  if (key == null) {
    return;
  }
  await signOnEveryRepository(world, key);
  final String signedName = findFirstListedWorkflow(world, key)!.name;
  await saveRenamedOnEveryRepository(world, key: key, name: 'edited-name');

  final List<WorkflowOutcome> outcomes = await performAndExpectAgreement(
    random,
    world,
    action: WorkflowContractAction.discardChange,
    key: key,
  );

  expect(isWorkflowStepRefused(outcomes), isFalse);
  expect(findFirstListedWorkflow(world, key)?.name, signedName);
  expect(hasFirstPendingChange(world, key), isFalse);
}

Future<void> _expectDiscardWithoutChangeRefused(
  Random random,
  WorkflowContractWorld world,
) async {
  final List<String> unchanged = <String>[
    for (final String key in listWorkflowKeys(world))
      if (!hasFirstPendingChange(world, key)) key,
  ];
  final String key = unchanged.isEmpty
      ? missingWorkflowKey(random)
      : pickOne(random, unchanged);
  await expectWorkflowRefusedWithoutChange(
    random,
    world,
    action: WorkflowContractAction.discardChange,
    key: key,
  );
}

Future<void> _expectDeleteRemovesExactlyOne(
  Random random,
  WorkflowContractWorld world,
) async {
  final List<String> keys = listWorkflowKeys(world);
  if (keys.isEmpty) {
    return;
  }
  final String key = pickOne(random, keys);

  final List<WorkflowOutcome> outcomes = await performAndExpectAgreement(
    random,
    world,
    action: WorkflowContractAction.deleteWorkflow,
    key: key,
  );

  expect(isWorkflowStepRefused(outcomes), isFalse);
  final Set<String> expected = <String>{
    for (final String listed in keys)
      if (listed != key) listed,
  };
  expect(listWorkflowKeys(world).toSet(), expected);
}

void main() {
  test('${_typePrefix}_save_workflow_property_every_implementation_agrees_'
      'on_the_outcome', () async {
    await expectWorkflowAgreementOn(87101, const <WorkflowContractAction>[
      WorkflowContractAction.saveWorkflow,
    ]);
  });

  test('${_typePrefix}_save_workflow_property_renaming_keeps_identity_and_'
      'signature', () async {
    await forEachWorkflowWorld(87102, _expectRenameKeepsIdentity);
  });

  test('${_typePrefix}_save_workflow_property_invalid_names_change_'
      'nothing', () async {
    await forEachWorkflowWorld(87103, _expectInvalidRenameRefused);
  });

  test('${_typePrefix}_sign_workflow_property_every_implementation_agrees_'
      'on_the_outcome', () async {
    await expectWorkflowAgreementOn(87104, const <WorkflowContractAction>[
      WorkflowContractAction.signWorkflow,
      WorkflowContractAction.saveWorkflow,
    ]);
  });

  test('${_typePrefix}_sign_workflow_property_leaves_a_signed_'
      'workflow', () async {
    await forEachWorkflowWorld(87105, _expectSignedAfterSigning);
  });

  test('${_typePrefix}_sign_workflow_property_missing_workflows_change_'
      'nothing', () async {
    await forEachWorkflowWorld(87106, _expectSignMissingRefused);
  });

  test('${_typePrefix}_discard_change_property_every_implementation_agrees_'
      'on_the_outcome', () async {
    await expectWorkflowAgreementOn(87107, const <WorkflowContractAction>[
      WorkflowContractAction.discardChange,
      WorkflowContractAction.saveWorkflow,
      WorkflowContractAction.signWorkflow,
    ]);
  });

  test('${_typePrefix}_discard_change_property_restores_the_signed_'
      'version', () async {
    await forEachWorkflowWorld(87108, _expectDiscardRestoresTheSignedName);
  });

  test('${_typePrefix}_discard_change_property_without_a_change_changes_'
      'nothing', () async {
    await forEachWorkflowWorld(87109, _expectDiscardWithoutChangeRefused);
  });

  test('${_typePrefix}_delete_workflow_property_every_implementation_'
      'agrees_on_the_outcome', () async {
    await expectWorkflowAgreementOn(87110, const <WorkflowContractAction>[
      WorkflowContractAction.deleteWorkflow,
      WorkflowContractAction.createWorkflow,
    ]);
  });

  test('${_typePrefix}_delete_workflow_property_removes_exactly_one_'
      'workflow', () async {
    await forEachWorkflowWorld(87111, _expectDeleteRemovesExactlyOne);
  });

  test('${_typePrefix}_delete_workflow_property_missing_workflows_change_'
      'nothing', () async {
    await forEachWorkflowWorld(87112, _expectDeleteMissingRefused);
  });
}
