import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/contract_step_failures.dart';
import 'support/workflow_contract_checks.dart';
import 'support/workflow_contract_rigs.dart';
import 'support/workflow_contract_steps.dart';

const String _typePrefix = 'test_workflow_repository';

Future<void> _expectListedOnce(
  Random random,
  WorkflowContractWorld world,
) async {
  for (final ContractWorkflowImplementation implementation
      in world.implementations) {
    final List<Workflow> listed = implementation.repository.listWorkflows();
    final Set<WorkflowId> identifiers = <WorkflowId>{
      for (final Workflow workflow in listed) workflow.id,
    };
    expect(identifiers, hasLength(listed.length), reason: implementation.name);
  }
}

Future<void> _expectUnmodifiable(
  Random random,
  WorkflowContractWorld world,
) async {
  for (final ContractWorkflowImplementation implementation
      in world.implementations) {
    final List<Workflow> listed = implementation.repository.listWorkflows();
    final List<String> before = describeContractWorkflows(implementation);
    final Object? failure = await findStepFailure(() async {
      listed.clear();
    });
    expect(failure, isA<UnsupportedError>(), reason: implementation.name);
    expect(describeContractWorkflows(implementation), before);
  }
}

Future<void> _expectEveryListedFound(
  Random random,
  WorkflowContractWorld world,
) async {
  for (final ContractWorkflowImplementation implementation
      in world.implementations) {
    for (final Workflow listed in implementation.repository.listWorkflows()) {
      final Workflow found = implementation.repository.findWorkflow(listed.id);
      expect(
        describeContractWorkflow(implementation, found),
        describeContractWorkflow(implementation, listed),
        reason: implementation.name,
      );
    }
  }
}

Future<void> _expectNotFoundEverywhere(
  WorkflowContractWorld world,
  String key,
) async {
  for (final ContractWorkflowImplementation implementation
      in world.implementations) {
    final WorkflowId workflowId = implementation.resolveKey(key);
    final Object? failure = await findStepFailure(
      () async => implementation.repository.findWorkflow(workflowId),
    );
    expect(failure, isA<RecordNotFound>(), reason: implementation.name);
    expect(implementation.repository.findPendingChange(workflowId), isNull);
  }
}

Future<void> _expectMissingNotFound(
  Random random,
  WorkflowContractWorld world,
) {
  return _expectNotFoundEverywhere(world, missingWorkflowKey(random));
}

Future<void> _expectDeletedNotFound(
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
  await _expectNotFoundEverywhere(world, key);
}

Future<void> _expectRenamingSignedRecordsAChange(
  Random random,
  WorkflowContractWorld world,
) async {
  final List<String> keys = listUndraftedKeys(world);
  if (keys.isEmpty) {
    return;
  }
  final String key = pickOne(random, keys);
  final Workflow before = findFirstListedWorkflow(world, key)!;
  final bool wasPending = hasFirstPendingChange(world, key);

  final List<WorkflowOutcome> outcomes = await saveRenamedOnEveryRepository(
    world,
    key: key,
    name: '${before.name}-renamed',
  );

  expectWorkflowOutcomesAgree(outcomes);
  expectWorkflowStateAgrees(world);
  final bool isSigned = before.signature != null;
  expect(hasFirstPendingChange(world, key), isSigned || wasPending);
}

Future<void> _expectSigningClearsTheChange(
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
  expect(isWorkflowStepRefused(outcomes), isFalse);
  expect(hasFirstPendingChange(world, key), isFalse);
}

Future<void> _expectCreatedUnsignedAndListed(
  Random random,
  WorkflowContractWorld world,
) async {
  final List<String> sources = listUndraftedKeys(world);
  if (sources.isEmpty) {
    return;
  }
  final Set<String> keysBefore = world.implementations.first.idsByKey.keys
      .toSet();

  final List<WorkflowOutcome> outcomes = await performAndExpectAgreement(
    random,
    world,
    action: WorkflowContractAction.createWorkflow,
    key: pickOne(random, sources),
  );

  final Set<String> newKeys = world.implementations.first.idsByKey.keys
      .toSet()
      .difference(keysBefore);
  expect(newKeys, hasLength(isWorkflowStepRefused(outcomes) ? 0 : 1));
  for (final String key in newKeys) {
    final Workflow? created = findFirstListedWorkflow(world, key);
    expect(created, isNotNull);
    expect(created?.signature, isNull);
    expect(hasFirstPendingChange(world, key), isFalse);
  }
}

Future<void> _expectInvalidNamesRefused(
  Random random,
  WorkflowContractWorld world,
) async {
  final List<String> sources = listUndraftedKeys(world);
  if (sources.isEmpty) {
    return;
  }
  final List<String> before = describeContractWorkflows(
    world.implementations.first,
  );

  final List<WorkflowOutcome> outcomes = await createCopyOnEveryRepository(
    world,
    sourceKey: pickOne(random, sources),
    name: pickOne(random, <String>['', ' ', 'Has Space', 'UPPER', 'é']),
  );

  expectWorkflowOutcomesAgree(outcomes);
  expect(isWorkflowStepRefused(outcomes), isTrue);
  expectWorkflowStateAgrees(world);
  expect(describeContractWorkflows(world.implementations.first), before);
}

void main() {
  test('${_typePrefix}_list_workflows_property_every_implementation_lists_'
      'the_same_workflows', () async {
    await expectWorkflowAgreementOn(87001, WorkflowContractAction.values);
  });

  test('${_typePrefix}_list_workflows_property_lists_each_workflow_'
      'once', () async {
    await forEachWorkflowWorld(87002, _expectListedOnce);
  });

  test('${_typePrefix}_list_workflows_property_callers_cannot_change_the_'
      'listing', () async {
    await forEachWorkflowWorld(87003, _expectUnmodifiable);
  });

  test('${_typePrefix}_find_workflow_property_finds_every_listed_workflow_'
      'unchanged', () async {
    await forEachWorkflowWorld(87004, _expectEveryListedFound);
  });

  test('${_typePrefix}_find_workflow_property_missing_workflows_are_not_'
      'found', () async {
    await forEachWorkflowWorld(87005, _expectMissingNotFound);
  });

  test('${_typePrefix}_find_workflow_property_deleted_workflows_are_not_'
      'found', () async {
    await forEachWorkflowWorld(87006, _expectDeletedNotFound);
  });

  test('${_typePrefix}_find_pending_change_property_every_implementation_'
      'agrees_on_pending_changes', () async {
    await expectWorkflowAgreementOn(87007, const <WorkflowContractAction>[
      WorkflowContractAction.saveWorkflow,
      WorkflowContractAction.signWorkflow,
      WorkflowContractAction.discardChange,
    ]);
  });

  test('${_typePrefix}_find_pending_change_property_renaming_a_signed_'
      'workflow_records_a_change', () async {
    await forEachWorkflowWorld(87008, _expectRenamingSignedRecordsAChange);
  });

  test('${_typePrefix}_find_pending_change_property_signing_clears_the_'
      'change', () async {
    await forEachWorkflowWorld(87009, _expectSigningClearsTheChange);
  });

  test('${_typePrefix}_create_workflow_property_every_implementation_'
      'agrees_on_the_outcome', () async {
    await expectWorkflowAgreementOn(87010, const <WorkflowContractAction>[
      WorkflowContractAction.createWorkflow,
    ]);
  });

  test('${_typePrefix}_create_workflow_property_lists_an_unsigned_'
      'workflow', () async {
    await forEachWorkflowWorld(87011, _expectCreatedUnsignedAndListed);
  });

  test('${_typePrefix}_create_workflow_property_invalid_names_change_'
      'nothing', () async {
    await forEachWorkflowWorld(87012, _expectInvalidNamesRefused);
  });
}
