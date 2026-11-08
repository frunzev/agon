import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';

import '../../../support/random_workflows.dart';

const int _largestChainLength = 6;
const int _shortestChainLength = 2;
const int _largestRoundLimitDistance = 100;

typedef OrderedAgentPair = ({WorkflowAgent earlier, WorkflowAgent later});

AgentConnection buildConnection(
  WorkflowAgent from,
  WorkflowAgent to, {
  required String? condition,
  required int? roundLimit,
}) {
  return AgentConnection(
    from: from.id,
    to: to.id,
    condition: condition,
    roundLimit: roundLimit,
  );
}

List<WorkflowAgent> randomChainAgents(Random random) {
  final int count =
      _shortestChainLength +
      random.nextInt(_largestChainLength - _shortestChainLength + 1);
  return <WorkflowAgent>[
    for (int index = 0; index < count; index += 1) randomAgent(random, index),
  ];
}

List<AgentConnection> linkInChain(List<WorkflowAgent> agents) {
  return <AgentConnection>[
    for (int index = 1; index < agents.length; index += 1)
      buildConnection(
        agents[index - 1],
        agents[index],
        condition: null,
        roundLimit: null,
      ),
  ];
}

Workflow buildConnectionWorkflow(
  List<WorkflowAgent> agents,
  List<AgentConnection> connections,
) {
  return Workflow(
    id: const WorkflowId('connection-rules-workflow'),
    name: 'connection-rules',
    availability: const AllWorkspaces(),
    agents: agents,
    connections: connections,
    signature: null,
  );
}

String describeConnectionEnds(WorkflowAgent from, WorkflowAgent to) {
  return 'from ${from.name} to ${to.name}';
}

int randomGoodRoundLimit(Random random) {
  return fewestLoopRounds +
      random.nextInt(mostLoopRounds - fewestLoopRounds + 1);
}

int randomBadRoundLimit(Random random) {
  final int distance = 1 + random.nextInt(_largestRoundLimitDistance);
  return random.nextBool()
      ? fewestLoopRounds - distance
      : mostLoopRounds + distance;
}

OrderedAgentPair pickOrderedPair(Random random, List<WorkflowAgent> agents) {
  final int laterIndex = 1 + random.nextInt(agents.length - 1);
  final int earlierIndex = random.nextInt(laterIndex);
  return (earlier: agents[earlierIndex], later: agents[laterIndex]);
}

String? describeChainWith(
  List<WorkflowAgent> agents,
  List<AgentConnection> extraConnections,
) {
  final Workflow workflow = buildConnectionWorkflow(agents, <AgentConnection>[
    ...linkInChain(agents),
    ...extraConnections,
  ]);
  return describeConnectionsProblem(workflow);
}
