import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/bridge/commands/drafting_commands.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';

import '../../support/random_inputs.dart';
import 'support/drafting_rig.dart';
import 'support/simulated_workflow_node.dart';

const String _typePrefix = 'test_node_workflow_drafting';
const int _iterations = 20;
const int _largestShortPolls = 4;
const int _pollsOfALongDraft = 1000000;
const String _statusCommand = 'workflow_draft_status';
const String _listRunsCommand = 'list_runs';

WorkflowDraft _randomDraft(Random random) {
  return WorkflowDraft(description: 'Draft ${randomWordPhrase(random)}x');
}

DraftingRig _buildRig(int polls) {
  return DraftingRig(
    pollsBeforeDraftIsDone: polls,
    pollInterval: Duration.zero,
  );
}

Future<node.WorkflowView> _redraft(
  DraftingRig rig, {
  required WorkspaceId workspaceId,
}) {
  final Map<String, Object?> seeded = rig.simulated.addWorkflow(
    name: 'flow',
    state: signedState,
  );
  final String workflowId =
      (seeded['workflow']! as Map<String, Object?>)['id']! as String;
  return rig.drafting.redraftWorkflow(
    workspaceId: workspaceId,
    command: node.ChangeWorkflowCommand(
      workspaceId: workspaceId,
      workflowId: WorkflowId(workflowId),
      request: 'Add a step',
      agent: node.AgentKind.claudeCode,
    ),
  );
}

List<Map<String, Object?>> _statusReads(DraftingRig rig) {
  return <Map<String, Object?>>[
    for (final Map<String, Object?> command in rig.sentCommands)
      if (command['command'] == _statusCommand) command,
  ];
}

void main() {
  test('${_typePrefix}_redraft_workflow_property_polls_until_done_and_'
      'returns_the_same_workflow', () async {
    final Random random = seededRandom(85401);
    for (int i = 0; i < _iterations; i += 1) {
      final int polls = random.nextInt(_largestShortPolls);
      final DraftingRig rig = _buildRig(polls);

      final node.WorkflowView changed = await _redraft(
        rig,
        workspaceId: draftingRigWorkspaceId,
      );

      expect(_statusReads(rig), hasLength(polls + 1));
      expect(changed.workflow.id.value, startsWith('workflow-'));
    }
  });

  test('${_typePrefix}_redraft_workflow_property_a_failing_status_ends_'
      'the_redraft', () async {
    final Random random = seededRandom(85402);
    for (int i = 0; i < _iterations; i += 1) {
      final DraftingRig rig = _buildRig(random.nextInt(_largestShortPolls));
      rig.simulated.failingCommands.add(_statusCommand);

      await expectLater(
        _redraft(rig, workspaceId: draftingRigWorkspaceId),
        throwsStateError,
      );
      expect(_statusReads(rig), hasLength(1));
    }
  });

  test('${_typePrefix}_redraft_workflow_property_reads_status_in_the_'
      'given_workspace', () async {
    final Random random = seededRandom(85403);
    for (int i = 0; i < _iterations; i += 1) {
      final DraftingRig rig = _buildRig(random.nextInt(_largestShortPolls));
      final WorkspaceId workspaceId = WorkspaceId(randomText(random));

      await _redraft(rig, workspaceId: workspaceId);

      for (final Map<String, Object?> read in _statusReads(rig)) {
        expect(read['workspace_id'], workspaceId.value);
      }
    }
  });

  test('${_typePrefix}_poll_draft_progress_property_lists_runs_before_'
      'every_status_read', () async {
    final Random random = seededRandom(85404);
    for (int i = 0; i < _iterations; i += 1) {
      final DraftingRig rig = _buildRig(random.nextInt(_largestShortPolls));

      await rig.streamDraft(_randomDraft(random)).toList();

      final List<String> polling = <String>[
        for (final String name in rig.listSentNames())
          if (name == _listRunsCommand || name == _statusCommand) name,
      ];
      for (int index = 0; index < polling.length; index += 2) {
        expect(polling[index], _listRunsCommand);
        expect(polling[index + 1], _statusCommand);
      }
    }
  });

  test('${_typePrefix}_poll_draft_progress_property_a_status_failure_while_'
      'drafting_reaches_the_stream', () async {
    final Random random = seededRandom(85405);
    for (int i = 0; i < _iterations; i += 1) {
      final DraftingRig rig = _buildRig(_pollsOfALongDraft);
      rig.simulated.failingCommands.add(_statusCommand);
      final WorkflowDraft draft = _randomDraft(random);

      await expectLater(rig.streamDraft(draft).toList(), throwsStateError);
      await expectLater(rig.drafting.stopDrafting(draft), throwsStateError);
      expect(rig.stored, isEmpty);
    }
  });

  test('${_typePrefix}_poll_draft_progress_property_yields_no_progress_'
      'after_the_finished_one', () async {
    final Random random = seededRandom(85406);
    for (int i = 0; i < _iterations; i += 1) {
      final DraftingRig rig = _buildRig(random.nextInt(_largestShortPolls));

      final List<WorkflowDraftProgress> progress = await rig
          .streamDraft(_randomDraft(random))
          .toList();

      final int finishedIndex = progress.indexWhere(
        (WorkflowDraftProgress step) => step.isFinished,
      );
      expect(finishedIndex, progress.length - 1);
      for (final WorkflowDraftProgress step in progress) {
        expect(step.workflow.id, progress.last.workflow.id);
      }
    }
  });

  test('${_typePrefix}_read_draft_status_property_asks_about_the_started_'
      'task_and_workflow', () async {
    final Random random = seededRandom(85407);
    for (int i = 0; i < _iterations; i += 1) {
      final DraftingRig rig = _buildRig(random.nextInt(_largestShortPolls));

      final List<WorkflowDraftProgress> progress = await rig
          .streamDraft(_randomDraft(random))
          .toList();

      final List<Map<String, Object?>> reads = _statusReads(rig);
      final Set<Object?> askedTasks = <Object?>{
        for (final Map<String, Object?> read in reads) read['task_id'],
      };
      expect(askedTasks, hasLength(1));
      for (final Map<String, Object?> read in reads) {
        expect(read['workspace_id'], draftingRigWorkspaceId.value);
        expect(read['workflow_id'], progress.last.workflow.id.value);
      }
    }
  });

  test('${_typePrefix}_read_draft_status_property_one_read_per_poll_until_'
      'done', () async {
    final Random random = seededRandom(85408);
    for (int i = 0; i < _iterations; i += 1) {
      final int polls = random.nextInt(_largestShortPolls);
      final DraftingRig rig = _buildRig(polls);

      await rig.streamDraft(_randomDraft(random)).toList();

      expect(_statusReads(rig), hasLength(polls + 1));
      expect(rig.simulated.draftStatusPollCount, polls + 1);
    }
  });

  test('${_typePrefix}_read_draft_status_property_a_later_failure_ends_'
      'the_redraft', () async {
    final Random random = seededRandom(85409);
    for (int i = 0; i < _iterations; i += 1) {
      final DraftingRig rig = _buildRig(_pollsOfALongDraft);
      final Future<node.WorkflowView> redrafting = _redraft(
        rig,
        workspaceId: draftingRigWorkspaceId,
      );
      await Future<void>.delayed(Duration.zero);
      while (_statusReads(rig).length < 1 + random.nextInt(3)) {
        await Future<void>.delayed(Duration.zero);
      }
      rig.simulated.failingCommands.add(_statusCommand);

      await expectLater(redrafting, throwsStateError);
    }
  });
}
