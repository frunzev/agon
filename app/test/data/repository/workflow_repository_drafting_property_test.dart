import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';

import '../../support/random_inputs.dart';
import 'support/workflow_contract_checks.dart';
import 'support/workflow_contract_rigs.dart';
import 'support/workflow_contract_steps.dart';

const String _typePrefix = 'test_workflow_repository';
const List<String> _blankTexts = <String>['', ' ', '\n\t', ' '];

Future<WorkflowDraftProgress> _draftToTheEnd(
  ContractWorkflowImplementation implementation,
  String description,
) {
  return implementation.repository
      .draftWorkflow(WorkflowDraft(description: description))
      .last;
}

Future<Workflow> _change(
  ContractWorkflowImplementation implementation,
  String key,
  String request,
) {
  return implementation.repository.changeWorkflow(
    implementation.resolveKey(key),
    request,
    AgentKind.codex,
  );
}

Future<Workflow> _fillMissingAgent(
  ContractWorkflowImplementation implementation,
  String key,
) {
  return implementation.repository.fillAgentSettings(
    implementation.resolveKey(key),
    WorkflowAgentId('$key-absent-agent'),
  );
}

Future<void> _expectFinishedDraftListsOneMore(
  Random random,
  WorkflowContractWorld world,
) async {
  final int countBefore = listWorkflowKeys(world).length;

  final List<WorkflowOutcome> outcomes = await performAndExpectAgreement(
    random,
    world,
    action: WorkflowContractAction.draftWorkflow,
    key: missingWorkflowKey(random),
  );

  final int added = isWorkflowStepRefused(outcomes) ? 0 : 1;
  expect(listWorkflowKeys(world), hasLength(countBefore + added));
}

Future<void> _expectBlankDescriptionRefused(
  Random random,
  WorkflowContractWorld world,
) async {
  final String blank = pickOne(random, _blankTexts);
  final List<String> before = describeContractWorkflows(
    world.implementations.first,
  );

  final List<WorkflowOutcome> outcomes = await runOnEveryWorkflowRepository(
    world,
    (ContractWorkflowImplementation implementation) =>
        _draftToTheEnd(implementation, blank),
  );

  expectWorkflowOutcomesAgree(outcomes);
  expect(isWorkflowStepRefused(outcomes), isTrue);
  expect(describeContractWorkflows(world.implementations.first), before);
}

Future<void> _expectIdleStopRefused(
  Random random,
  WorkflowContractWorld world,
) async {
  final List<String> before = describeContractWorkflows(
    world.implementations.first,
  );

  final List<WorkflowOutcome> outcomes = await stopDraftingOnEveryRepository(
    world,
    'never drafted ${random.nextInt(1 << 20)}',
  );

  expectWorkflowOutcomesAgree(outcomes);
  expect(isWorkflowStepRefused(outcomes), isTrue);
  expectWorkflowStateAgrees(world);
  expect(describeContractWorkflows(world.implementations.first), before);
}

Future<void> _expectStopAfterFinishRefused(
  Random random,
  WorkflowContractWorld world,
) async {
  final String description = 'draft ${randomWordPhrase(random)}';
  final List<WorkflowOutcome> drafted = await runOnEveryWorkflowRepository(
    world,
    (ContractWorkflowImplementation implementation) =>
        _draftToTheEnd(implementation, description),
  );
  expect(isWorkflowStepRefused(drafted), isFalse);

  final List<WorkflowOutcome> outcomes = await stopDraftingOnEveryRepository(
    world,
    description,
  );

  expectWorkflowOutcomesAgree(outcomes);
  expect(isWorkflowStepRefused(outcomes), isTrue);
}

Future<void> _expectChangeAddsOneAgent(
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

  final List<WorkflowOutcome> outcomes = await runOnEveryWorkflowRepository(
    world,
    (ContractWorkflowImplementation implementation) =>
        _change(implementation, key, 'add a reviewer'),
  );

  expectWorkflowOutcomesAgree(outcomes);
  expectWorkflowStateAgrees(world);
  expect(isWorkflowStepRefused(outcomes), isFalse);
  final Workflow after = findFirstListedWorkflow(world, key)!;
  expect(after.id, before.id);
  expect(after.name, before.name);
  expect(after.agents, hasLength(before.agents.length + 1));
  final bool isSigned = before.signature != null;
  expect(hasFirstPendingChange(world, key), isSigned || wasPending);
}

Future<void> _expectBlankOrMissingChangeRefused(
  Random random,
  WorkflowContractWorld world,
) async {
  final List<String> keys = listWorkflowKeys(world);
  final bool isBlank = keys.isNotEmpty && random.nextBool();
  final String key = isBlank
      ? pickOne(random, keys)
      : missingWorkflowKey(random);
  final String request = isBlank
      ? pickOne(random, _blankTexts)
      : 'add a reviewer';
  final List<String> before = describeContractWorkflows(
    world.implementations.first,
  );

  final List<WorkflowOutcome> outcomes = await runOnEveryWorkflowRepository(
    world,
    (ContractWorkflowImplementation implementation) =>
        _change(implementation, key, request),
  );

  expectWorkflowOutcomesAgree(outcomes);
  expect(isWorkflowStepRefused(outcomes), isTrue);
  expect(describeContractWorkflows(world.implementations.first), before);
}

Future<void> _expectFillKeepsTheShape(
  Random random,
  WorkflowContractWorld world,
) async {
  final List<String> keys = listUndraftedKeys(world);
  if (keys.isEmpty) {
    return;
  }
  final String key = pickOne(random, keys);
  final Workflow before = findFirstListedWorkflow(world, key)!;

  final List<WorkflowOutcome> outcomes = await performAndExpectAgreement(
    random,
    world,
    action: WorkflowContractAction.fillAgentSettings,
    key: key,
  );

  if (isWorkflowStepRefused(outcomes)) {
    return;
  }
  final Workflow after = findFirstListedWorkflow(world, key)!;
  expect(after.id, before.id);
  expect(after.name, before.name);
  expect(after.agents, hasLength(before.agents.length));
}

Future<void> _expectMissingAgentRefused(
  Random random,
  WorkflowContractWorld world,
) async {
  final String key = pickWorkflowKey(random, world);
  final List<String> before = describeContractWorkflows(
    world.implementations.first,
  );

  final List<WorkflowOutcome> outcomes = await runOnEveryWorkflowRepository(
    world,
    (ContractWorkflowImplementation implementation) =>
        _fillMissingAgent(implementation, key),
  );

  expectWorkflowOutcomesAgree(outcomes);
  expect(isWorkflowStepRefused(outcomes), isTrue);
  expect(describeContractWorkflows(world.implementations.first), before);
}

void main() {
  test('${_typePrefix}_draft_workflow_property_every_implementation_agrees_'
      'on_the_outcome', () async {
    await expectWorkflowAgreementOn(87201, const <WorkflowContractAction>[
      WorkflowContractAction.draftWorkflow,
    ]);
  });

  test('${_typePrefix}_draft_workflow_property_a_finished_draft_lists_one_'
      'more_workflow', () async {
    await forEachWorkflowWorld(87202, _expectFinishedDraftListsOneMore);
  });

  test('${_typePrefix}_draft_workflow_property_blank_descriptions_change_'
      'nothing', () async {
    await forEachWorkflowWorld(87203, _expectBlankDescriptionRefused);
  });

  test('${_typePrefix}_stop_drafting_property_every_implementation_agrees_'
      'on_the_outcome', () async {
    await expectWorkflowAgreementOn(87204, const <WorkflowContractAction>[
      WorkflowContractAction.stopDrafting,
      WorkflowContractAction.draftWorkflow,
    ]);
  });

  test('${_typePrefix}_stop_drafting_property_nothing_to_stop_is_'
      'refused', () async {
    await forEachWorkflowWorld(87205, _expectIdleStopRefused);
  });

  test('${_typePrefix}_stop_drafting_property_a_finished_draft_cannot_be_'
      'stopped', () async {
    await forEachWorkflowWorld(87206, _expectStopAfterFinishRefused);
  });

  test('${_typePrefix}_change_workflow_property_every_implementation_'
      'agrees_on_the_outcome', () async {
    await expectWorkflowAgreementOn(87207, const <WorkflowContractAction>[
      WorkflowContractAction.changeWorkflow,
      WorkflowContractAction.signWorkflow,
    ]);
  });

  test('${_typePrefix}_change_workflow_property_adds_exactly_one_'
      'agent', () async {
    await forEachWorkflowWorld(87208, _expectChangeAddsOneAgent);
  });

  test('${_typePrefix}_change_workflow_property_blank_or_missing_changes_'
      'nothing', () async {
    await forEachWorkflowWorld(87209, _expectBlankOrMissingChangeRefused);
  });

  test('${_typePrefix}_fill_agent_settings_property_every_implementation_'
      'agrees_on_the_outcome', () async {
    await expectWorkflowAgreementOn(87210, const <WorkflowContractAction>[
      WorkflowContractAction.fillAgentSettings,
      WorkflowContractAction.changeWorkflow,
    ]);
  });

  test('${_typePrefix}_fill_agent_settings_property_keeps_the_workflow_'
      'shape', () async {
    await forEachWorkflowWorld(87211, _expectFillKeepsTheShape);
  });

  test('${_typePrefix}_fill_agent_settings_property_missing_agents_change_'
      'nothing', () async {
    await forEachWorkflowWorld(87212, _expectMissingAgentRefused);
  });
}
