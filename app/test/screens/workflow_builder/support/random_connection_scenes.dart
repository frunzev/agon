import 'dart:math';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';

import '../../../support/random_branching_workflows.dart';
import '../../../support/random_inputs.dart';

const String _outcomeLetters = 'abcdefghijklmnopqrstuvwxyz0123456789-';
const List<String> _paddings = <String>[' ', '   ', '\t', ' ', ' '];
const String _doubleSpacedOutcome = 'needs  work';
const String _loneDash = '-';

final class ConnectionScene {
  const ConnectionScene({required this.workflow, required this.connection});

  final Workflow workflow;
  final AgentConnection connection;

  Workflow replaceConnection(AgentConnection edited) {
    return workflow.withGraph(
      agents: workflow.agents,
      connections: <AgentConnection>[
        for (final AgentConnection existing in workflow.connections)
          if (existing.joinsSameSteps(edited)) edited else existing,
      ],
    );
  }
}

ConnectionScene randomConnectionScene(Random random) {
  Workflow workflow = randomBranchingWorkflow(random);
  while (workflow.connections.isEmpty ||
      describeConnectionsProblem(workflow) != null) {
    workflow = randomBranchingWorkflow(random);
  }
  return ConnectionScene(
    workflow: workflow,
    connection: pickOne(random, workflow.connections),
  );
}

ConnectionScene randomLoopScene(Random random) {
  ConnectionScene scene = randomConnectionScene(random);
  while (!scene.connection.isLoop) {
    scene = randomConnectionScene(random);
  }
  return scene;
}

String randomOutcomeOfLength(Random random, int length) {
  final StringBuffer outcome = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    outcome.write(_outcomeLetters[random.nextInt(_outcomeLetters.length)]);
  }
  return outcome.toString();
}

List<String> _listSiblingOutcomes(ConnectionScene scene) {
  final List<String> outcomes = <String>[];
  for (final AgentConnection other in scene.workflow.connections) {
    final String? condition = other.condition;
    if (other.from == scene.connection.from && condition != null) {
      outcomes.add(condition);
    }
  }
  return outcomes;
}

String randomTypedOutcome(Random random, ConnectionScene scene) {
  final String word = pickOne(random, sampleOutcomes);
  final String padding = pickOne(random, _paddings);
  final List<String> candidates = <String>[
    '',
    padding,
    word,
    word.toUpperCase(),
    '$padding$word$padding',
    randomText(random),
    randomOutcomeOfLength(random, 1 + random.nextInt(maximumOutcomeLength)),
    randomOutcomeOfLength(random, maximumOutcomeLength + 1),
    _doubleSpacedOutcome,
    _loneDash,
    scene.connection.condition ?? '',
    ..._listSiblingOutcomes(scene),
  ];
  return pickOne(random, candidates);
}
