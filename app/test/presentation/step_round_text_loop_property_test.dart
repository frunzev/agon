import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/step_round_text.dart';

import '../support/random_branching_workflows.dart';
import '../support/random_inputs.dart';
import '../support/random_step_rounds.dart';
import '../support/random_workflows.dart';

const int _mostLoopsTaken = 30;
final RegExp _roundOfTotal = RegExp(r'^round (\d+) of (\d+)$');

final class _LoopRoundsModel {
  _LoopRoundsModel(this.workflow);

  final Workflow workflow;
  final Map<WorkflowAgentId, int> earlierRoundCounts =
      <WorkflowAgentId, int>{};
  final Map<WorkflowAgentId, String?> loopSources =
      <WorkflowAgentId, String?>{};
  final Map<AgentConnection, int> takenRounds = <AgentConnection, int>{};

  List<AgentConnection> listLoopsWithRoundsLeft() {
    return <AgentConnection>[
      for (final AgentConnection connection in workflow.connections)
        if (connection.isLoop &&
            (takenRounds[connection] ?? 0) < connection.roundLimit!)
          connection,
    ];
  }

  void takeLoop(AgentConnection takenLoop) {
    final Set<WorkflowAgentId> resetAgents = <WorkflowAgentId>{
      for (final WorkflowAgent agent in workflow.agents)
        if (hasForwardPath(workflow, from: takenLoop.to, to: agent.id))
          agent.id,
    };
    final String sourceName = workflow.findAgent(takenLoop.from).name;

    for (final WorkflowAgentId agentId in resetAgents) {
      earlierRoundCounts[agentId] = (earlierRoundCounts[agentId] ?? 0) + 1;
      loopSources[agentId] = agentId == takenLoop.to ? sourceName : null;
    }
    for (final AgentConnection connection in workflow.connections) {
      if (_isNestedIn(connection, takenLoop, resetAgents)) {
        takenRounds.remove(connection);
      }
    }
    takenRounds[takenLoop] = (takenRounds[takenLoop] ?? 0) + 1;
  }

  bool _isNestedIn(
    AgentConnection connection,
    AgentConnection takenLoop,
    Set<WorkflowAgentId> resetAgents,
  ) {
    if (!connection.isLoop || !resetAgents.contains(connection.to)) {
      return false;
    }
    if (connection.to != takenLoop.to) {
      return true;
    }
    final bool isTakenLoop = connection.from == takenLoop.from;
    final bool reachesTakenSource = hasForwardPath(
      workflow,
      from: connection.from,
      to: takenLoop.from,
    );
    return !isTakenLoop && reachesTakenSource;
  }
}

List<String> _describeEveryRound(Random random, _LoopRoundsModel model) {
  final List<String> roundTexts = <String>[];
  for (final WorkflowAgent agent in model.workflow.agents) {
    final int earlierCount = model.earlierRoundCounts[agent.id] ?? 0;
    final RunStep step = buildAgentRunStep(
      agent: agent,
      loopSource: model.loopSources[agent.id],
      earlierRounds: randomEarlierRounds(random, earlierCount),
      result: null,
    );
    final String? roundText = describeStepRound(
      step: step,
      workflow: model.workflow,
    );
    if (roundText != null) {
      roundTexts.add(roundText);
    }
  }
  return roundTexts;
}

void main() {
  test('test_describe_step_round_property_round_never_exceeds_total', () {
    final Random random = seededRandom(94711);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _LoopRoundsModel model = _LoopRoundsModel(
        randomBranchingWorkflow(random),
      );

      for (int taken = 0; taken < _mostLoopsTaken; taken += 1) {
        final List<AgentConnection> loops = model.listLoopsWithRoundsLeft();
        if (loops.isEmpty) {
          break;
        }
        model.takeLoop(pickOne(random, loops));

        for (final String roundText in _describeEveryRound(random, model)) {
          final RegExpMatch? match = _roundOfTotal.firstMatch(roundText);
          if (match == null) {
            continue;
          }
          final int round = int.parse(match.group(1)!);
          final int total = int.parse(match.group(2)!);
          expect(round, lessThanOrEqualTo(total), reason: roundText);
        }
      }
    }
  });

  test(
    'test_list_loops_rerunning_property_two_rerunning_loops_drop_limit',
    () {
      final Random random = seededRandom(94712);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Workflow workflow = randomBranchingWorkflow(random);

        for (final WorkflowAgent agent in workflow.agents) {
          final List<AgentConnection> rerunningLoops = <AgentConnection>[
            for (final AgentConnection connection in workflow.connections)
              if (connection.isLoop &&
                  hasForwardPath(workflow, from: connection.to, to: agent.id))
                connection,
          ];
          if (rerunningLoops.length < 2) {
            continue;
          }
          final RunStep step = buildAgentRunStep(
            agent: agent,
            loopSource: workflow.findAgent(rerunningLoops.first.from).name,
            earlierRounds: randomEarlierRounds(random, 1),
            result: null,
          );

          expect(findStepRoundLimit(step: step, workflow: workflow), isNull);
        }
      }
    },
  );

  test('test_list_loops_rerunning_property_single_loop_limits_its_reach', () {
    final Random random = seededRandom(94713);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final List<AgentConnection> loops = <AgentConnection>[
        for (final AgentConnection connection in workflow.connections)
          if (connection.isLoop) connection,
      ];
      if (loops.length != 1) {
        continue;
      }
      final AgentConnection loop = loops.single;

      for (final WorkflowAgent agent in workflow.agents) {
        final RunStep step = buildAgentRunStep(
          agent: agent,
          loopSource: null,
          earlierRounds: randomEarlierRounds(random, 1),
          result: null,
        );
        final bool isRerun = hasForwardPath(
          workflow,
          from: loop.to,
          to: agent.id,
        );

        expect(
          findStepRoundLimit(step: step, workflow: workflow),
          isRerun ? loop.roundLimit : null,
        );
      }
    }
  });

  test('test_list_loops_rerunning_property_no_loops_means_no_limit', () {
    final Random random = seededRandom(94714);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);

      for (final WorkflowAgent agent in workflow.agents) {
        final RunStep step = buildAgentRunStep(
          agent: agent,
          loopSource: agent.name,
          earlierRounds: randomEarlierRounds(random, 1 + random.nextInt(3)),
          result: null,
        );

        expect(findStepRoundLimit(step: step, workflow: workflow), isNull);
        expect(
          describeStepRound(step: step, workflow: workflow),
          'round ${step.earlierRounds.length + 1}',
        );
      }
    }
  });
}
