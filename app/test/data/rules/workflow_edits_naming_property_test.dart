import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';

const int _largestTakenSuffix = 6;
final RegExp _numberedIdShape = RegExp(
  r'^00000000-0000-4000-8000-[0-9a-f]{12}$',
);

Workflow _renameAgents(Workflow workflow, List<String> names) {
  final List<WorkflowAgent> renamed = <WorkflowAgent>[
    for (int index = 0; index < workflow.agents.length; index += 1)
      workflow.agents[index].copyWith(name: names[index % names.length]),
  ];
  return workflow.withGraph(
    agents: renamed,
    connections: const <AgentConnection>[],
  );
}

List<String> _randomTakenSuffixNames(Random random, String baseName) {
  return <String>[
    if (random.nextBool()) baseName,
    for (int suffix = 2; suffix <= _largestTakenSuffix; suffix += 1)
      if (random.nextInt(3) != 0) '$baseName-$suffix',
  ];
}

void main() {
  test('test_find_free_agent_name_property_a_free_base_name_is_kept', () {
    final Random random = seededRandom(84101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final String baseName = 'fresh-${random.nextInt(1000)}';

      expect(findFreeAgentName(workflow, baseName), baseName);
    }
  });

  test('test_find_free_agent_name_property_takes_the_smallest_suffix', () {
    final Random random = seededRandom(84102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> taken = _randomTakenSuffixNames(random, 'step');
      if (taken.isEmpty) {
        continue;
      }
      final Workflow workflow = _renameAgents(
        randomBranchingWorkflow(random),
        taken,
      );
      final Set<String> storedNames = <String>{
        for (final WorkflowAgent agent in workflow.agents) agent.name,
      };
      String expected = 'step';
      int suffix = 2;
      while (storedNames.contains(expected)) {
        expected = 'step-$suffix';
        suffix += 1;
      }

      expect(findFreeAgentName(workflow, 'step'), expected);
    }
  });

  test('test_has_agent_named_property_only_exact_names_are_taken', () {
    final Random random = seededRandom(84103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _renameAgents(
        randomBranchingWorkflow(random),
        const <String>['Plan', 'plan ', ' plan', 'plan-', 'PLAN'],
      );

      expect(findFreeAgentName(workflow, 'plan'), 'plan');
    }
  });

  test('test_has_agent_named_property_a_name_anywhere_is_taken', () {
    final Random random = seededRandom(84104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final String takenName = pickOne(random, workflow.agents).name;

      final String freeName = findFreeAgentName(workflow, takenName);

      expect(freeName, isNot(takenName));
      expect(freeName, startsWith('$takenName-'));
    }
  });

  test('test_has_agent_named_property_an_empty_workflow_takes_nothing', () {
    final Random random = seededRandom(84105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final Workflow empty = workflow.withGraph(
        agents: const <WorkflowAgent>[],
        connections: const <AgentConnection>[],
      );
      final String baseName = randomText(random);

      expect(findFreeAgentName(empty, baseName), baseName);
    }
  });

  test('test_build_blank_person_step_property_takes_the_free_person_name', () {
    final Random random = seededRandom(84116);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _renameAgents(
        randomBranchingWorkflow(random),
        _randomTakenSuffixNames(random, blankPersonStepName) +
            <String>['other'],
      );

      final WorkflowAgent blank = buildBlankPersonStep(workflow);

      expect(blank.name, findFreeAgentName(workflow, blankPersonStepName));
      expect(blank.stepKind, StepKind.person);
    }
  });

  test('test_build_blank_person_step_property_id_differs_from_every_'
      'step', () {
    final Random random = seededRandom(84117);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);

      final WorkflowAgent blank = buildBlankPersonStep(workflow);

      final bool isTaken = workflow.agents.any(
        (WorkflowAgent agent) => agent.id == blank.id,
      );
      expect(isTaken, isFalse);
      expect(blank.id.value, matches(_numberedIdShape));
    }
  });
}
