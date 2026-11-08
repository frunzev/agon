import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';

import '../../../support/random_inputs.dart';
import 'workflow_contract_rigs.dart';

const String _missingPrefix = 'flow-missing-';
const String _createdKeyPrefix = 'created-';
const int _largestMissingNumber = 1 << 30;
const List<String> _blankTexts = <String>['', '  ', '\n\t'];

enum WorkflowContractAction {
  createWorkflow,
  saveWorkflow,
  signWorkflow,
  discardChange,
  deleteWorkflow,
  draftWorkflow,
  stopDrafting,
  changeWorkflow,
  fillAgentSettings,
}

typedef WorkflowEdit = Workflow Function(Workflow workflow);

String missingWorkflowKey(Random random) {
  return '$_missingPrefix${random.nextInt(_largestMissingNumber)}';
}

List<String> listWorkflowKeys(WorkflowContractWorld world) {
  final ContractWorkflowImplementation first = world.implementations.first;
  return <String>[
    for (final Workflow workflow in first.repository.listWorkflows())
      first.findKey(workflow.id),
  ];
}

String pickWorkflowKey(Random random, WorkflowContractWorld world) {
  final List<String> keys = listWorkflowKeys(world);
  if (keys.isEmpty || random.nextInt(5) == 0) {
    return missingWorkflowKey(random);
  }
  return pickOne(random, keys);
}

String pickWorkflowKeyFor(
  Random random,
  WorkflowContractWorld world,
  WorkflowContractAction action,
) {
  if (action != WorkflowContractAction.createWorkflow) {
    return pickWorkflowKey(random, world);
  }
  final List<String> sources = <String>[
    for (final String key in listWorkflowKeys(world))
      if (!key.startsWith(draftedKeyPrefix)) key,
  ];
  if (sources.isEmpty) {
    return missingWorkflowKey(random);
  }
  return pickOne(random, sources);
}

Workflow? findListedWorkflow(
  ContractWorkflowImplementation implementation,
  String key,
) {
  for (final Workflow workflow in implementation.repository.listWorkflows()) {
    if (implementation.findKey(workflow.id) == key) {
      return workflow;
    }
  }
  return null;
}

Workflow renameWorkflow(Workflow workflow, String name) {
  return Workflow(
    id: workflow.id,
    name: name,
    availability: workflow.availability,
    agents: workflow.agents,
    connections: workflow.connections,
    signature: workflow.signature,
  );
}

Workflow _resolveEdited(
  ContractWorkflowImplementation implementation,
  String key,
  String name,
) {
  final Workflow? listed = findListedWorkflow(implementation, key);
  final Workflow template =
      listed ?? implementation.repository.listWorkflows().first;
  final Workflow renamed = renameWorkflow(template, name);
  if (listed != null) {
    return renamed;
  }
  return Workflow(
    id: WorkflowId(key),
    name: renamed.name,
    availability: renamed.availability,
    agents: renamed.agents,
    connections: renamed.connections,
    signature: renamed.signature,
  );
}

Future<Workflow> _create(
  ContractWorkflowImplementation implementation,
  String sourceKey,
  String name,
  String key,
) async {
  final Workflow? source = findListedWorkflow(implementation, sourceKey);
  if (source == null) {
    throw StateError('there is no listed workflow $sourceKey to copy');
  }
  final Workflow unsaved = renameWorkflow(source, name);
  final Workflow created = await implementation.repository.createWorkflow(
    Workflow(
      id: const WorkflowId('unsaved'),
      name: unsaved.name,
      availability: unsaved.availability,
      agents: unsaved.agents,
      connections: unsaved.connections,
      signature: null,
    ),
  );
  implementation.idsByKey[key] = created.id.value;
  return created;
}

Future<Workflow> _draft(
  ContractWorkflowImplementation implementation,
  WorkflowDraft draft,
  String key,
) async {
  final WorkflowDraftProgress finished = await implementation.repository
      .draftWorkflow(draft)
      .last;
  implementation.idsByKey[key] = finished.workflow.id.value;
  return finished.workflow;
}

Future<Workflow> _fill(
  ContractWorkflowImplementation implementation,
  String key,
  int agentChoice,
) {
  final Workflow? listed = findListedWorkflow(implementation, key);
  final List<WorkflowAgent> agents = listed?.agents ?? <WorkflowAgent>[];
  final WorkflowAgentId agentId = agentChoice < agents.length
      ? agents[agentChoice].id
      : WorkflowAgentId('$key-missing-agent');
  return implementation.repository.fillAgentSettings(
    implementation.resolveKey(key),
    agentId,
  );
}

String _nextKey(WorkflowContractWorld world, String prefix) {
  final int count = world.implementations.first.idsByKey.length;
  return '$prefix$count';
}

String randomWorkflowName(Random random) {
  if (random.nextInt(4) == 0) {
    return pickOne(random, <String>['', 'Has Space', 'UPPER', 'n' * 41]);
  }
  return 'flow-${random.nextInt(_largestMissingNumber)}';
}

String randomWorkflowText(Random random) {
  if (random.nextInt(4) == 0) {
    return pickOne(random, _blankTexts);
  }
  return 'please ${randomWordPhrase(random)}';
}

Future<Object?> _perform(
  ContractWorkflowImplementation implementation, {
  required WorkflowContractAction action,
  required String key,
  required String text,
  required String name,
  required String newKey,
  required AgentKind agent,
  required int agentChoice,
}) {
  final WorkflowId workflowId = implementation.resolveKey(key);
  return switch (action) {
    WorkflowContractAction.createWorkflow => _create(
      implementation,
      key,
      name,
      newKey,
    ),
    WorkflowContractAction.saveWorkflow =>
      implementation.repository.saveWorkflow(
        _resolveEdited(implementation, key, name),
      ),
    WorkflowContractAction.signWorkflow =>
      implementation.repository.signWorkflow(workflowId),
    WorkflowContractAction.discardChange =>
      implementation.repository.discardChange(workflowId),
    WorkflowContractAction.deleteWorkflow =>
      implementation.repository.deleteWorkflow(workflowId),
    WorkflowContractAction.draftWorkflow => _draft(
      implementation,
      WorkflowDraft(description: text),
      newKey,
    ),
    WorkflowContractAction.stopDrafting =>
      implementation.repository.stopDrafting(WorkflowDraft(description: text)),
    WorkflowContractAction.changeWorkflow =>
      implementation.repository.changeWorkflow(workflowId, text, agent),
    WorkflowContractAction.fillAgentSettings => _fill(
      implementation,
      key,
      agentChoice,
    ),
  };
}

Future<List<WorkflowOutcome>> performWorkflowAction(
  Random random,
  WorkflowContractWorld world, {
  required WorkflowContractAction action,
  required String key,
}) {
  final String text = randomWorkflowText(random);
  final String name = randomWorkflowName(random);
  final String prefix = action == WorkflowContractAction.draftWorkflow
      ? draftedKeyPrefix
      : _createdKeyPrefix;
  final String newKey = _nextKey(world, prefix);
  final AgentKind agent = pickOne(random, AgentKind.values);
  final int agentChoice = random.nextInt(3);
  return runOnEveryWorkflowRepository(
    world,
    (ContractWorkflowImplementation implementation) => _perform(
      implementation,
      action: action,
      key: key,
      text: text,
      name: name,
      newKey: newKey,
      agent: agent,
      agentChoice: agentChoice,
    ),
  );
}

Future<void> performRandomWorkflowSteps(
  Random random,
  WorkflowContractWorld world, {
  required int stepCount,
  required List<WorkflowContractAction> actions,
}) async {
  for (int step = 0; step < stepCount; step += 1) {
    final WorkflowContractAction action = pickOne(random, actions);
    final List<WorkflowOutcome> outcomes = await performWorkflowAction(
      random,
      world,
      action: action,
      key: pickWorkflowKeyFor(random, world, action),
    );
    expectWorkflowOutcomesAgree(outcomes);
    expectWorkflowStateAgrees(world);
  }
}
