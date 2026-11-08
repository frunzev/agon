import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/simulated_workflow_node.dart';
import 'support/workflow_workspace_rig.dart';

const String _typePrefix = 'test_node_backed_workflow_repository';
const String _workflowKind = 'workflow';
const WorkflowId _missingWorkflowId = WorkflowId('workflow-missing');
const int _iterations = 30;
const List<String> _fieldsOldRecordsLack = <String>[
  'signed_at',
  'changed_at',
  'changed_by',
  'changed_by_name',
];
const node.AreaChanged _workflowsChanged = node.AreaChanged(
  area: node.ChangeArea.workflows,
);

Future<WorkflowWorkspaceRig> _openLoadedRig(Random random) async {
  final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);
  await rig.workspaces.repository.switchWorkspace(
    pickOne(random, rig.workspaceIds),
  );
  await pumpEventQueue();
  await rig.repository.load();
  return rig;
}

List<WorkflowId> _listCandidateIds(Random random, WorkflowWorkspaceRig rig) {
  return <WorkflowId>[
    for (final Map<String, Object?> view in rig.simulated.views)
      WorkflowId(readSimulatedWorkflowId(view)),
    _missingWorkflowId,
    WorkflowId(randomText(random)),
  ];
}

bool _isFound(WorkflowWorkspaceRig rig, WorkflowId workflowId) {
  try {
    rig.repository.findWorkflow(workflowId);
    return true;
  } on RecordNotFound {
    return false;
  }
}

void _forgetDetailsLikeOldRecords(Random random, WorkflowWorkspaceRig rig) {
  for (final Map<String, Object?> view in rig.simulated.views) {
    for (final String field in _fieldsOldRecordsLack) {
      if (random.nextBool()) {
        view.remove(field);
      } else {
        view[field] = null;
      }
    }
  }
}

Future<void> _changeSomethingLocally(
  Random random,
  WorkflowWorkspaceRig rig,
) async {
  final List<Workflow> listed = rig.repository.listWorkflows();
  if (listed.isNotEmpty && random.nextBool()) {
    await rig.repository.deleteWorkflow(pickOne(random, listed).id);
    return;
  }
  seedWorkflowAvailableOver(random, rig.simulated, rig.workspaceIds);
  await rig.repository.applyChange(_workflowsChanged);
}

void main() {
  test('${_typePrefix}_list_workflows_property_lists_exactly_the_workflows_'
      'available_here_in_node_order', () async {
    final Random random = seededRandom(91101);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = await _openLoadedRig(random);

      expect(
        listShownWorkflowIds(rig.repository),
        predictListedWorkflowIds(rig.simulated, currentRigWorkspaceId(rig)),
      );
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_list_workflows_property_hands_out_snapshots_later_'
      'changes_leave_alone', () async {
    final Random random = seededRandom(91102);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = await _openLoadedRig(random);
      final List<Workflow> snapshot = rig.repository.listWorkflows();
      final List<String> shownBefore = listShownWorkflowIds(rig.repository);

      await _changeSomethingLocally(random, rig);

      expect(<String>[
        for (final Workflow workflow in snapshot) workflow.id.value,
      ], shownBefore);
      if (snapshot.isNotEmpty) {
        expect(() => snapshot.add(snapshot.first), throwsUnsupportedError);
      }
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_find_workflow_property_finds_exactly_the_listed_'
      'workflows', () async {
    final Random random = seededRandom(91103);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = await _openLoadedRig(random);
      final List<Workflow> listed = rig.repository.listWorkflows();

      for (final WorkflowId workflowId in _listCandidateIds(random, rig)) {
        final List<Workflow> matching = <Workflow>[
          for (final Workflow workflow in listed)
            if (workflow.id == workflowId) workflow,
        ];
        expect(_isFound(rig, workflowId), matching.isNotEmpty);
        if (matching.isNotEmpty) {
          expect(
            rig.repository.findWorkflow(workflowId),
            same(matching.single),
          );
        }
      }
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_find_workflow_property_misses_name_the_workflow_and_'
      'its_id', () async {
    final Random random = seededRandom(91104);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = await _openLoadedRig(random);
      final List<String> listed = listShownWorkflowIds(rig.repository);

      for (final WorkflowId workflowId in _listCandidateIds(random, rig)) {
        if (listed.contains(workflowId.value)) {
          continue;
        }
        expect(
          () => rig.repository.findWorkflow(workflowId),
          throwsA(
            isA<RecordNotFound>()
                .having(
                  (RecordNotFound error) => error.kind,
                  'kind',
                  _workflowKind,
                )
                .having(
                  (RecordNotFound error) => error.identifier,
                  'identifier',
                  workflowId.value,
                ),
          ),
        );
      }
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_find_pending_change_property_only_changed_listed_'
      'workflows_have_one', () async {
    final Random random = seededRandom(91105);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = await _openLoadedRig(random);

      expect(
        listShownChangedWorkflowIds(rig.repository, rig.simulated),
        predictChangedWorkflowIds(rig.simulated, currentRigWorkspaceId(rig)),
      );
      expect(rig.repository.findPendingChange(_missingWorkflowId), isNull);
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_find_pending_change_property_old_records_keep_their_'
      'signature_state', () async {
    final Random random = seededRandom(91106);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);
      _forgetDetailsLikeOldRecords(random, rig);

      await rig.repository.load();

      final List<String> listed = listShownWorkflowIds(rig.repository);
      for (final Map<String, Object?> view in rig.simulated.views) {
        final WorkflowId workflowId = WorkflowId(
          readSimulatedWorkflowId(view),
        );
        if (!listed.contains(workflowId.value)) {
          continue;
        }
        final Object? state = view['signature_state'];
        final Workflow workflow = rig.repository.findWorkflow(workflowId);
        expect(
          rig.repository.findPendingChange(workflowId) != null,
          state == changedState,
        );
        expect(workflow.signature != null, state != unsignedState);
      }
      rig.repository.dispose();
    }
  });
}
