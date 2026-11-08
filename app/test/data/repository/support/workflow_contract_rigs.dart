import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/rules/naming.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../../screens/support/planned_refusal.dart';
import '../../../screens/support/refusing_library_action_repositories.dart';
import '../../../support/random_inputs.dart';
import '../../node_backed/support/node_backed_harness.dart';
import '../../node_backed/support/simulated_node_replies.dart';
import '../../node_backed/support/simulated_workflow_node.dart';
import '../../node_backed/support/simulated_workflow_views.dart';
import 'contract_step_failures.dart';

const String draftedKeyPrefix = 'drafted-';
const String _createdIdPrefix = 'created-flow-';
const int _largestSeedCount = 4;
const int _largestDraftPolls = 2;
const List<String> _seededStates = <String>[signedState, unsignedState];

final class RustLikeWorkflowNode {
  RustLikeWorkflowNode({required this.workflows});

  final SimulatedWorkflowNode workflows;
  int _createdCount = 0;

  String answer(String inputJson) {
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    final Object? commandName = command['command'];
    final String? nameProblem = _describeSavedNameProblem(command);
    if (nameProblem != null) {
      return encodeErrorReply(nameProblem);
    }
    if (commandName != 'create_workflow') {
      return workflows.answer(inputJson);
    }
    _createdCount += 1;
    final Map<String, Object?> workflow = <String, Object?>{
      'id': '$_createdIdPrefix$_createdCount',
      'name': command['name'],
      'availability': command['availability'],
      'agents': command['agents'],
      'connections': command['connections'],
      'signature': null,
    };
    final Map<String, Object?> view = buildSimulatedWorkflowView(
      workflow,
      unsignedState,
    );
    workflows.views.add(view);
    return encodeSuccessReply(view);
  }
}

String? _describeSavedNameProblem(Map<String, Object?> command) {
  final Object? commandName = command['command'];
  if (commandName == 'create_workflow') {
    return describeNameProblem(command['name']! as String);
  }
  if (commandName == 'save_workflow') {
    final Map<String, Object?> workflow =
        command['workflow']! as Map<String, Object?>;
    return describeNameProblem(workflow['name']! as String);
  }
  return null;
}

final class ContractWorkflowImplementation {
  ContractWorkflowImplementation({
    required this.name,
    required this.repository,
    required Set<String> seededIdentifiers,
  }) : idsByKey = <String, String>{
         for (final String identifier in seededIdentifiers)
           identifier: identifier,
       };

  final String name;
  final WorkflowRepository repository;
  final Map<String, String> idsByKey;

  String findKey(WorkflowId workflowId) {
    for (final MapEntry<String, String> entry in idsByKey.entries) {
      if (entry.value == workflowId.value) {
        return entry.key;
      }
    }
    return 'unknown ${workflowId.value}';
  }

  WorkflowId resolveKey(String key) => WorkflowId(idsByKey[key] ?? key);
}

typedef WorkflowContractWorld = ({
  RustLikeWorkflowNode node,
  NodeBackedWorkflowRepository nodeRepository,
  List<ContractWorkflowImplementation> implementations,
});

typedef WorkflowStep = Future<Object?> Function(
  ContractWorkflowImplementation implementation,
);

typedef WorkflowOutcome = ({String name, Object? failure, String? returned});

FakeWorkflowRepository _buildTwin(NodeBackedWorkflowRepository source) {
  final List<Workflow> workflows = source.listWorkflows();
  return FakeWorkflowRepository(
    workflows: workflows,
    changes: <WorkflowChange>[
      for (final Workflow workflow in workflows)
        ?source.findPendingChange(workflow.id),
    ],
    clock: FixedClock(DateTime.parse(simulatedMoment)),
    currentDeviceId: const DeviceId(simulatedSignerId),
    draftTemplate: workflows.first,
    drafterDeviceId: const DeviceId(simulatedDrafterId),
    draftStepDelay: Duration.zero,
    workspaceRepository: buildSingleWorkspaceRepository(),
  );
}

Future<WorkflowContractWorld> openWorkflowContractWorld(Random random) async {
  final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
    pollsBeforeDraftIsDone: random.nextInt(_largestDraftPolls + 1),
  );
  final int seedCount = 1 + random.nextInt(_largestSeedCount);
  for (int i = 0; i < seedCount; i += 1) {
    simulated.addWorkflow(
      name: 'seeded-$i',
      state: pickOne(random, _seededStates),
    );
  }
  final RustLikeWorkflowNode node = RustLikeWorkflowNode(workflows: simulated);
  final NodeBackedWorkflowRepository nodeRepository =
      NodeBackedWorkflowRepository(
        channel: buildSimulatedChannel(node.answer),
        workspaceRepository: buildSingleWorkspaceRepository(),
        draftPollInterval: Duration.zero,
      );
  await nodeRepository.load();

  final Set<String> seeded = <String>{
    for (final Workflow workflow in nodeRepository.listWorkflows())
      workflow.id.value,
  };
  return (
    node: node,
    nodeRepository: nodeRepository,
    implementations: <ContractWorkflowImplementation>[
      ContractWorkflowImplementation(
        name: 'fake',
        repository: _buildTwin(nodeRepository),
        seededIdentifiers: seeded,
      ),
      ContractWorkflowImplementation(
        name: 'node backed',
        repository: nodeRepository,
        seededIdentifiers: seeded,
      ),
      ContractWorkflowImplementation(
        name: 'refusing double',
        repository: RefusingWorkflowRepository(
          stored: _buildTwin(nodeRepository),
          refusal: PlannedRefusal(),
        ),
        seededIdentifiers: seeded,
      ),
    ],
  );
}

String describeContractWorkflow(
  ContractWorkflowImplementation implementation,
  Workflow workflow,
) {
  final String key = implementation.findKey(workflow.id);
  final bool isSigned = workflow.signature != null;
  final bool hasPendingChange =
      implementation.repository.findPendingChange(workflow.id) != null;
  if (key.startsWith(draftedKeyPrefix)) {
    return jsonEncode(<Object?>[key, isSigned, hasPendingChange]);
  }
  return jsonEncode(<Object?>[
    key,
    workflow.name,
    workflow.agents.length,
    isSigned,
    hasPendingChange,
  ]);
}

List<String> describeContractWorkflows(
  ContractWorkflowImplementation implementation,
) {
  final List<String> descriptions = <String>[
    for (final Workflow workflow in implementation.repository.listWorkflows())
      describeContractWorkflow(implementation, workflow),
  ];
  descriptions.sort();
  return descriptions;
}

Future<WorkflowOutcome> _runOnWorkflowRepository(
  ContractWorkflowImplementation implementation,
  WorkflowStep step,
) async {
  final Object? returned;
  try {
    returned = await step(implementation);
  } on Object catch (failure) {
    return (name: implementation.name, failure: failure, returned: null);
  }
  final String? description = returned is Workflow
      ? describeContractWorkflow(implementation, returned)
      : null;
  return (name: implementation.name, failure: null, returned: description);
}

Future<List<WorkflowOutcome>> runOnEveryWorkflowRepository(
  WorkflowContractWorld world,
  WorkflowStep step,
) async {
  final List<WorkflowOutcome> outcomes = <WorkflowOutcome>[];
  for (final ContractWorkflowImplementation implementation
      in world.implementations) {
    outcomes.add(await _runOnWorkflowRepository(implementation, step));
  }
  return outcomes;
}

bool isWorkflowStepRefused(List<WorkflowOutcome> outcomes) {
  return outcomes.first.failure != null;
}

void expectWorkflowOutcomesAgree(List<WorkflowOutcome> outcomes) {
  final WorkflowOutcome first = outcomes.first;
  for (final WorkflowOutcome outcome in outcomes) {
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

void expectWorkflowStateAgrees(WorkflowContractWorld world) {
  final List<String> expected = describeContractWorkflows(
    world.implementations.first,
  );
  for (final ContractWorkflowImplementation implementation
      in world.implementations) {
    expect(
      describeContractWorkflows(implementation),
      orderedEquals(expected),
      reason: implementation.name,
    );
  }
}

void closeWorkflowContractWorld(WorkflowContractWorld world) {
  world.nodeRepository.dispose();
}
