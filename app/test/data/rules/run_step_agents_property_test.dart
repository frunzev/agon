import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/run_step_agents.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import '../models/support/random_run_records.dart';

RunStep _stepFor(
  Random random, {
  required WorkflowAgentId? agentId,
  required String name,
}) {
  final RunStep template = randomRunStep(random);
  return RunStep(
    name: name,
    agentId: agentId,
    runner: template.runner,
    status: template.status,
    startedAt: template.startedAt,
    finishedAt: template.finishedAt,
    result: template.result,
    outcome: template.outcome,
    loopSource: template.loopSource,
    earlierRounds: template.earlierRounds,
  );
}

void main() {
  test('test_find_run_step_agent_property_no_agent_or_no_workflow_finds_'
      'nothing', () {
    final Random random = seededRandom(88901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final WorkflowAgentId? listedId = workflow.agents.isEmpty
          ? null
          : pickOne(random, workflow.agents).id;

      final WorkflowAgent? withoutAgent = findRunStepAgent(
        step: _stepFor(random, agentId: null, name: randomHostileText(random)),
        workflow: workflow,
      );
      final WorkflowAgent? withoutWorkflow = findRunStepAgent(
        step: _stepFor(
          random,
          agentId: listedId,
          name: randomHostileText(random),
        ),
        workflow: null,
      );

      expect(withoutAgent, isNull);
      expect(withoutWorkflow, isNull);
    }
  });

  test('test_find_run_step_agent_property_returns_the_listed_agent_'
      'itself', () {
    final Random random = seededRandom(88902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent listed = pickOne(random, workflow.agents);

      final WorkflowAgent? found = findRunStepAgent(
        step: _stepFor(
          random,
          agentId: listed.id,
          name: randomHostileText(random),
        ),
        workflow: workflow,
      );

      expect(identical(found, listed), isTrue);
    }
  });

  test('test_find_run_step_agent_property_matches_by_id_not_by_name', () {
    final Random random = seededRandom(88903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final WorkflowAgentId unknownId = WorkflowAgentId(
        'unknown ${randomHostileText(random)}',
      );
      final String borrowedName = workflow.agents.isEmpty
          ? randomHostileText(random)
          : pickOne(random, workflow.agents).name;
      final RunStep namedLikeAnAgent = _stepFor(
        random,
        agentId: unknownId,
        name: borrowedName,
      );

      final WorkflowAgent? found = findRunStepAgent(
        step: namedLikeAnAgent,
        workflow: workflow,
      );

      expect(found, isNull);
    }
  });
}
