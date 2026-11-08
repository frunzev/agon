import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

import '../../../support/random_inputs.dart';

const String _loopOutcome = 'again';
const int _mostLoopRounds = 10;

AgentConnection proposeConnection(
  WorkflowAgentId from,
  WorkflowAgentId to, {
  required int? roundLimit,
}) {
  return AgentConnection(
    from: from,
    to: to,
    condition: roundLimit == null ? null : _loopOutcome,
    roundLimit: roundLimit,
  );
}

AgentConnection randomConnectionProposal(Random random, Workflow workflow) {
  final int? roundLimit = random.nextBool()
      ? null
      : 1 + random.nextInt(_mostLoopRounds);
  return proposeConnection(
    pickOne(random, workflow.agents).id,
    pickOne(random, workflow.agents).id,
    roundLimit: roundLimit,
  );
}

bool isConnectionRefused(Workflow workflow, AgentConnection connection) {
  final bool hasProblem = findConnectionProblem(workflow, connection) != null;
  final bool isBackward = pointsBack(workflow, connection);
  return hasProblem || connection.isLoop != isBackward;
}

Matcher throwsConnectionRefusal(String problem) {
  return throwsA(
    isA<ArgumentError>().having(
      (ArgumentError error) => error.message,
      'message',
      problem,
    ),
  );
}
