import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/refusals.dart';
import '../fakes/support/workflow_inputs.dart';
import '../fakes/support/workspace_scope_inputs.dart';
import '../fakes/support/workspace_workflow_inputs.dart';
import 'support/workflow_workspace_rig.dart';

const String _typePrefix = 'test_node_backed_workflow_repository';
const WorkflowId _missingWorkflowId = WorkflowId('workflow-missing');
const int _iterations = 30;
const int _longestSequence = 8;

typedef _Pair = ({WorkflowWorkspaceRig rig, FakeWorkflowRepository fake});

typedef _PairStep = Future<void> Function(Random random, _Pair pair);

bool _isWorkflowRefusal(Object error) {
  return error is StateError ||
      error is ArgumentError ||
      error is RecordNotFound;
}

Future<_Pair> _openPair(Random random) async {
  final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);
  final List<node.WorkflowView> views = <node.WorkflowView>[
    for (final Map<String, Object?> view in rig.simulated.views)
      node.WorkflowView.fromJson(jsonDecode(jsonEncode(view))),
  ];
  await rig.repository.load();
  final FakeWorkflowRepository fake = buildWorkflowRepositoryIn(
    workflows: <Workflow>[
      for (final node.WorkflowView view in views) mapWorkflowFromNode(view),
    ],
    changes: <WorkflowChange>[
      for (final node.WorkflowView view in views)
        ?mapPendingChangeFromNode(view),
    ],
    workspaceRepository: rig.workspaces.repository,
  );
  return (rig: rig, fake: fake);
}

String _describeAvailability(Workflow workflow) {
  return jsonEncode(mapWorkspaceScopeToNode(workflow.availability).toJson());
}

String _describeWorkflow(WorkflowRepository repository, Workflow workflow) {
  final bool hasChange = repository.findPendingChange(workflow.id) != null;
  return '${workflow.id.value}|${workflow.name}|'
      '${_describeAvailability(workflow)}|'
      '${workflow.signature != null}|$hasChange';
}

List<String> _describeListing(WorkflowRepository repository) {
  return <String>[
    for (final Workflow workflow in repository.listWorkflows())
      _describeWorkflow(repository, workflow),
  ];
}

bool _isFound(WorkflowRepository repository, WorkflowId workflowId) {
  try {
    repository.findWorkflow(workflowId);
    return true;
  } on RecordNotFound {
    return false;
  }
}

List<WorkflowId> _listSeededIds(_Pair pair) {
  return <WorkflowId>[
    for (final Map<String, Object?> view in pair.rig.simulated.views)
      WorkflowId(readSimulatedWorkflowId(view)),
    _missingWorkflowId,
  ];
}

WorkflowId _pickWorkflowId(Random random, _Pair pair) {
  return pickOne(random, _listSeededIds(pair));
}

Future<void> _switchBoth(Random random, _Pair pair) async {
  await pair.rig.workspaces.repository.switchWorkspace(
    pickOne(random, pair.rig.workspaceIds),
  );
  await pumpEventQueue();
}

Future<void> _expectSameOutcome(
  Future<Object?> Function() fakeStep,
  Future<Object?> Function() nodeStep,
  String reason,
) async {
  final bool isFakeRefused = await isRefused(
    fakeStep,
    isRefusal: _isWorkflowRefusal,
  );
  final bool isNodeRefused = await isRefused(
    nodeStep,
    isRefusal: _isWorkflowRefusal,
  );
  expect(isFakeRefused, isNodeRefused, reason: reason);
}

Future<void> _signBoth(Random random, _Pair pair) {
  final WorkflowId workflowId = _pickWorkflowId(random, pair);
  return _expectSameOutcome(
    () => pair.fake.signWorkflow(workflowId),
    () => pair.rig.repository.signWorkflow(workflowId),
    'sign ${workflowId.value}',
  );
}

Future<void> _discardBoth(Random random, _Pair pair) {
  final WorkflowId workflowId = _pickWorkflowId(random, pair);
  return _expectSameOutcome(
    () => pair.fake.discardChange(workflowId),
    () => pair.rig.repository.discardChange(workflowId),
    'discard ${workflowId.value}',
  );
}

Future<void> _deleteBoth(Random random, _Pair pair) {
  final WorkflowId workflowId = _pickWorkflowId(random, pair);
  return _expectSameOutcome(
    () => pair.fake.deleteWorkflow(workflowId),
    () => pair.rig.repository.deleteWorkflow(workflowId),
    'delete ${workflowId.value}',
  );
}

Future<void> _moveBoth(Random random, _Pair pair) async {
  final List<Workflow> listed = pair.rig.repository.listWorkflows();
  if (listed.isEmpty) {
    return;
  }
  final WorkspaceScope availability = randomWorkspaceScopeOver(
    random,
    pair.rig.workspaceIds,
  );
  final Workflow chosen = pickOne(random, listed);
  final Workflow moved = withAvailability(chosen, availability);
  if (_describeAvailability(moved) == _describeAvailability(chosen)) {
    return;
  }

  await _expectSameOutcome(
    () => pair.fake.saveWorkflow(moved),
    () => pair.rig.repository.saveWorkflow(moved),
    'move ${moved.id.value}',
  );
}

const List<_PairStep> _pairSteps = <_PairStep>[
  _switchBoth,
  _signBoth,
  _discardBoth,
  _deleteBoth,
  _moveBoth,
];

void _expectReadsAgree(_Pair pair) {
  expect(_describeListing(pair.fake), _describeListing(pair.rig.repository));
  for (final WorkflowId workflowId in _listSeededIds(pair)) {
    expect(
      _isFound(pair.fake, workflowId),
      _isFound(pair.rig.repository, workflowId),
      reason: 'find ${workflowId.value}',
    );
    expect(
      pair.fake.findPendingChange(workflowId) == null,
      pair.rig.repository.findPendingChange(workflowId) == null,
      reason: 'change ${workflowId.value}',
    );
  }
}

Future<void> _checkReadsAgreeOverSteps(int seed) async {
  final Random random = seededRandom(seed);
  for (int i = 0; i < _iterations; i += 1) {
    final _Pair pair = await _openPair(random);
    _expectReadsAgree(pair);
    final int stepCount = 1 + random.nextInt(_longestSequence);

    for (int step = 0; step < stepCount; step += 1) {
      await pickOne(random, _pairSteps)(random, pair);
      await pumpEventQueue();

      _expectReadsAgree(pair);
    }
    pair.rig.repository.dispose();
    pair.fake.dispose();
  }
}

void main() {
  test('${_typePrefix}_list_workflows_property_agrees_with_the_fake_over_'
      'random_steps', () {
    return _checkReadsAgreeOverSteps(90701);
  });

  test('${_typePrefix}_find_workflow_property_agrees_with_the_fake_over_'
      'random_steps', () {
    return _checkReadsAgreeOverSteps(90702);
  });

  test('${_typePrefix}_find_pending_change_property_agrees_with_the_fake_'
      'over_random_steps', () {
    return _checkReadsAgreeOverSteps(90703);
  });
}
