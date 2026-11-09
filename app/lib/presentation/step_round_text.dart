import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

const String _separator = ' · ';

String? describeStepOutcome(String? outcome) {
  if (outcome == null) {
    return null;
  }
  return '→\u00A0$outcome';
}

WorkflowAgent? _findAgentNamed(Workflow workflow, String name) {
  for (final WorkflowAgent agent in workflow.agents) {
    if (agent.name == name) {
      return agent;
    }
  }
  return null;
}

List<AgentConnection> _listLoopsRerunning(
  Workflow workflow,
  WorkflowAgentId agentId,
) {
  return <AgentConnection>[
    for (final AgentConnection connection in workflow.connections)
      if (connection.isLoop &&
          reachesForward(workflow, from: connection.to, to: agentId))
        connection,
  ];
}

int? findStepRoundLimit({required RunStep step, required Workflow? workflow}) {
  final WorkflowAgentId? agentId = step.agentId;
  if (agentId == null || workflow == null) {
    return null;
  }

  final List<AgentConnection> rerunningLoops = _listLoopsRerunning(
    workflow,
    agentId,
  );
  if (rerunningLoops.length != 1) {
    return null;
  }
  return rerunningLoops.single.roundLimit;
}

String? describeStepRound({
  required RunStep step,
  required Workflow? workflow,
}) {
  if (step.earlierRounds.isEmpty) {
    return null;
  }

  final int round = step.earlierRounds.length + 1;
  final int? roundLimit = findStepRoundLimit(step: step, workflow: workflow);
  if (roundLimit == null) {
    return 'round $round';
  }
  return 'round $round of ${roundLimit + 1}';
}

String describeEarlierRound({
  required EarlierRound round,
  required int roundNumber,
  required String statusText,
}) {
  final List<String> parts = <String>['Round $roundNumber', statusText];
  final String? outcome = describeStepOutcome(round.outcome);
  if (outcome != null) {
    parts.add(outcome);
  }

  final DateTime? startedAt = round.startedAt;
  final DateTime? finishedAt = round.finishedAt;
  if (startedAt != null && finishedAt != null) {
    final Duration took = finishedAt.difference(startedAt);
    parts.add('took ${describeStepDuration(took)}');
  }
  return parts.join(_separator);
}

String _describeRoundCount(int count) {
  final String unit = count == 1 ? 'earlier round' : 'earlier rounds';
  return '$count $unit';
}

String describeShowEarlierRounds(int count) {
  return 'Show ${_describeRoundCount(count)}';
}

String describeHideEarlierRounds(int count) {
  return 'Hide ${_describeRoundCount(count)}';
}

List<RunStep> findIncomingResults({
  required Run run,
  required Workflow? workflow,
  required String stepName,
}) {
  if (workflow == null) {
    return const <RunStep>[];
  }
  final WorkflowAgent? target = _findAgentNamed(workflow, stepName);
  if (target == null) {
    return const <RunStep>[];
  }

  final Set<WorkflowAgentId> sourceIds = <WorkflowAgentId>{
    for (final AgentConnection connection in workflow.connections)
      if (connection.to == target.id) connection.from,
  };
  return <RunStep>[
    for (final RunStep step in run.steps)
      if (step.agentId != null &&
          sourceIds.contains(step.agentId) &&
          step.result != null)
        step,
  ];
}
