import 'dart:convert';

import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/bridge/commands/drafting_commands.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import 'simulated_node_replies.dart';
import 'simulated_workflow_node.dart';

const WorkspaceId draftingRigWorkspaceId = WorkspaceId('drafting-rig-space');

final class DraftingRig {
  DraftingRig({
    required int pollsBeforeDraftIsDone,
    required Duration pollInterval,
  }) : simulated = SimulatedWorkflowNode(
         pollsBeforeDraftIsDone: pollsBeforeDraftIsDone,
       ),
       _pollInterval = pollInterval;

  final SimulatedWorkflowNode simulated;
  final Duration _pollInterval;
  final List<Map<String, Object?>> sentCommands = <Map<String, Object?>>[];
  final List<node.WorkflowView> stored = <node.WorkflowView>[];
  late final NodeWorkflowDrafting drafting = NodeWorkflowDrafting(
    channel: buildSimulatedChannel(_recordAndAnswer),
    pollInterval: _pollInterval,
  );

  Stream<WorkflowDraftProgress> streamDraft(WorkflowDraft draft) {
    return drafting.streamDraftProgress(
      draft: draft,
      command: node.DraftWorkflowCommand(
        workspaceId: draftingRigWorkspaceId,
        description: draft.description,
      ),
      storeDrafted: _storeView,
    );
  }

  List<String> listSentNames() {
    return <String>[
      for (final Map<String, Object?> command in sentCommands)
        command['command']! as String,
    ];
  }

  String _recordAndAnswer(String inputJson) {
    sentCommands.add(jsonDecode(inputJson) as Map<String, Object?>);
    return simulated.answer(inputJson);
  }

  Workflow _storeView(node.WorkflowView view) {
    stored.add(view);
    return mapWorkflowFromNode(view);
  }
}

Future<void> waitForDraftProgress(
  List<WorkflowDraftProgress> received,
  int count,
) async {
  await Future<void>.delayed(Duration.zero);
  while (received.length < count) {
    await Future<void>.delayed(Duration.zero);
  }
}
